import WidgetKit
import SwiftUI

// MARK: - Timeline

struct LarderEntry: TimelineEntry {
    let date: Date
    let snapshot: LarderSnapshot
}

struct LarderProvider: TimelineProvider {
    func placeholder(in context: Context) -> LarderEntry {
        LarderEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (LarderEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : LarderSnapshot.read()
        completion(LarderEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LarderEntry>) -> Void) {
        let entry = LarderEntry(date: .now, snapshot: LarderSnapshot.read())
        // A shelf changes when a person is in the kitchen, so a half hour cadence is
        // enough and gives the widget a reason to read the store again.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Shared marks

private enum W {
    static var canvas: Color { Theme.canvas }
    static var ink: Color { Theme.ink }
    static var soft: Color { Theme.inkSoft }
    static var moss: Color { Theme.moss }
    static var tomato: Color { Theme.tomato }
}

// MARK: - Small

struct ShelfWidget: View {
    let entry: LarderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Shelf")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(W.soft)
            Spacer(minLength: 0)
            Text("\(entry.snapshot.pantryCount)")
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .foregroundStyle(W.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(entry.snapshot.pantryCount == 1 ? "thing" : "things")
                .font(.system(size: 13))
                .foregroundStyle(W.soft)
            Spacer(minLength: 0)
            if entry.snapshot.expiringCount > 0 {
                Text("\(entry.snapshot.expiringCount) to use up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(W.canvas)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(W.tomato, in: .capsule)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium

struct ShelfAndListWidget: View {
    let entry: LarderEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shelf")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(W.soft)
                Text("\(entry.snapshot.pantryCount)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(W.ink)
                if entry.snapshot.expiringCount > 0 {
                    Text("\(entry.snapshot.expiringCount) to use up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(W.tomato)
                } else if let meal = entry.snapshot.lastMeal {
                    Text("last: \(meal)")
                        .font(.system(size: 11))
                        .foregroundStyle(W.soft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            Rectangle().fill(Theme.line).frame(width: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("To get")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(W.soft)
                if entry.snapshot.listTitles.isEmpty {
                    Text("List is clear")
                        .font(.system(size: 13))
                        .foregroundStyle(W.soft)
                } else {
                    ForEach(entry.snapshot.listTitles.prefix(4), id: \.self) { title in
                        HStack(spacing: 5) {
                            Circle().fill(W.moss).frame(width: 4, height: 4)
                            Text(title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(W.ink)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Lock screen

struct ShelfAccessoryWidget: View {
    let entry: LarderEntry

    var body: some View {
        Label("\(entry.snapshot.pantryCount) on the shelf", systemImage: "square.grid.2x2")
            .font(.system(size: 13, weight: .medium))
    }
}

// MARK: - Configuration

struct ShelfWidgetView: View {
    @Environment(\.widgetFamily) private var family

    private let entry: LarderEntry

    init(entry: LarderEntry) { self.entry = entry }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: ShelfWidget(entry: entry)
            #if os(iOS)
            case .accessoryInline: ShelfAccessoryWidget(entry: entry)
            #endif
            default: ShelfAndListWidget(entry: entry)
            }
        }
        .containerBackground(W.canvas, for: .widget)
    }
}

struct LarderShelfWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LarderShelf", provider: LarderProvider()) { entry in
            ShelfWidgetView(entry: entry)
        }
        .configurationDisplayName("The shelf")
        .description("What is at home right now, and what is about to go off.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

@main
struct LarderWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LarderShelfWidget()
    }
}
