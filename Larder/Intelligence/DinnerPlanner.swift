import Foundation
import FoundationModels

// MARK: - What the model is asked to produce

@Generable
struct MissingIngredient: Equatable, Sendable {
    @Guide(description: "The ingredient, two words at most, lower case, no quantities")
    var name: String

    @Guide(
        description: "The shop aisle this belongs to",
        .anyOf(["Produce", "Protein", "Dairy", "Dry goods", "Spices", "Bakery", "Frozen", "Other"])
    )
    var aisle: String
}

/// A concrete dinner for tonight, built out of what is already on the shelf.
@Generable
struct DinnerIdea: Equatable, Sendable {
    @Guide(description: "Dish name, three to five words, title case, no quotes, no brand names")
    var title: String

    @Guide(description: "One sentence, at most sixteen words, on why this is the right cook tonight")
    var why: String

    @Guide(description: "Minutes from opening the fridge to a plate", .range(10...120))
    var minutes: Int

    @Guide(description: "Pantry ingredients this dish uses, named exactly as the pantry lists them", .count(2...8))
    var have: [String]

    @Guide(description: "Things this dish needs that the pantry does not have, at most three", .count(0...3))
    var missing: [MissingIngredient]

    @Guide(description: "Cooking steps in order, one short sentence each, no numbering", .count(3...7))
    var steps: [String]
}

// MARK: - Availability

enum KitchenStatus: Equatable, Sendable {
    case ready
    case needsHardware
    case needsSetting
    case preparing

    var note: String {
        switch self {
        case .ready: ""
        case .needsHardware:
            "This Mac or iPhone cannot run Apple Intelligence, so Larder will not invent a dinner. Your pantry and list still sync."
        case .needsSetting:
            "Turn on Apple Intelligence in System Settings to let Larder read your shelf and cook from it."
        case .preparing:
            "The on-device model is still downloading. Your shelf and list work in the meantime."
        }
    }

    var canCook: Bool { self == .ready }
}

@MainActor
enum Kitchen {
    static var status: KitchenStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .needsHardware
            case .appleIntelligenceNotEnabled: return .needsSetting
            case .modelNotReady: return .preparing
            @unknown default: return .needsSetting
            }
        }
    }
}

// MARK: - Requests

/// A shelf, flattened for prompting. A value type so it crosses actors without a context.
struct ShelfItem: Sendable, Equatable {
    var name: String
    var quantity: Double
    var unit: String
    var aisle: String
    var daysLeft: Int?
}

struct CookRequest: Sendable {
    var shelf: [ShelfItem]
    var avoid: [String]
    var mood: String?
    var servings: Int

    var prompt: String {
        var lines: [String] = []
        lines.append("What I have at home:")
        if shelf.isEmpty {
            lines.append("- nothing recorded")
        } else {
            for item in shelf.sorted(by: { $0.name < $1.name }) {
                var line = "- \(item.name)"
                if item.quantity > 1 || !item.unit.isEmpty {
                    line += " (\(Format.quantity(item.quantity))\(item.unit.isEmpty ? "" : " \(item.unit)"))"
                }
                if let days = item.daysLeft, days <= 3 {
                    line += days < 0 ? " [past its date]" : " [use within \(days)d]"
                }
                lines.append(line)
            }
        }
        lines.append("")
        lines.append("Cook for \(servings) \(servings == 1 ? "person" : "people").")
        if !avoid.isEmpty {
            lines.append("Already cooked recently, do not repeat: \(avoid.joined(separator: ", ")).")
        }
        if let mood, !mood.isEmpty {
            lines.append("Tonight I want: \(mood).")
        }
        lines.append("Pick one dinner. Lead with what is about to go off. Ask me to buy at most three things.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - The generator

/// Holds the on-device session off the main actor so the shelf stays scrollable
/// while a dinner is being written.
actor KitchenBench {
    private var cached: LanguageModelSession?

    private static let instructions = """
    You are the cook of a small household. You get a list of what is actually in the kitchen and you name one \
    dinner that can be made tonight, mostly from that list. You are concrete, you never pad, and you never \
    suggest a dish that needs a shopping trip to be worth eating. If something is close to its date, it goes \
    in the dish. Names come straight from the list so the cook can trust the match.
    """

    private func languageSession() -> LanguageModelSession {
        if let cached { return cached }
        let fresh = LanguageModelSession(instructions: Self.instructions)
        cached = fresh
        return fresh
    }

    /// Forgets the conversation. Called when the shelf changes underneath a suggestion.
    func reset() {
        cached = nil
    }

    func stream(_ request: CookRequest) -> AsyncThrowingStream<DinnerIdea.PartiallyGenerated, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream = languageSession().streamResponse(
                        to: request.prompt,
                        generating: DinnerIdea.self,
                        options: GenerationOptions(temperature: 0.8)
                    )
                    for try await snapshot in stream {
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Formatting

enum Format {
    static func quantity(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    static func minutes(_ value: Int) -> String {
        value <= 0 ? "under an hour" : "\(value) min"
    }
}
