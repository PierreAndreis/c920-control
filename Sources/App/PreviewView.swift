import SwiftUI
import AVFoundation

/// Live preview of the C920 using AVFoundation. The session is torn down when the view disappears.
struct PreviewView: NSViewRepresentable {
    final class Coordinator {
        let session = AVCaptureSession()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        let layer = AVCaptureVideoPreviewLayer(session: context.coordinator.session)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        start(context.coordinator.session)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.session.stopRunning()
    }

    private func start(_ session: AVCaptureSession) {
        let vidPid = "VendorID_\(CameraModel.vendorID) ProductID_\(CameraModel.productID)"
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }
            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: .video, position: .unspecified)
            guard let camera = discovery.devices.first(where: { $0.modelID.contains(vidPid) }),
                  let input = try? AVCaptureDeviceInput(device: camera) else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            if session.canAddInput(input) { session.addInput(input) }
            session.commitConfiguration()
            session.startRunning()
        }
    }
}
