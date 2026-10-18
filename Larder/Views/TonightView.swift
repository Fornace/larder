import SwiftUI
import SwiftData

/// The answer to the only question that matters at seven: what is dinner.
struct TonightView: View {
    @Environment(\.modelContext) private var context
    @Environment(Desk.self) private var desk
    @Query private var pantry: [PantryItem]
    @Query private var list: [ShoppingItem]

    @State private var didCook = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if desk.idea != nil {
                    reading
                } else {
                    waiting
                }
            }
            .pageBackground()
            .navigationTitle("")
            .inlineTitle()
        }
        .onAppear(perform: maybeCook)
        .sensoryFeedback(.success, trigger: didCook)
        .sheet(isPresented: $showsSettings) { SettingsView() }
    }

    /// A dinner on screen: the page scrolls under a fixed title.
    private var reading: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                masthead
                content
                actions
            }
            .padding(Theme.page)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    /// No dinner yet. Rather than one card in a field of nothing, the page shows the
    /// card and then the few things on the shelf that want eating this week.
    private var waiting: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                masthead
                content
                if !urgent.isEmpty { urgentBlock }
            }
            .padding(Theme.page)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            if !pantry.isEmpty {
                footer.padding(.horizontal, Theme.page).padding(.bottom, 2)
            }
        }
    }

    /// Sorted by date, not by opinion: the arithmetic a cook does in their head.
    private var urgent: [PantryItem] {
        pantry
            .filter { ($0.daysLeft ?? .max) <= 3 }
            .sorted { ($0.daysLeft ?? .max) < ($1.daysLeft ?? .max) }
            .prefix(5)
            .map { $0 }
    }

    private var urgentBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Eat these first")
            VStack(spacing: 0) {
                ForEach(Array(urgent.enumerated()), id: \.element.persistentModelID) { index, item in
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(Theme.body(15, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        if let days = item.daysLeft {
                            Chip(
                                text: days < 0 ? "past it" : days == 0 ? "today" : "\(days)d",
                                tint: Theme.tomato
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    if index < urgent.count - 1 {
                        Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 14)
                    }
                }
            }
            .card(padding: 0, radius: 16)
        }
    }

    /// The bottom line that keeps the page from ending in empty canvas.
    private var footer: some View {
        HStack(spacing: 6) {
            Text("\(pantry.count) on the shelf")
            if openCount > 0 {
                Text("·")
                Text("\(openCount) to get")
            }
            Spacer(minLength: 0)
        }
        .font(Theme.body(12))
        .foregroundStyle(Theme.inkSoft)
        .opacity(0.85)
    }

    // MARK: Head

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Eyebrow(text: greeting)
                if desk.isCooking { Pulse() }
                Spacer()
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .buttonStyle(.plain)
            }
            if desk.idea == nil && !desk.isCooking {
                Text("Dinner")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    /// The weekday, not a greeting. It dates the page without adding a sentence.
    private var openCount: Int { list.count { !$0.done } }

    private var greeting: String {
        Date.now.formatted(.dateTime.weekday(.wide))
    }

    // MARK: Body

    @ViewBuilder
    private var content: some View {
        if let problem = desk.problem {
            EmptyNote(
                title: "The kitchen went quiet",
                line: problem,
                action: (title: "Try again", run: {
                    desk.clear()
                    cook()
                })
            )
        } else if !desk.status.canCook {
            unavailableCard
        } else if pantry.isEmpty {
            EmptyNote(
                title: "Nothing to cook from",
                line: "Larder needs to know what is on the shelf before it can name a dinner. Add three things and it works."
            )
        } else if let idea = desk.idea {
            ideaCard(idea)
        } else if desk.isCooking {
            skeleton
        } else {
            startCard
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "On-device model", tint: Theme.tomato)
            Text("Dinner ideas are asleep")
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
            Text(desk.status.note)
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 22)
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ready when you are")
                .font(Theme.title(24))
                .foregroundStyle(Theme.ink)
            Text("\(pantry.count) things on the shelf. Larder will pick one dinner and tell you the shortest way to it.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Cook from the shelf") { cook() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .card(padding: 22)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.surfaceSunken)
                .frame(height: 34)
                .frame(maxWidth: 300)
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.surfaceSunken)
                .frame(height: 14)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 22)
        .opacity(0.85)
    }

    private func ideaCard(_ idea: DinnerIdea.PartiallyGenerated) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = idea.title, !title.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(Theme.display(32))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let why = idea.why, !why.isEmpty {
                        Text(why)
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let minutes = idea.minutes, let have = idea.have {
                HStack(spacing: 8) {
                    Chip(text: Format.minutes(minutes), tint: Theme.moss, filled: true)
                    Chip(text: "\(have.count) from your shelf", tint: Theme.inkSoft)
                    Spacer()
                }
            }

            coverage(idea)

            if let have = idea.have, !have.isEmpty {
                ingredientBlock(title: "You have", names: have, missing: false)
            }
            if let missing = idea.missing, !missing.isEmpty {
                ingredientBlock(title: "Pick up", names: missing.compactMap(\.name), missing: true)
            }

            if let steps = idea.steps, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Method")
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(Theme.number(12, weight: .semibold))
                                .foregroundStyle(Theme.canvas)
                                .frame(width: 20, height: 20)
                                .background(Theme.moss, in: .circle)
                            Text(step)
                                .font(Theme.body(15))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 22)
    }

    private func coverage(_ idea: DinnerIdea.PartiallyGenerated) -> some View {
        let have = idea.have?.count ?? 0
        let missing = idea.missing?.count ?? 0
        let total = max(1, have + missing)
        return VStack(alignment: .leading, spacing: 6) {
            Meter(value: Double(have) / Double(total))
            Text(missing == 0 ? "Everything is already home" : "\(missing) to buy")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func ingredientBlock(title: String, names: [String], missing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: title, tint: missing ? Theme.tomato : Theme.inkSoft)
            FlowRow(spacing: 6) {
                ForEach(names, id: \.self) { name in
                    Chip(text: name, tint: missing ? Theme.tomato : Theme.inkSoft)
                }
            }
        }
    }

    // MARK: Foot

    @ViewBuilder
    private var actions: some View {
        if desk.idea != nil {
            VStack(spacing: 10) {
                if let done = desk.finished, desk.isCooking == false {
                    Button(didCook ? "Logged. It is off the shelf." : "Cooked it") {
                        Shelf.cooked(done, in: context)
                        context.saveQuietly()
                        didCook = true
                        desk.clear()
                        cook()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(didCook)
                }
                HStack(spacing: 10) {
                    Button("Another idea") {
                        desk.clear()
                        cook()
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
    }

    // MARK: Work

    private func maybeCook() {
        guard desk.status.canCook, !pantry.isEmpty, desk.idea == nil, !desk.isCooking else { return }
        cook()
    }

    private func cook() {
        didCook = false
        desk.cook(shelf: shelf, avoid: Shelf.recentMeals(in: context))
    }

    private var shelf: [ShelfItem] {
        pantry.map {
            ShelfItem(
                name: $0.name,
                quantity: $0.quantity,
                unit: $0.unit,
                aisle: $0.aisle.rawValue,
                daysLeft: $0.daysLeft
            )
        }
    }
}

// MARK: - Small pieces

/// Three flat dots, no gradient, that say "the model is writing".
struct Pulse: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.inkSoft)
                    .frame(width: 4, height: 4)
                    .opacity(0.25 + 0.75 * max(0, sin(phase - Double(index) * 0.8)))
            }
        }
        .task {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

/// Chips that wrap onto as many lines as they need.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
