// SPDX-License-Identifier: MIT
import Foundation
import Observation

/// Ein aufgenommenes Foto, bereits mit GPS-/EXIF-Daten im JPEG.
struct Shot: Codable, Identifiable, Hashable, Sendable {
    /// Wird als `picture_id` an Panoramax geschickt: ein erneuter Upload nach
    /// einem Abbruch erzeugt so kein Duplikat.
    var id: UUID
    var fileName: String
    var takenAt: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var uploaded: Bool = false
}

/// Eine Serie = ein Upload-Set bei Panoramax. Einzelfotos landen in einer
/// Tages-Serie.
struct CaptureSeries: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var shots: [Shot] = []
    var uploadSetID: UUID?
    var uploadCompleted: Bool = false

    var pendingCount: Int { shots.filter { !$0.uploaded }.count }
}

/// Ablage im Documents-Ordner: pro Serie ein Verzeichnis mit `series.json`
/// und den JPEGs. Über die Dateien-App einsehbar.
@MainActor
@Observable
final class Library {
    private(set) var series: [CaptureSeries] = []
    private let root: URL

    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Serien", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        load()
    }

    func directory(for series: CaptureSeries) -> URL {
        root.appendingPathComponent(series.id.uuidString, isDirectory: true)
    }

    func fileURL(for shot: Shot, in series: CaptureSeries) -> URL {
        directory(for: series).appendingPathComponent(shot.fileName)
    }

    func newSeries(title: String) -> CaptureSeries {
        let item = CaptureSeries(id: UUID(), title: title, createdAt: .now)
        try? FileManager.default.createDirectory(at: directory(for: item), withIntermediateDirectories: true)
        series.insert(item, at: 0)
        persist(item)
        return item
    }

    /// Serie für Einzelfotos des heutigen Tages, wird bei Bedarf angelegt.
    func todaysSingleShotSeries() -> CaptureSeries {
        let title = "Einzelfotos \(Date.now.formatted(date: .numeric, time: .omitted))"
        if let existing = series.first(where: { $0.title == title && !$0.uploadCompleted }) {
            return existing
        }
        return newSeries(title: title)
    }

    func add(jpeg: Data, shot: Shot, to seriesID: UUID) throws {
        guard let index = series.firstIndex(where: { $0.id == seriesID }) else { return }
        try jpeg.write(to: fileURL(for: shot, in: series[index]), options: .atomic)
        series[index].shots.append(shot)
        persist(series[index])
    }

    func update(_ item: CaptureSeries) {
        guard let index = series.firstIndex(where: { $0.id == item.id }) else { return }
        series[index] = item
        persist(item)
    }

    func delete(_ item: CaptureSeries) {
        try? FileManager.default.removeItem(at: directory(for: item))
        series.removeAll { $0.id == item.id }
    }

    func current(_ id: UUID) -> CaptureSeries? {
        series.first { $0.id == id }
    }

    private func persist(_ item: CaptureSeries) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(item) else { return }
        try? data.write(to: directory(for: item).appendingPathComponent("series.json"), options: .atomic)
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        series = folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("series.json")) else { return nil }
            return try? decoder.decode(CaptureSeries.self, from: data)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}
