import Foundation
import SwiftData
#if os(macOS)
import Security
#endif

/// One container, shared by the app and its widget through an app group, synced
/// through the private CloudKit database so an iPhone and a Mac see the same shelf.
enum Store {
    static let appGroup = "group.app.fornace.larder"
    static let cloudContainer = "iCloud.app.fornace.larder"

    static let schema = Schema([
        PantryItem.self,
        ShoppingItem.self,
        CookedMeal.self,
        KnownProduct.self,
    ])

    /// The one container the app process uses, including App Intents. Built once so
    /// CloudKit is not brought up twice.
    static let shared: ModelContainer = container()

    /// Shared on-disk location. Falls back to Application Support when the app group
    /// is not granted, which only happens in a build without a signing team.
    static var storeURL: URL {
        let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "Larder.store")
    }

    /// CloudKit mirroring needs the iCloud entitlement, which only a signed build
    /// carries. There is no throw to catch when it is missing: Core Data's mirroring
    /// setup raises inside CloudKit on a background queue when the entitlement is
    /// absent, so the choice has to be made before the store opens.
    static var mirrors: Bool {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.icloud-services" as CFString,
            nil
        )
        return (value as? [String])?.contains("CloudKit") == true
        #elseif targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    static func container() -> ModelContainer {
        let mirror: ModelConfiguration.CloudKitDatabase =
            mirrors ? .private(cloudContainer) : .none
        if !mirrors {
            NSLog("Larder: this build has no iCloud entitlement, so the shelf stays on this device")
        }
        let configuration = ModelConfiguration(
            "Larder",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: mirror
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Larder: cannot open the pantry store at \(storeURL.path): \(error)")
        }
    }

    /// A container for the widget process, which never writes.
    static func readOnlyContainer() -> ModelContainer? {
        let configuration = ModelConfiguration(
            "Larder",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: configuration)
    }
}

/// The three facts a widget needs, gathered without waking the app's scene.
struct LarderSnapshot: Sendable {
    var pantryCount: Int = 0
    var expiringCount: Int = 0
    var openListCount: Int = 0
    var listTitles: [String] = []
    var lastMeal: String?

    static let placeholder = LarderSnapshot(
        pantryCount: 24,
        expiringCount: 3,
        openListCount: 5,
        listTitles: ["Ripe tomatoes", "Cumin", "Flat parsley", "Yogurt", "Lemon"],
        lastMeal: "Braised beans"
    )

    static func read() -> LarderSnapshot {
        guard let container = Store.readOnlyContainer() else { return .placeholder }
        let context = ModelContext(container)

        var snapshot = LarderSnapshot()
        let pantry = (try? context.fetch(FetchDescriptor<PantryItem>())) ?? []
        snapshot.pantryCount = pantry.count
        snapshot.expiringCount = pantry.filter(\.isExpiringSoon).count

        let list = ((try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? [])
            .filter { !$0.done }
            .sorted { $0.createdAt < $1.createdAt }
        snapshot.openListCount = list.count
        snapshot.listTitles = list.prefix(6).map(\.name)

        let meals = (try? context.fetch(FetchDescriptor<CookedMeal>())) ?? []
        snapshot.lastMeal = meals.max(by: { $0.cookedAt < $1.cookedAt })?.title
        return snapshot
    }
}

extension Aisle {
    static func sortedByWalk(_ aisles: some Sequence<Aisle>) -> [Aisle] {
        walkingOrder.filter { aisles.contains($0) }
    }
}
