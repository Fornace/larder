import SwiftUI
import SwiftData

/// The shelf: what is at home, grouped the way a kitchen is grouped, with the things
/// that need eating standing out.
struct PantryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\PantryItem.name)]) private var items: [PantryItem]

    @State private var search = ""
    @State private var adding = false
    @State private var scanning = false
    @State private var editing: PantryItem?

    private var visible: [PantryItem] {
        guard !search.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var groups: [(aisle: Aisle, items: [PantryItem])] {
        let byAisle = Dictionary(grouping: visible, by: \.aisle)
        return Aisle.sortedByWalk(byAisle.keys).map { (aisle: $0, items: byAisle[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.gap) {
                    header
                    searchField
                    if items.isEmpty {
                        emptyShelf
                    } else if visible.isEmpty {
                        EmptyNote(title: "Nothing called that", line: "No shelf row matches \(search).")
                    } else {
                        ForEach(groups, id: \.aisle) { group in
                            aisleBlock(group.aisle, group.items)
                        }
                    }
                }
                .padding(Theme.page)
                .padding(.bottom, 96)
            }
            .pageBackground()
            .navigationTitle("")
            .toolbar { toolbar }
        }
        .sheet(isPresented: $adding) {
            AddSheet(defaultAisle: .produce)
        }
        #if os(iOS)
        .sheet(isPresented: $scanning) {
            ScanSheet()
        }
        #else
        .sheet(isPresented: $scanning) {
            ShelfDropSheet()
        }
        #endif
        .sheet(item: $editing) { item in
            ItemSheet(item: item)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenTitle(title: "Pantry", detail: items.isEmpty ? nil : "\(items.count) things")
            let soon = items.filter(\.isExpiringSoon).count
            if soon > 0 {
                HStack(spacing: 8) {
                    Chip(text: "\(soon) to use up", tint: Theme.tomato, filled: true)
                    Text("these go in dinner first")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(.bottom, 2)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            TextField("Search the shelf", text: $search)
                .textFieldStyle(.plain)
                .font(Theme.body(15))
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.surface, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1)
        }
    }

    private var emptyShelf: some View {
        EmptyNote(
            title: "The shelves are dark",
            line: "Scan a barcode, read a label, or type what is in the fridge. Dinner gets better with every row.",
            action: (title: "Add the first thing", run: { adding = true })
        )
    }

    private func aisleBlock(_ aisle: Aisle, _ rows: [PantryItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: aisle.rawValue)
                Spacer()
                Text("\(rows.count)")
                    .font(Theme.number(12))
                    .foregroundStyle(Theme.inkSoft)
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.persistentModelID) { index, item in
                    PantryRow(item: item) { editing = item }
                        .contextMenu {
                            Button("Edit") { editing = item }
                            Button("Put on the list") {
                                Shelf.addToList(item.name, quantity: 1, unit: item.unit, aisle: item.aisle, in: context)
                                context.saveQuietly()
                            }
                            Divider()
                            Button("Remove", role: .destructive) {
                                context.delete(item)
                                context.saveQuietly()
                            }
                        }
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Theme.line)
                            .frame(height: 1)
                            .padding(.leading, 2)
                    }
                }
            }
            .card(padding: 0, radius: 16)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                scanning = true
            } label: {
                Label("Scan", systemImage: "barcode.viewfinder")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                adding = true
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }
}

// MARK: - Row

private struct PantryRow: View {
    @Environment(\.modelContext) private var context
    let item: PantryItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(Theme.body(15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(measure)
                            .font(Theme.number(12))
                            .foregroundStyle(Theme.inkSoft)
                        if let days = item.daysLeft, days <= 2 {
                            Chip(
                                text: days < 0 ? "past it" : days == 0 ? "today" : "\(days)d",
                                tint: Theme.tomato
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            QuantityStepper {
                item.quantity -= 1
                if item.quantity <= 0 { context.delete(item) }
                context.saveQuietly()
            } onPlus: {
                item.quantity += 1
                context.saveQuietly()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var measure: String {
        let count = Format.quantity(item.quantity)
        return item.unit.isEmpty ? count : "\(count) \(item.unit)"
    }
}

