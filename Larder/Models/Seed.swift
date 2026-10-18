#if DEBUG
import Foundation
import SwiftData

/// Fills the store with a believable kitchen so the app can be looked at and
/// photographed. Only ever runs when the app is launched with `-larder-seed`.
@MainActor
enum Seed {
    static func runIfAsked(_ context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-larder-seed") else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<PantryItem>())) ?? 0
        guard existing == 0 else { return }

        for row in kitchen {
            context.insert(
                PantryItem(
                    name: row.name,
                    quantity: row.quantity,
                    unit: row.unit,
                    aisle: row.aisle,
                    expires: row.days.map { Calendar.current.date(byAdding: .day, value: $0, to: .now) ?? .now }
                )
            )
        }

        for row in shopping {
            context.insert(ShoppingItem(name: row.0, aisle: row.1, fromDinner: row.2))
        }

        context.insert(CookedMeal(title: "Lemon roast chicken"))

        do {
            try context.save()
        } catch {
            NSLog("Larder: seed failed \(error)")
        }
    }

    private struct Row {
        var name: String
        var quantity: Double
        var unit: String
        var aisle: Aisle
        var days: Int?
    }

    private static let kitchen: [Row] = [
        Row(name: "Ripe tomatoes", quantity: 6, unit: "", aisle: .produce, days: 1),
        Row(name: "Spinach", quantity: 1, unit: "bag", aisle: .produce, days: 2),
        Row(name: "Lemons", quantity: 3, unit: "", aisle: .produce, days: nil),
        Row(name: "Garlic", quantity: 1, unit: "head", aisle: .produce, days: nil),
        Row(name: "Yellow onions", quantity: 4, unit: "", aisle: .produce, days: nil),
        Row(name: "Flat parsley", quantity: 1, unit: "bunch", aisle: .produce, days: 3),
        Row(name: "Chicken thighs", quantity: 6, unit: "", aisle: .protein, days: 1),
        Row(name: "Pancetta", quantity: 1, unit: "pack", aisle: .protein, days: 5),
        Row(name: "Eggs", quantity: 8, unit: "", aisle: .dairy, days: nil),
        Row(name: "Whole milk", quantity: 1, unit: "l", aisle: .dairy, days: 4),
        Row(name: "Parmesan", quantity: 1, unit: "wedge", aisle: .dairy, days: nil),
        Row(name: "Greek yogurt", quantity: 1, unit: "tub", aisle: .dairy, days: 6),
        Row(name: "Butter", quantity: 1, unit: "block", aisle: .dairy, days: nil),
        Row(name: "Chickpeas", quantity: 2, unit: "cans", aisle: .dryGoods, days: nil),
        Row(name: "Spaghetti", quantity: 1, unit: "pack", aisle: .dryGoods, days: nil),
        Row(name: "Carnaroli rice", quantity: 1, unit: "pack", aisle: .dryGoods, days: nil),
        Row(name: "Cumin", quantity: 1, unit: "jar", aisle: .spices, days: nil),
        Row(name: "Smoked paprika", quantity: 1, unit: "jar", aisle: .spices, days: nil),
        Row(name: "Chilli flakes", quantity: 1, unit: "jar", aisle: .spices, days: nil),
        Row(name: "Sourdough", quantity: 1, unit: "loaf", aisle: .bakery, days: 1),
        Row(name: "Peas", quantity: 1, unit: "bag", aisle: .frozen, days: nil),
    ]

    private static let shopping: [(String, Aisle, Bool)] = [
        ("Capers", .dryGoods, false),
        ("Anchovies", .protein, false),
        ("Saffron", .spices, true),
        ("Rosemary", .produce, true),
        ("Ricotta", .dairy, false),
    ]
}
#endif
