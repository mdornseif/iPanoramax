// SPDX-License-Identifier: MIT
import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

/// Drehwinkel für das Foto aus der aktuellen Gerätelage. Die App-Oberfläche
/// bleibt im Hochformat, das Foto folgt der tatsächlichen Haltung.
@MainActor
func captureRotationAngle() -> CGFloat {
    switch UIDevice.current.orientation {
    case .landscapeLeft: 0
    case .landscapeRight: 180
    case .portraitUpsideDown: 270
    default: 90
    }
}
