import Foundation
import FoundationModels

func check(_ label: String, _ model: SystemLanguageModel) async {
    print(label, "availability:", model.availability)
    let session = LanguageModelSession(model: model)
    do {
        let r = try await session.respond(to: "List three vegetables as a comma separated line.")
        print(label, "ok:", r.content)
    } catch {
        print(label, "failed:", error)
    }
}

try await check("general", SystemLanguageModel(useCase: .general))
try await check("contentTagging", SystemLanguageModel(useCase: .contentTagging))
