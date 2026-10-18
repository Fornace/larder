import Foundation
import SwiftUI
import FoundationModels

/// The state of one evening: what is on the stove, what it will take to finish it.
@MainActor
@Observable
final class Desk {
    var idea: DinnerIdea.PartiallyGenerated?
    var isCooking = false
    var problem: String?
    var mood = ""
    var servings = 2
    var showsListing = false

    private let bench = KitchenBench()
    private var job: Task<Void, Never>?

    var isThinking: Bool { isCooking && (idea?.title ?? "").isEmpty }

    var finished: DinnerIdea? { idea?.completed }

    var status: KitchenStatus { Kitchen.status }

    func cook(shelf: [ShelfItem], avoid: [String]) {
        job?.cancel()
        idea = nil
        problem = nil
        isCooking = true

        let request = CookRequest(shelf: shelf, avoid: avoid, mood: mood, servings: servings)
        job = Task { [bench] in
            do {
                for try await partial in await bench.stream(request) {
                    self.idea = partial
                }
            } catch is CancellationError {
                // A newer request replaced this one.
            } catch {
                NSLog("Larder: dinner generation failed: \(error)")
                self.problem = Self.explain(error)
            }
            self.isCooking = false
            self.job = nil
        }
    }

    func stop() {
        job?.cancel()
        job = nil
        isCooking = false
    }

    func clear() {
        stop()
        idea = nil
        problem = nil
    }

    /// Hand the session back when the shelf changed underneath it.
    func forget() async {
        clear()
        await bench.reset()
    }

    func describeProblem(_ text: String) {
        problem = text
    }

    /// The raw error goes to the log. The screen gets a sentence a cook can act on.
    private static func explain(_ error: any Error) -> String {
        guard let generation = error as? LanguageModelSession.GenerationError else {
            return "The on-device model stopped before it finished. Your shelf is untouched."
        }
        switch generation {
        case .assetsUnavailable:
            return "The on-device model is not installed yet. Turn on Apple Intelligence, then try again."
        case .guardrailViolation:
            return "That request tripped the on-device safety check. Try another mood."
        case .unsupportedLanguageOrLocale:
            return "The on-device model does not cover this language yet."
        case .exceededContextWindowSize:
            return "There is more on your shelf than one prompt holds. Remove a few rows."
        case .rateLimited:
            return "The model is busy. Give it a moment, then try again."
        case .concurrentRequests:
            return "Another idea is still being written. Let it finish."
        case .decodingFailure, .unsupportedGuide:
            return "The answer did not come through cleanly. Try again."
        case .refusal:
            return "The model declined that one. Try a different mood."
        @unknown default:
            return "The on-device model stopped before it finished. Try again."
        }
    }
}

extension DinnerIdea.PartiallyGenerated {
    /// A partial snapshot only counts as a dinner once every field has landed.
    var completed: DinnerIdea? {
        guard let title, let why, let minutes, let have, let missing, let steps,
              !title.isEmpty, !steps.isEmpty
        else { return nil }
        return DinnerIdea(
            title: title,
            why: why,
            minutes: minutes,
            have: have,
            missing: missing.compactMap { part in
                guard let name = part.name, !name.isEmpty else { return nil }
                return MissingIngredient(name: name, aisle: part.aisle ?? Aisle.other.rawValue)
            },
            steps: steps
        )
    }
}
