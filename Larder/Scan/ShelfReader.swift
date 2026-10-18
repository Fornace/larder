import Foundation
import Vision

/// Reads a photo of a shelf or a package with Vision, then hands the raw text to
/// the on-device model. No network, no product database, no account.
enum ShelfReader {
    struct Read: Sendable, Equatable {
        var barcodes: [String] = []
        var words: [String] = []

        var joined: String { words.joined(separator: "\n") }
        var isEmpty: Bool { words.isEmpty && barcodes.isEmpty }
    }

    static func read(imageData: Data) async throws -> Read {
        var result = Read()

        var barcodeRequest = DetectBarcodesRequest()
        barcodeRequest.symbologies = [.ean13, .ean8, .upce, .code128, .code39, .itf14]
        if let observations = try? await barcodeRequest.perform(on: imageData) {
            result.barcodes = observations.compactMap(\.payloadString).reduce(into: [String]()) { unique, code in
                if !unique.contains(code) { unique.append(code) }
            }
        }

        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        if let observations = try? await textRequest.perform(on: imageData) {
            result.words = observations
                .map { $0.transcript.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 1 }
        }

        return result
    }

    /// Keeps the recognisable part of a label: the bold name lines and the words
    /// that read like food, dropping barcodes, weights and legal filler.
    static func shelfPhrase(from read: Read) -> String {
        let noise: Set<String> = ["ingredients", "nutrition", "best before", "store in", "keep refrigerated"]
        let lines = read.words.filter { line in
            let lower = line.lowercased()
            guard noise.contains(where: { lower.hasPrefix($0) }) == false else { return false }
            guard line.rangeOfCharacter(from: .letters) != nil else { return false }
            return line.count <= 60
        }
        return lines.prefix(12).joined(separator: "\n")
    }
}
