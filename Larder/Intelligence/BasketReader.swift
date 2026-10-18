import Foundation
import FoundationModels

/// One item the on-device model pulled out of a typed line, a spoken line or a
/// shelf label read by the camera.
@Generable
struct ParsedItem: Equatable, Sendable {
    @Guide(description: "The item as a person would say it, for example 'chickpeas' or 'whole milk'")
    var name: String

    @Guide(description: "How many, as a number. Use 1 when the line does not say", .range(1...99))
    var quantity: Int

    @Guide(description: "The unit if one was said, for example g, kg, can, jar, bunch. Empty when none")
    var unit: String

    @Guide(
        description: "The shop aisle",
        .anyOf(["Produce", "Protein", "Dairy", "Dry goods", "Spices", "Bakery", "Frozen", "Other"])
    )
    var aisle: String
}

@Generable
struct ParsedBasket: Equatable, Sendable {
    @Guide(description: "Every separate item found in the text", .count(1...12))
    var items: [ParsedItem]
}

/// Turns messy text into structured pantry rows. The text can be typed, dictated,
/// read off a label by Vision, or pasted from a recipe.
@MainActor
enum BasketReader {
    static func read(_ text: String) async throws -> [ParsedItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let session = LanguageModelSession(instructions: """
            You turn shopping and shelf text into clean kitchen records. You split comma lists, you keep \
            quantities attached to the right item, and you choose the aisle a person would actually walk to. \
            You never invent an item that is not in the text.
            """)

        let response = try await session.respond(
            to: "Read these items:\n\(trimmed)",
            generating: ParsedBasket.self,
            options: GenerationOptions(temperature: 0.2)
        )
        return response.content.items
    }

    /// A single line fast path, used by the add field and by App Intents.
    static func readOne(_ text: String) async throws -> ParsedItem? {
        try await read(text).first
    }
}
