#if os(macOS)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// On a Mac there is no handheld lens, so the shelf comes in as a photo or a dropped
/// image. Vision reads it, the on-device model names the rows.
struct ShelfDropSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var picking = false
    @State private var working = false
    @State private var note: String?
    @State private var found: [ParsedItem] = []
    @State private var target = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Read a shelf")
                        .font(Theme.title(22))
                        .foregroundStyle(Theme.ink)
                    Text("Drop a photo of the fridge, a receipt or a label. Larder reads the words and turns them into rows.")
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                dropZone

                if !found.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "\(found.count) read")
                        FlowRow(spacing: 6) {
                            ForEach(found, id: \.name) { item in
                                Chip(text: item.name, tint: Theme.moss)
                            }
                        }
                    }
                    Button("Put them on the shelf") { commit() }
                        .buttonStyle(PrimaryButtonStyle())
                }

                if let note {
                    Text(note)
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer()
            }
            .padding(Theme.page)
            .frame(minWidth: 460, minHeight: 420, alignment: .topLeading)
            .pageBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.image, .pdf]) { result in
                switch result {
                case .success(let url):
                    ingest(url)
                case .failure(let error):
                    note = error.localizedDescription
                }
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: working ? "ellipsis" : "photo.on.rectangle.angled")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.inkSoft)
            Text(working ? "Reading" : "Drop an image here")
                .font(Theme.body(14, weight: .medium))
                .foregroundStyle(Theme.ink)
            Button("Choose a file") { picking = true }
                .buttonStyle(QuietButtonStyle())
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            ingest(url)
            return true
        }
        .onTapGesture { picking = true }
    }

    private func ingest(_ url: URL) {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            note = "That file could not be opened."
            return
        }
        read(data)
    }

    private func read(_ data: Data) {
        guard Kitchen.status.canCook else {
            note = Kitchen.status.note
            return
        }
        working = true
        Task {
            defer { working = false }
            do {
                let read = try await ShelfReader.read(imageData: data)
                let phrase = ShelfReader.shelfPhrase(from: read)
                guard !phrase.isEmpty else {
                    note = "No readable words in that image."
                    return
                }
                found = try await BasketReader.read(phrase)
                note = found.isEmpty ? "Nothing recognisable as food." : nil
            } catch {
                note = error.localizedDescription
            }
        }
    }

    private func commit() {
        for item in found {
            Shelf.stock(
                item.name,
                quantity: Double(max(1, item.quantity)),
                unit: item.unit,
                aisle: Aisle.named(item.aisle),
                in: context
            )
        }
        context.saveQuietly()
        dismiss()
    }
}
#endif
