import Foundation
import FoundationModels

let model = SystemLanguageModel.default
print("availability:", model.availability)
let session = LanguageModelSession()
do {
    let r = try await session.respond(to: "Name one dinner in three words.")
    print("plain:", r.content)
} catch {
    print("plain failed:", type(of: error), error)
}
