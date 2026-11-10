// SPDX-License-Identifier: MIT
@preconcurrency import AVFoundation

/// Rückkamera mit JPEG-Ausgabe. Alle Session-Zugriffe laufen auf einer
/// eigenen Queue; nach außen gibt es nur `async`-Methoden.
final class CameraService: @unchecked Sendable {
    enum Failure: Error, LocalizedError {
        case noCamera
        case notAuthorized
        case captureFailed(String)

        var errorDescription: String? {
            switch self {
            case .noCamera: "Keine Rückkamera gefunden."
            case .notAuthorized: "Kein Zugriff auf die Kamera. Bitte in den Einstellungen erlauben."
            case .captureFailed(let reason): "Aufnahme fehlgeschlagen: \(reason)"
            }
        }
    }

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "ipanoramax.camera")
    private var configured = false
    private var inFlight: [Int64: PhotoDelegate] = [:]
    private(set) var device: AVCaptureDevice?

    func start() async throws {
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw Failure.notAuthorized }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    if !self.configured { try self.configure() }
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw Failure.noCamera
        }
        self.device = device
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw Failure.captureFailed("Session-Konfiguration abgelehnt")
        }
        session.addInput(input)
        session.addOutput(output)
        // Serien brauchen Tempo mehr als Rauschunterdrückung.
        output.maxPhotoQualityPrioritization = .balanced
        configured = true
    }

    /// Nimmt ein Foto auf und liefert die JPEG-Daten, wie AVFoundation sie
    /// schreibt (mit Apples EXIF zu Gerät, Objektiv und Belichtung).
    func capture(rotationAngle: CGFloat) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            queue.async {
                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                settings.photoQualityPrioritization = .balanced
                if let connection = self.output.connection(with: .video),
                   connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
                let id = settings.uniqueID
                let delegate = PhotoDelegate { result in
                    self.queue.async { self.inFlight[id] = nil }
                    continuation.resume(with: result)
                }
                self.inFlight[id] = delegate
                self.output.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(CameraService.Failure.captureFailed(error.localizedDescription)))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(CameraService.Failure.captureFailed("keine Bilddaten")))
        }
    }
}
