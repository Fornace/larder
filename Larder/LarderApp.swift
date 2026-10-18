import SwiftUI
import SwiftData

@main
struct LarderApp: App {
    @State private var desk = Desk()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(desk)
                .tint(Theme.moss)
                .task {
                    #if DEBUG
                    Seed.runIfAsked(Store.shared.mainContext)
                    ModelProbe.runIfAsked()
                    #endif
                }
        }
        .modelContainer(Store.shared)
        #if os(macOS)
        .defaultSize(width: 900, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Cook something") {
                    NotificationCenter.default.post(name: .larderCookNow, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        #endif
    }
}

extension Notification.Name {
    static let larderCookNow = Notification.Name("larder.cookNow")
    static let larderScan = Notification.Name("larder.scan")
}
