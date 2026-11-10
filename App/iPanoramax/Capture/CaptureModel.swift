// SPDX-License-Identifier: MIT
import Foundation
import GeoKit
import ImageMetadataKit
import Observation
import UIKit

/// Verbindet Kamera, GPS und Ablage. Hier sitzt die Regel, die der
/// Kamera-App fehlt: ohne gute, frische Position wird nicht ausgelöst.
@MainActor
@Observable
final class CaptureModel {
    enum Mode: String, CaseIterable, Identifiable {
        case single = "Einzelfoto"
        case series = "Serie"
        var id: String { rawValue }
    }

    var mode: Mode = .single
    private(set) var activeSeriesID: UUID?
    private(set) var isCapturing = false
    private(set) var lastMessage: String?
    private(set) var shotsInActiveSeries = 0
    private(set) var cameraError: String?

    let camera = CameraService()
    private var trigger: CaptureTrigger?
    private let assembler = CaptureMetadataAssembler(software: Account.userAgent)

    // Werden von der View gesetzt.
    var location: LocationService?
    var library: Library?
    var settings: AppSettings?

    var isRecordingSeries: Bool { activeSeriesID != nil }

    private var filter: FixFilter {
        FixFilter(maximumHorizontalAccuracy: settings?.maximumAccuracy ?? 10, maximumAge: 3)
    }

    /// Warum gerade nicht ausgelöst werden darf, oder `nil`.
    func blockingReason(now: Date = .now) -> String? {
        guard let fix = location?.latestFix else { return "Warte auf GPS …" }
        return filter.rejection(for: fix, now: now).map { "Gesperrt: \($0.description)" }
    }

    func startCamera() async {
        do {
            try await camera.start()
            cameraError = nil
        } catch {
            cameraError = error.localizedDescription
        }
    }

    // MARK: Einzelfoto

    func takeSingleShot() async {
        guard let library else { return }
        let series = library.todaysSingleShotSeries()
        await capture(into: series.id)
    }

    // MARK: Serie

    func startSeries() {
        guard let library, let settings else { return }
        let title = "Serie \(Date.now.formatted(date: .numeric, time: .shortened))"
        let series = library.newSeries(title: title)
        activeSeriesID = series.id
        shotsInActiveSeries = 0
        trigger = CaptureTrigger(mode: .distance(metres: settings.sequenceDistance), minimumInterval: 1.0)
        UIApplication.shared.isIdleTimerDisabled = true
        location?.onFix = { [weak self] fix in
            self?.handle(fix)
        }
    }

    func stopSeries() {
        activeSeriesID = nil
        trigger = nil
        location?.onFix = nil
        UIApplication.shared.isIdleTimerDisabled = false
        lastMessage = "Serie beendet: \(shotsInActiveSeries) Fotos"
    }

    private func handle(_ fix: Fix) {
        guard let seriesID = activeSeriesID, let trigger, !isCapturing else { return }
        guard filter.accepts(fix, now: .now) else { return }
        if case .capture = trigger.decision(for: fix) {
            Task { await self.capture(into: seriesID) }
        }
    }

    // MARK: Aufnahme

    private func capture(into seriesID: UUID) async {
        guard !isCapturing, let library, let location else { return }
        guard let fix = location.latestFix, filter.accepts(fix, now: .now) else {
            lastMessage = blockingReason()
            return
        }
        isCapturing = true
        defer { isCapturing = false }

        do {
            let raw = try await camera.capture(rotationAngle: captureRotationAngle())
            // Position zum Auslösezeitpunkt, nicht die nach der Verarbeitung.
            let metadata = assembler.metadata(fix: fix, compass: location.latestHeading)
            let jpeg = try ImageMetadataWriter.writingMetadata(metadata, into: raw)
            let shotID = UUID()
            let shot = Shot(
                id: shotID,
                fileName: "\(shotID.uuidString).jpg",
                takenAt: fix.timestamp,
                latitude: fix.coordinate.latitude,
                longitude: fix.coordinate.longitude,
                horizontalAccuracy: fix.horizontalAccuracy
            )
            try library.add(jpeg: jpeg, shot: shot, to: seriesID)
            trigger?.recordCapture(at: fix)
            if seriesID == activeSeriesID { shotsInActiveSeries += 1 }
            lastMessage = "Gespeichert (±\(Int(fix.horizontalAccuracy)) m)"
        } catch {
            lastMessage = error.localizedDescription
        }
    }
}
