#if os(iOS)
import SwiftUI
import VisionKit
import AVFoundation

/// Live camera scanning. Barcodes resolve instantly against products this device has
/// already named; a label photo goes to Vision and the on-device model.
struct LiveScanner: UIViewControllerRepresentable {
    var onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .code39, .itf14])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard DataScannerViewController.isSupported, !controller.isScanning else { return }
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let parent: LiveScanner
        private var lastCode: String?
        private var lastCodeAt = Date.distantPast

        init(_ parent: LiveScanner) { self.parent = parent }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue else { continue }
                // A shelf held in front of the lens repeats the same code many times a second.
                guard payload != lastCode || Date.now.timeIntervalSince(lastCodeAt) > 2 else { continue }
                lastCode = payload
                lastCodeAt = .now
                parent.onBarcode(payload)
            }
        }
    }
}

/// Falls back to a still photo when the live scanner is not supported.
struct PhotoScanner: UIViewControllerRepresentable {
    var onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: PhotoScanner
        init(_ parent: PhotoScanner) { self.parent = parent }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else { return }
            let image = scan.imageOfPage(at: 0)
            if let data = image.jpegData(compressionQuality: 0.82) {
                parent.onImage(data)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {}
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) {
            NSLog("Larder: camera failed \(error)")
        }
    }
}
#endif
