import AppIntents
import FoundationModels
import SwiftData
import Foundation

/// Put something on the list without opening the app.
struct AddToListIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Larder list"
    static let description = IntentDescription(
        "Puts an item on the shopping list that syncs to the other devices."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Item", requestValueDialog: "What should go on the list?")
    var item: String

    init() {}

    init(item: String) { self.item = item }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(Store.shared)
        let line = Shelf.addToList(item, in: context)
        context.saveQuietly()
        return .result(dialog: "\(line.name) is on the list.")
    }
}

/// Put something in the cupboard after a shop.
struct StockIntent: AppIntent {
    static let title: LocalizedStringResource = "Stock Larder"
    static let description = IntentDescription("Adds something you already have to the pantry shelf.")
    static let openAppWhenRun = false

    @Parameter(title: "Item", requestValueDialog: "What did you put away?")
    var item: String

    init() {}

    init(item: String) { self.item = item }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(Store.shared)
        guard Kitchen.status.canCook else {
            Shelf.stock(item, in: context)
            context.saveQuietly()
            return .result(dialog: "\(item) is on the shelf.")
        }
        let parsed = try? await BasketReader.readOne(item)
        let name = parsed?.name.isEmpty == false ? parsed!.name : item
        Shelf.stock(
            name,
            quantity: Double(max(1, parsed?.quantity ?? 1)),
            unit: parsed?.unit ?? "",
            aisle: Aisle.named(parsed?.aisle ?? Aisle.other.rawValue),
            in: context
        )
        context.saveQuietly()
        return .result(dialog: "\(name) is on the shelf.")
    }
}

/// The whole point of the app, spoken to Siri or the Mac's menu.
struct DinnerTonightIntent: AppIntent {
    static let title: LocalizedStringResource = "What is for dinner"
    static let description = IntentDescription(
        "Reads your pantry and names one dinner you can cook tonight from what is already at home."
    )
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard Kitchen.status.canCook else {
            return .result(dialog: "Larder needs Apple Intelligence turned on to think of a dinner.")
        }

        let context = ModelContext(Store.shared)
        let pantry = (try? context.fetch(FetchDescriptor<PantryItem>())) ?? []
        guard !pantry.isEmpty else {
            return .result(dialog: "The pantry is empty. Add a few things first and I will cook from them.")
        }

        let shelf = pantry.map {
            ShelfItem(
                name: $0.name,
                quantity: $0.quantity,
                unit: $0.unit,
                aisle: $0.aisle.rawValue,
                daysLeft: $0.daysLeft
            )
        }
        let request = CookRequest(
            shelf: shelf,
            avoid: Shelf.recentMeals(in: context),
            mood: nil,
            servings: 2
        )

        let session = LanguageModelSession(instructions: """
            You are the cook of a small household. You name one dinner that can be made tonight from what \
            is already in the kitchen, and you say it out loud in two sentences.
            """)
        let response = try await session.respond(to: request.prompt, generating: DinnerIdea.self)
        let idea = response.content

        let shopping = idea.missing.map(\.name)
        let tail = shopping.isEmpty
            ? "Everything you need is home."
            : "You need \(ListFormatter.localizedString(byJoining: shopping))."
        return .result(dialog: "\(idea.title). \(idea.why) \(tail)")
    }
}

struct LarderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DinnerTonightIntent(),
            phrases: [
                "What is for dinner in \(.applicationName)",
                "Ask \(.applicationName) what to cook",
            ],
            shortTitle: "What is for dinner",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: AddToListIntent(),
            phrases: [
                "Add to \(.applicationName) list",
                "Put it on the \(.applicationName) list",
            ],
            shortTitle: "Add to list",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: StockIntent(),
            phrases: [
                "Stock the \(.applicationName) pantry",
                "Put something away in \(.applicationName)",
            ],
            shortTitle: "Stock the pantry",
            systemImageName: "square.grid.2x2"
        )
    }
}
