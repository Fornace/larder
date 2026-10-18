import SwiftUI
import SwiftData

/// Typing is faster than a form. One line goes in, the on-device model splits it,
/// sorts the aisles and gets the quantities right.
struct AddSheet: View {
    var defaultAisle: Aisle = .other

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var manual = false
    @State private var working = false
    @State private var added = 0
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if manual {
                        ItemForm(
                            name: $manualName,
                            quantity: $manualQuantity,
                            unit: $manualUnit,
                            aisle: $manualAisle,
                            expires: $manualExpires
                        )
                    } else {
                        quick
                    }

                    Button(manual ? "Read a line instead" : "Fill in details by hand") {
                        manual.toggle()
                        focused = !manual
                    }
                    .buttonStyle(QuietButtonStyle())
                }
                .padding(Theme.page)
            }
            .pageBackground()
            .navigationTitle("Add")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if manual {
                        Button("Add") { addManual() }
                            .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Button(working ? "Reading" : "Add") { submit() }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
                    }
                }
            }
        }
        .onAppear { focused = true }
        .presentationDetents([.medium, .large])
    }

    private var quick: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "What came home")
            TextEditor(text: $text)
                .font(Theme.body(17))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 130)
                .focused($focused)
                .padding(12)
                .background(Theme.surface, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1)
                }
            Text("One line or several. Larder splits it, sets the quantity and picks the aisle.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
            if added > 0 {
                Chip(text: "\(added) added", tint: Theme.moss, filled: true)
            }
        }
    }

    // Detail entry

    @State private var manualName = ""
    @State private var manualQuantity = 1.0
    @State private var manualUnit = ""
    @State private var manualAisle: Aisle = .other
    @State private var manualExpires: Date?

    private func submit() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        guard Kitchen.status.canCook else {
            for line in input.split(separator: "\n") {
                Shelf.stock(String(line), in: context)
            }
            context.saveQuietly()
            dismiss()
            return
        }

        working = true
        Task {
            defer { working = false }
            do {
                let parsed = try await BasketReader.read(input)
                for item in parsed {
                    Shelf.stock(
                        item.name,
                        quantity: Double(max(1, item.quantity)),
                        unit: item.unit,
                        aisle: Aisle.named(item.aisle),
                        in: context
                    )
                }
                context.saveQuietly()
                added = parsed.count
                dismiss()
            } catch {
                // The model refused or was interrupted. The line is still what the
                // person typed, so it goes on the shelf verbatim rather than vanishing.
                Shelf.stock(input, in: context)
                context.saveQuietly()
                dismiss()
            }
        }
    }

    private func addManual() {
        Shelf.stock(
            manualName,
            quantity: manualQuantity,
            unit: manualUnit,
            aisle: manualAisle,
            in: context
        )
        context.saveQuietly()
        dismiss()
    }
}
