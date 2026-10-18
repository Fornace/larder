#if DEBUG
import Foundation
import FoundationModels

/// Diagnostic runs for the on-device model, only reachable with `-larder-probe-fm`.
/// Answers one question: which part of the stack fails on this machine.
enum ModelProbe {
    static func runIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains("-larder-probe-fm") else { return }
        Task {
            await run()
        }
    }

    private static func run() async {
        log("general availability: \(SystemLanguageModel.default.availability)")

        await attempt("plain/default", guardrails: .default) { session in
            try await session.respond(to: "Name one dinner in three words.").content
        }
        await attempt("plain/permissive", guardrails: .permissiveContentTransformations) { session in
            try await session.respond(to: "Name one dinner in three words.").content
        }
        await attempt("tagging/default", guardrails: .default, useCase: .contentTagging) { session in
            try await session.respond(to: "Name one dinner in three words.").content
        }
        await attempt("structured/permissive", guardrails: .permissiveContentTransformations) { session in
            let idea = try await session.respond(
                to: "Pantry: tomatoes, chickpeas, garlic, parsley. Name one dinner.",
                generating: DinnerIdea.self
            ).content
            return idea.title
        }
    }

    private static func attempt(
        _ label: String,
        guardrails: SystemLanguageModel.Guardrails,
        useCase: SystemLanguageModel.UseCase = .general,
        _ body: (LanguageModelSession) async throws -> String
    ) async {
        let model = SystemLanguageModel(useCase: useCase, guardrails: guardrails)
        guard case .available = model.availability else {
            log("\(label): unavailable \(model.availability)")
            return
        }
        let session = LanguageModelSession(model: model)
        do {
            let value = try await body(session)
            log("\(label): OK -> \(value)")
        } catch {
            log("\(label): FAIL -> \(error)")
        }
    }

    private static func log(_ text: String) {
        NSLog("LARDERPROBE \(text)")
    }
}
#endif
