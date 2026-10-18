import Foundation
import SwiftData

/// Everything that changes the store. Views never write rows directly, so the rules
/// about what happens when you cook a meal live in one place.
@MainActor
enum Shelf {
    // MARK: Pantry

    @discardableResult
    static func stock(
        _ name: String,
        quantity: Double = 1,
        unit: String = "",
        aisle: Aisle = .other,
        barcode: String? = nil,
        in context: ModelContext
    ) -> PantryItem {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = match(clean, in: context) {
            existing.quantity += quantity
            existing.barcode = barcode ?? existing.barcode
            return existing
        }
        let item = PantryItem(name: clean, quantity: quantity, unit: unit, aisle: aisle, barcode: barcode)
        context.insert(item)
        return item
    }

    /// Tolerant lookup used when a dinner idea names an ingredient the way the pantry
    /// named it, and when a second scan of the same product comes in.
    static func match(_ name: String, in context: ModelContext) -> PantryItem? {
        let pantry = (try? context.fetch(FetchDescriptor<PantryItem>())) ?? []
        let needle = normalise(name)
        guard !needle.isEmpty else { return nil }
        if let exact = pantry.first(where: { normalise($0.name) == needle }) { return exact }
        return pantry.first { item in
            let hay = normalise(item.name)
            return hay.hasPrefix(needle) || needle.hasPrefix(hay)
        }
    }

    static func product(for barcode: String, in context: ModelContext) -> KnownProduct? {
        let descriptor = FetchDescriptor<KnownProduct>(predicate: #Predicate { $0.barcode == barcode })
        return try? context.fetch(descriptor).first
    }

    static func remember(barcode: String, name: String, aisle: Aisle, in context: ModelContext) {
        if let existing = product(for: barcode, in: context) {
            existing.name = name
            existing.aisleRaw = aisle.rawValue
            existing.lastSeen = .now
        } else {
            context.insert(KnownProduct(barcode: barcode, name: name, aisle: aisle))
        }
    }

    // MARK: List

    @discardableResult
    static func addToList(
        _ name: String,
        quantity: Double = 1,
        unit: String = "",
        aisle: Aisle = .other,
        fromDinner: Bool = false,
        in context: ModelContext
    ) -> ShoppingItem {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let open = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        if let existing = open.first(where: { !$0.done && normalise($0.name) == normalise(clean) }) {
            existing.quantity += quantity
            return existing
        }
        let item = ShoppingItem(name: clean, quantity: quantity, unit: unit, aisle: aisle, fromDinner: fromDinner)
        context.insert(item)
        return item
    }

    /// Checked lines become pantry rows, because a bought thing is a thing you have.
    static func moveCheckedToPantry(in context: ModelContext) -> Int {
        let list = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        let checked = list.filter(\.done)
        for line in checked {
            stock(line.name, quantity: line.quantity, unit: line.unit, aisle: line.aisle, in: context)
            context.delete(line)
        }
        return checked.count
    }

    // MARK: Cooking

    /// Records the meal and takes the used ingredients off the shelf. Anything left
    /// at zero leaves the pantry, so the next suggestion is honest.
    static func cooked(_ idea: DinnerIdea, in context: ModelContext) {
        context.insert(CookedMeal(title: idea.title))
        for name in idea.have {
            guard let item = match(name, in: context) else { continue }
            item.quantity -= 1
            if item.quantity <= 0 {
                context.delete(item)
            }
        }
        for missing in idea.missing {
            addToList(
                missing.name,
                aisle: Aisle.named(missing.aisle),
                fromDinner: true,
                in: context
            )
        }
    }

    static func recentMeals(in context: ModelContext, limit: Int = 6) -> [String] {
        let meals = (try? context.fetch(FetchDescriptor<CookedMeal>())) ?? []
        return meals
            .sorted { $0.cookedAt > $1.cookedAt }
            .prefix(limit)
            .map(\.title)
    }

    // MARK: Helpers

    static func normalise(_ text: String) -> String {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
        return folded.hasSuffix("s") ? String(folded.dropLast()) : folded
    }
}

extension ModelContext {
    func saveQuietly() {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            NSLog("Larder: save failed \(error)")
        }
    }
}
