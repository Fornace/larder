import SwiftUI
import SwiftData

/// The shared field set for a pantry item, used by the quick sheet's manual mode and
/// by the edit sheet.
struct ItemForm: View {
    @Binding var name: String
    @Binding var quantity: Double
    @Binding var unit: String
    @Binding var aisle: Aisle
    @Binding var expires: Date?

    private var usesDate: Binding<Bool> {
        Binding(
            get: { expires != nil },
            set: { expires = $0 ? Calendar.current.startOfDay(for: .now) : nil }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            field("Name") {
                TextField("Whole milk", text: $name)
                    .textFieldStyle(.plain)
                    .font(Theme.body(16))
            }

            HStack(spacing: 12) {
                field("How many") {
                    HStack(spacing: 10) {
                        Text(Format.quantity(quantity))
                            .font(Theme.number(16))
                            .foregroundStyle(Theme.ink)
                        Stepper("", value: $quantity, in: 0.5...99, step: 0.5)
                            .labelsHidden()
                    }
                }
                field("Unit") {
                    TextField("g, can, bunch", text: $unit)
                        .textFieldStyle(.plain)
                        .font(Theme.body(16))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Aisle")
                FlowRow(spacing: 6) {
                    ForEach(Aisle.walkingOrder) { option in
                        Button {
                            aisle = option
                        } label: {
                            Chip(text: option.rawValue, tint: aisle == option ? Theme.moss : Theme.inkSoft, filled: aisle == option)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: usesDate) {
                    Text("Has a date")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.moss)
                if let expires {
                    DatePicker("Use by", selection: Binding(
                        get: { expires },
                        set: { self.expires = $0 }
                    ), displayedComponents: .date)
                        .font(Theme.body(15))
                        .tint(Theme.moss)
                }
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: label)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1)
                }
        }
    }
}

/// Edit one row on the shelf.
struct ItemSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let item: PantryItem

    @State private var name = ""
    @State private var quantity = 1.0
    @State private var unit = ""
    @State private var aisle: Aisle = .other
    @State private var expires: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                ItemForm(
                    name: $name,
                    quantity: $quantity,
                    unit: $unit,
                    aisle: $aisle,
                    expires: $expires
                )
                .padding(Theme.page)
            }
            .pageBackground()
            .navigationTitle("")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            name = item.name
            quantity = item.quantity
            unit = item.unit
            aisle = item.aisle
            expires = item.expires
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        item.name = name
        item.quantity = quantity
        item.unit = unit
        item.aisle = aisle
        item.expires = expires
        context.saveQuietly()
        dismiss()
    }
}
