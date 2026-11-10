// SPDX-License-Identifier: MIT
import SwiftUI

struct LibraryView: View {
    @Environment(Library.self) private var library
    @Environment(Account.self) private var account
    @State private var uploader = Uploader()

    var body: some View {
        NavigationStack {
            List {
                if let error = uploader.lastError {
                    Text(error).foregroundStyle(.red)
                }
                ForEach(library.series) { item in
                    row(item)
                        .swipeActions {
                            Button("Löschen", role: .destructive) { library.delete(item) }
                        }
                }
            }
            .overlay {
                if library.series.isEmpty {
                    ContentUnavailableView("Noch keine Fotos", systemImage: "camera")
                }
            }
            .navigationTitle("Serien")
        }
    }

    private func row(_ item: CaptureSeries) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline)
                Text(summary(item)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if uploader.activeSeriesID == item.id {
                ProgressView(value: Double(uploader.progress.done), total: Double(max(uploader.progress.total, 1)))
                    .frame(width: 60)
            } else if item.uploadCompleted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if !item.shots.isEmpty {
                Button("Hochladen") {
                    guard let client = account.client else { return }
                    Task { await uploader.upload(item.id, library: library, client: client) }
                }
                .buttonStyle(.bordered)
                .disabled(!account.isSignedIn || uploader.activeSeriesID != nil)
            }
        }
    }

    private func summary(_ item: CaptureSeries) -> String {
        var parts = ["\(item.shots.count) Fotos"]
        if item.pendingCount > 0, item.pendingCount < item.shots.count {
            parts.append("\(item.pendingCount) offen")
        }
        if let worst = item.shots.map(\.horizontalAccuracy).max() {
            parts.append("schlechteste ±\(Int(worst)) m")
        }
        return parts.joined(separator: " · ")
    }
}
