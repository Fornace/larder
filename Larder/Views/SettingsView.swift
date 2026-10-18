import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var pantry: [PantryItem]
    @Query private var list: [ShoppingItem]
    @Query private var meals: [CookedMeal]

    @State private var confirmingEmpty = false

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    row("On-device model", Kitchen.status.note.isEmpty ? "Ready" : Kitchen.status.note)
                    row("Sync", "Your pantry and list live in your own iCloud and appear on every device signed in to it. Nothing is sent anywhere else.")
                    row("Privacy", "No account, no analytics, no requests to a server. What you have for dinner stays on the device.")
                    row("On this device", "\(pantry.count) shelf rows, \(list.filter { !$0.done }.count) to buy, \(meals.count) meals cooked.")

                    Button(confirmingEmpty ? "Tap again to empty" : "Empty the pantry") {
                        if confirmingEmpty {
                            for item in pantry { context.delete(item) }
                            context.saveQuietly()
                            confirmingEmpty = false
                        } else {
                            confirmingEmpty = true
                        }
                    }
                    .buttonStyle(QuietButtonStyle())
                    .foregroundStyle(Theme.tomato)

                    Text("Larder \(version)")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding(Theme.page)
            }
            .pageBackground()
            .navigationTitle("Settings")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: title)
            Text(body)
                .font(Theme.body(14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}
