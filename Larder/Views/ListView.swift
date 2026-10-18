import SwiftUI
import SwiftData

/// The list that is already on the other device.
struct ListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ShoppingItem.createdAt)]) private var items: [ShoppingItem]

    @State private var draft = ""
    @State private var moved = 0
    @FocusState private var typing: Bool

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty }

    private var open: [ShoppingItem] { items.filter { !$0.done } }
    private var done: [ShoppingItem] { items.filter(\.done) }

    private var groups: [(aisle: Aisle, items: [ShoppingItem])] {
        let byAisle = Dictionary(grouping: open, by: \.aisle)
        return Aisle.sortedByWalk(byAisle.keys).map { (aisle: $0, items: byAisle[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.gap) {
                    ScreenTitle(title: "List", detail: open.isEmpty ? nil : "\(open.count) to get")

                    entry

                    if items.isEmpty {
                        EmptyNote(
                            title: "Nothing to get",
                            line: "Type a line above, or cook something in Tonight and the missing few land here."
                        )
                    } else {
                        shoppingCard
                        if !done.isEmpty { finishedBlock }
                    }
                }
                .padding(Theme.page)
                .padding(.bottom, 96)
                .frame(maxWidth: 620, alignment: .leading)
            }
            .pageBackground()
            .navigationTitle("")
            .safeAreaInset(edge: .bottom) { footer }
        }
    }

    private var entry: some View {
        HStack(spacing: 8) {
            TextField("Add something", text: $draft)
                .textFieldStyle(.plain)
                .font(Theme.body(15))
                .focused($typing)
                .onSubmit(commit)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.surface, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1)
                }
            Button {
                commit()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSend ? Theme.canvas : Theme.inkSoft)
                    .frame(width: 46, height: 46)
                    .background(
                        canSend ? Theme.moss : Theme.surfaceSunken,
                        in: .rect(cornerRadius: 14)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    /// One card for the shop, with the aisle as a quiet rule inside it. A list of five
    /// things should read as one list, not five stacked cards.
    private var shoppingCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.aisle) { groupIndex, group in
                HStack {
                    Text(group.aisle.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(Theme.inkSoft)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.top, groupIndex == 0 ? 12 : 14)
                .padding(.bottom, 6)

                ForEach(Array(group.items.enumerated()), id: \.element.persistentModelID) { index, item in
                    ListRow(item: item)
                    if index < group.items.count - 1 {
                        Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 46)
                    }
                }
                if groupIndex < groups.count - 1 {
                    Rectangle().fill(Theme.line).frame(height: 1)
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .card(padding: 0, radius: 16)
    }

    private var finishedBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "In the basket")
            VStack(spacing: 0) {
                ForEach(Array(done.enumerated()), id: \.element.persistentModelID) { index, item in
                    ListRow(item: item)
                    if index < done.count - 1 {
                        Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 46)
                    }
                }
            }
            .card(padding: 0, radius: 16)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if !done.isEmpty {
            VStack(spacing: 0) {
                Button {
                    moved = Shelf.moveCheckedToPantry(in: context)
                    context.saveQuietly()
                } label: {
                    Text(moved > 0 ? "Moved \(moved) to the pantry" : "Move \(done.count) into the pantry")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(moved > 0)
                .padding(.horizontal, Theme.page)
                .padding(.vertical, 10)
            }
            .background(Theme.canvas)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.line).frame(height: 1)
            }
        }
    }

    private func commit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        moved = 0

        // One tap should not wait on a language model. The line lands immediately,
        // then the on-device model refines the aisle and the plural in place.
        let line = Shelf.addToList(text, in: context)
        context.saveQuietly()

        guard Kitchen.status.canCook else { return }
        Task {
            guard let parsed = try? await BasketReader.readOne(text) else { return }
            let label = parsed.name.isEmpty ? text : parsed.name
            line.name = label
            line.quantity = max(1, Double(parsed.quantity))
            line.unit = parsed.unit
            line.aisle = Aisle.named(parsed.aisle)
            context.saveQuietly()
        }
    }
}

private struct ListRow: View {
    @Environment(\.modelContext) private var context
    let item: ShoppingItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.done.toggle()
                context.saveQuietly()
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: item.done ? .semibold : .regular))
                    .foregroundStyle(item.done ? Theme.moss : Theme.inkSoft.opacity(0.6))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            Text(item.name)
                .font(Theme.body(15, weight: item.done ? .regular : .medium))
                .foregroundStyle(item.done ? Theme.inkSoft : Theme.ink)
                .strikethrough(item.done, color: Theme.inkSoft)
                .lineLimit(2)

            Spacer(minLength: 4)

            if item.fromDinner {
                Chip(text: "dinner", tint: Theme.tomato)
            }
            if item.quantity > 1 {
                Text("×\(Format.quantity(item.quantity))")
                    .font(Theme.number(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                context.delete(item)
                context.saveQuietly()
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                context.delete(item)
                context.saveQuietly()
            }
        }
    }
}
