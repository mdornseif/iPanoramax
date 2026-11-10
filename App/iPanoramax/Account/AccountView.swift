// SPDX-License-Identifier: MIT
import SwiftUI

struct AccountView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Account.self) private var account
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Panoramax-Instanz") {
                    Picker("Instanz", selection: $settings.instanceChoice) {
                        ForEach(AppSettings.InstanceChoice.allCases) { Text($0.label).tag($0) }
                    }
                    accountState
                }

                Section {
                    Picker("Max. Ungenauigkeit", selection: $settings.maximumAccuracy) {
                        ForEach([5.0, 10, 15, 20, 30], id: \.self) { Text("\(Int($0)) m").tag($0) }
                    }
                    Picker("Abstand in Serien", selection: $settings.sequenceDistance) {
                        ForEach([3.0, 5, 10, 20], id: \.self) { Text("\(Int($0)) m").tag($0) }
                    }
                } header: {
                    Text("Aufnahme")
                } footer: {
                    Text("Ist die GPS-Position ungenauer oder älter als 3 s, bleibt der Auslöser gesperrt.")
                }
            }
            .navigationTitle("Konto")
        }
    }

    @ViewBuilder
    private var accountState: some View {
        switch account.state {
        case .signedOut:
            Button("Anmelden") {
                Task {
                    if let url = await account.beginSignIn() { openURL(url) }
                }
            }
        case .waitingForClaim(let url):
            VStack(alignment: .leading, spacing: 8) {
                Label("Warte auf Bestätigung im Browser …", systemImage: "hourglass")
                Button("Link erneut öffnen") { openURL(url) }
            }
        case .signedIn(let name):
            LabeledContent("Angemeldet als", value: name)
            Button("Abmelden", role: .destructive) {
                Task { await account.signOut() }
            }
        case .failed(let message):
            Text(message).foregroundStyle(.red)
            Button("Erneut anmelden") {
                Task {
                    if let url = await account.beginSignIn() { openURL(url) }
                }
            }
        }
    }
}
