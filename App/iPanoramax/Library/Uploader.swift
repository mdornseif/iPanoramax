// SPDX-License-Identifier: MIT
import Foundation
import Observation
import PanoramaxKit

/// Lädt eine Serie im Vordergrund hoch. Bricht es ab, wird beim nächsten
/// Versuch dasselbe Upload-Set weiterverwendet und nur der Rest geschickt.
@MainActor
@Observable
final class Uploader {
    private(set) var activeSeriesID: UUID?
    private(set) var progress: (done: Int, total: Int) = (0, 0)
    private(set) var lastError: String?

    func upload(_ seriesID: UUID, library: Library, client: PanoramaxClient) async {
        guard activeSeriesID == nil, var item = library.current(seriesID) else { return }
        activeSeriesID = seriesID
        lastError = nil
        defer { activeSeriesID = nil }

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(seriesID.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        do {
            if item.uploadSetID == nil {
                // Kein `user_agent` im Body: OSM-FR antwortet darauf mit 500
                // (siehe docs/rapports/).
                let set = try await client.createUploadSet(UploadSetRequest(
                    title: item.title,
                    estimatedNbFiles: item.shots.count,
                    sortMethod: .timeAscending
                ))
                item.uploadSetID = set.id
                library.update(item)
            }
            guard let uploadSetID = item.uploadSetID else { return }

            let pending = item.shots.filter { !$0.uploaded }
            progress = (item.shots.count - pending.count, item.shots.count)

            for shot in pending {
                let prepared = try await client.makeUploadRequest(
                    uploadSetID: uploadSetID,
                    pictureID: shot.id,
                    jpegURL: library.fileURL(for: shot, in: item),
                    bodyDirectory: scratch
                )
                let contentType = prepared.request.value(forHTTPHeaderField: "Content-Type") ?? ""
                do {
                    try await client.uploadPreparedFile(
                        uploadSetID: uploadSetID,
                        bodyFileURL: prepared.bodyFileURL,
                        contentType: contentType
                    )
                } catch PanoramaxError.server(let status, _) where status == 409 {
                    // Bild mit dieser picture_id ist schon da: als erledigt werten.
                }
                try? FileManager.default.removeItem(at: prepared.bodyFileURL)
                if let index = item.shots.firstIndex(where: { $0.id == shot.id }) {
                    item.shots[index].uploaded = true
                }
                library.update(item)
                progress.done += 1
            }

            try await client.completeUploadSet(id: uploadSetID)
            item.uploadCompleted = true
            library.update(item)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
