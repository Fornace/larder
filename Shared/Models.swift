import Foundation
import SwiftData

/// A shelf-stable grouping used by the pantry, the list and the recipe model.
/// Stored as a raw string so it stays queryable under CloudKit sync.
enum Aisle: String, CaseIterable, Codable, Sendable, Identifiable {
    case produce = "Produce"
    case protein = "Protein"
    case dairy = "Dairy"
    case dryGoods = "Dry goods"
    case spices = "Spices"
    case bakery = "Bakery"
    case frozen = "Frozen"
    case other = "Other"

    var id: String { rawValue }

    /// Order used everywhere so the aisle a person walks first comes first.
    static var walkingOrder: [Aisle] {
        [.produce, .protein, .dairy, .bakery, .dryGoods, .spices, .frozen, .other]
    }

    static func named(_ raw: String) -> Aisle {
        if let exact = Aisle(rawValue: raw) { return exact }
        let needle = raw.lowercased()
        if let loose = Aisle.allCases.first(where: { $0.rawValue.lowercased() == needle }) {
            return loose
        }
        if needle.contains("veg") || needle.contains("fruit") || needle.contains("herb") {
            return .produce
        }
        if needle.contains("meat") || needle.contains("fish") || needle.contains("poultry") {
            return .protein
        }
        if needle.contains("spice") || needle.contains("season") { return .spices }
        return .other
    }
}

/// Something on a shelf at home.
@Model
final class PantryItem {
    var name: String = ""
    var quantity: Double = 1
    var unit: String = ""
    var aisleRaw: String = Aisle.other.rawValue
    var expires: Date?
    var addedAt: Date = Date()
    var barcode: String?

    init(
        name: String,
        quantity: Double = 1,
        unit: String = "",
        aisle: Aisle = .other,
        expires: Date? = nil,
        barcode: String? = nil
    ) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.aisleRaw = aisle.rawValue
        self.expires = expires
        self.addedAt = Date()
        self.barcode = barcode
    }

    var aisle: Aisle {
        get { Aisle.named(aisleRaw) }
        set { aisleRaw = newValue.rawValue }
    }

    var daysLeft: Int? {
        guard let expires else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: expires).day
    }

    var isExpiringSoon: Bool {
        guard let daysLeft else { return false }
        return daysLeft <= 2
    }
}

/// Something to buy. Lives in the same store so it syncs across devices.
@Model
final class ShoppingItem {
    var name: String = ""
    var quantity: Double = 1
    var unit: String = ""
    var aisleRaw: String = Aisle.other.rawValue
    var done: Bool = false
    var createdAt: Date = Date()
    /// True when the line came from a dinner idea rather than typed by hand.
    var fromDinner: Bool = false

    init(
        name: String,
        quantity: Double = 1,
        unit: String = "",
        aisle: Aisle = .other,
        fromDinner: Bool = false
    ) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.aisleRaw = aisle.rawValue
        self.fromDinner = fromDinner
        self.createdAt = Date()
    }

    var aisle: Aisle {
        get { Aisle.named(aisleRaw) }
        set { aisleRaw = newValue.rawValue }
    }
}

/// What has actually been cooked, so "another idea" stops repeating itself.
@Model
final class CookedMeal {
    var title: String = ""
    var cookedAt: Date = Date()

    init(title: String) {
        self.title = title
        self.cookedAt = Date()
    }
}

/// Barcode to name memory. First scan of a product asks once, every later scan is instant
/// and works with no network.
@Model
final class KnownProduct {
    var barcode: String = ""
    var name: String = ""
    var aisleRaw: String = Aisle.other.rawValue
    var lastSeen: Date = Date()

    init(barcode: String, name: String, aisle: Aisle) {
        self.barcode = barcode
        self.name = name
        self.aisleRaw = aisle.rawValue
        self.lastSeen = Date()
    }

    var aisle: Aisle { Aisle.named(aisleRaw) }
}
