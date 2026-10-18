import SwiftUI

enum Panel: String, CaseIterable, Identifiable, Hashable {
    case tonight, pantry, list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tonight: "Tonight"
        case .pantry: "Pantry"
        case .list: "List"
        }
    }

    var symbol: String {
        switch self {
        case .tonight: "flame"
        case .pantry: "square.grid.2x2"
        case .list: "checklist"
        }
    }
}

extension Panel {
    /// A capture aid: `-larder-tab pantry` opens straight onto a panel.
    static var launchPanel: Panel {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-larder-tab"), index + 1 < args.count,
           let found = Panel(rawValue: args[index + 1]) {
            return found
        }
        #endif
        return .tonight
    }
}

struct RootView: View {
    @Environment(Desk.self) private var desk
    @State private var panel: Panel = Panel.launchPanel

    var body: some View {
        #if os(iOS)
        phoneLayout
        #else
        macLayout
        #endif
    }

    #if os(iOS)
    private var phoneLayout: some View {
        TabView(selection: $panel) {
            Tab(Panel.tonight.title, systemImage: Panel.tonight.symbol, value: .tonight) {
                TonightView()
            }
            Tab(Panel.pantry.title, systemImage: Panel.pantry.symbol, value: .pantry) {
                PantryView()
            }
            Tab(Panel.list.title, systemImage: Panel.list.symbol, value: .list) {
                ListView()
            }
        }
        .tint(Theme.moss)
        .pageBackground()
    }
    #else
    private var macLayout: some View {
        NavigationSplitView {
            List(Panel.allCases, selection: $panel) { item in
                Label(item.title, systemImage: item.symbol)
                    .font(Theme.body(14, weight: .medium))
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceSunken)
        } detail: {
            Group {
                switch panel {
                case .tonight: TonightView()
                case .pantry: PantryView()
                case .list: ListView()
                }
            }
            .pageBackground()
        }
        .navigationTitle(panel.title)
    }
    #endif
}
