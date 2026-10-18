#if os(iOS)
import SwiftUI
import SwiftData
import AVFoundation

/// Point the camera at a barcode. Known products land on the shelf in one tap.
/// Anything new gets a name once and is never asked about again.
struct ScanSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pendingCode: String?
    @State private var name = ""
    @State private var aisle: Aisle = .other
    @State private var readingLabel = false
    @State private var note: String?
    @State private var denied = false
    @State private var handled = Set<String>()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()

                if denied {
                    deniedState
                } else {
                    LiveScanner(onBarcode: handle(code:))
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .center) { reticule }
                        .overlay(alignment: .bottom) { controls }
                }

                if let note {
                    toast(note)
                }
            }
            .navigationTitle("")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.body(15, weight: .semibold))
                }
            }
            .sheet(isPresented: $readingLabel) {
                PhotoScanner { data in
                    readingLabel = false
                    read(data)
                }
                .ignoresSafeArea()
            }
            .sheet(item: Binding(
                get: { pendingCode.map(NameRequest.init(code:)) },
                set: { if $0 == nil { pendingCode = nil } }
            )) { request in
                namer(request.code)
                    .presentationDetents([.height(280)])
            }
        }
        .task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            denied = !granted
        }
    }

    // MARK: Chrome

    private var reticule: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Theme.butter, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .frame(width: 280, height: 130)
            .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Text("Point at a barcode")
                .font(Theme.body(14, weight: .medium))
                .foregroundStyle(.white)
            Button("Read a label instead") { readingLabel = true }
                .buttonStyle(PrimaryButtonStyle(fill: Theme.canvas, ink: Theme.ink))
        }
        .padding(Theme.page)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Theme.canvas)
    }

    private var deniedState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera is off")
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
            Text("Larder needs the camera to read barcodes and shelf labels. Turn it on in Settings, or type items in by hand.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            .buttonStyle(QuietButtonStyle())
        }
        .card(padding: 22)
        .padding(Theme.page)
    }

    private func toast(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(Theme.body(14, weight: .medium))
                .foregroundStyle(Theme.canvas)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.moss, in: .capsule)
                .padding(.bottom, 120)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func namer(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New product")
                .font(Theme.title(20))
                .foregroundStyle(Theme.ink)
            TextField("What is it", text: $name)
                .textFieldStyle(.plain)
                .font(Theme.body(16))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Theme.surface, in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1)
                }
            FlowRow(spacing: 6) {
                ForEach(Aisle.walkingOrder) { option in
                    Button { aisle = option } label: {
                        Chip(text: option.rawValue, tint: aisle == option ? Theme.moss : Theme.inkSoft, filled: aisle == option)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Stock it") {
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Shelf.stock(name, aisle: aisle, barcode: code, in: context)
                Shelf.remember(barcode: code, name: name, aisle: aisle, in: context)
                context.saveQuietly()
                handled.insert(code)
                pendingCode = nil
                flash("\(name) on the shelf")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer(minLength: 0)
        }
        .padding(Theme.page)
        .pageBackground()
    }

    // MARK: Work

    /// A barcode arrives several times a second while it is in frame. The set keeps
    /// the sheet from re-asking about the same product in one session.
    private func handle(code: String) {
        guard pendingCode == nil, !handled.contains(code) else { return }

        if let product = Shelf.product(for: code, in: context) {
            Shelf.stock(product.name, aisle: product.aisle, barcode: code, in: context)
            context.saveQuietly()
            handled.insert(code)
            flash("\(product.name) on the shelf")
            return
        }
        name = ""
        aisle = .other
        pendingCode = code
    }

    private func read(_ data: Data) {
        Task {
            guard Kitchen.status.canCook else {
                flash("Reading labels needs Apple Intelligence")
                return
            }
            do {
                let read = try await ShelfReader.read(imageData: data)
                let phrase = ShelfReader.shelfPhrase(from: read)
                guard !phrase.isEmpty || !read.barcodes.isEmpty else {
                    flash("No label found")
                    return
                }
                let parsed = try await BasketReader.read(phrase)
                for item in parsed {
                    Shelf.stock(
                        item.name,
                        quantity: Double(max(1, item.quantity)),
                        unit: item.unit,
                        aisle: Aisle.named(item.aisle),
                        in: context
                    )
                }
                if let code = read.barcodes.first, let first = parsed.first {
                    Shelf.remember(barcode: code, name: first.name, aisle: Aisle.named(first.aisle), in: context)
                }
                context.saveQuietly()
                flash("\(parsed.count) on the shelf")
            } catch {
                flash("Could not read that label")
            }
        }
    }

    private func flash(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { note = text }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeIn(duration: 0.25)) { note = nil }
        }
    }
}

private struct NameRequest: Identifiable {
    let code: String
    var id: String { code }
}
#endif
