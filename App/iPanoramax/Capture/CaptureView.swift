// SPDX-License-Identifier: MIT
import GeoKit
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LocationService.self) private var location
    @Environment(Library.self) private var library
    @State private var model = CaptureModel()

    var body: some View {
        ZStack {
            CameraPreview(session: model.camera.session)
                .ignoresSafeArea()

            VStack {
                statusBar
                Spacer()
                if let message = model.lastMessage {
                    Text(message)
                        .font(.footnote)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                controls
            }
            .padding()

            if let error = model.cameraError {
                Text(error)
                    .padding()
                    .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .task {
            model.location = location
            model.library = library
            model.settings = settings
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            location.start()
            await model.startCamera()
        }
        .onDisappear {
            if model.isRecordingSeries { model.stopSeries() }
            model.camera.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            location.updateHeadingOrientation()
        }
    }

    // MARK: Statuszeile: Genauigkeit, Alter, Kurs

    private var statusBar: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let blocked = model.blockingReason(now: context.date)
            HStack(spacing: 12) {
                Circle()
                    .fill(blocked == nil ? .green : .orange)
                    .frame(width: 12, height: 12)
                if let fix = location.latestFix {
                    Text("±\(Int(fix.horizontalAccuracy.rounded())) m")
                        .monospacedDigit()
                    Text("\(Int(location.age(of: fix, now: context.date))) s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("kein GPS")
                }
                if let heading = location.latestHeading, heading.isUsable {
                    Text("\(Int(heading.trueHeading))° ±\(Int(heading.accuracy))")
                        .monospacedDigit()
                }
                Spacer()
                Text("Limit \(Int(settings.maximumAccuracy)) m")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Bedienung

    private var controls: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let blocked = model.blockingReason(now: context.date)
            VStack(spacing: 12) {
                if !model.isRecordingSeries {
                    Picker("Modus", selection: $model.mode) {
                        ForEach(CaptureModel.Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                switch model.mode {
                case .single:
                    shutterButton(enabled: blocked == nil && !model.isCapturing) {
                        Task { await model.takeSingleShot() }
                    }
                case .series:
                    if model.isRecordingSeries {
                        Text("\(model.shotsInActiveSeries) Fotos · alle \(Int(settings.sequenceDistance)) m")
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                        Button("Serie beenden", role: .destructive) { model.stopSeries() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Serie starten") { model.startSeries() }
                            .buttonStyle(.borderedProminent)
                    }
                }

                if let blocked {
                    Text(blocked)
                        .font(.caption)
                        .padding(6)
                        .background(.orange.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func shutterButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .strokeBorder(.white, lineWidth: 4)
                .background(Circle().fill(enabled ? .white.opacity(0.9) : .gray.opacity(0.5)))
                .frame(width: 74, height: 74)
        }
        .disabled(!enabled)
        .accessibilityLabel("Auslösen")
    }
}
