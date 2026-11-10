// SPDX-License-Identifier: MIT
import SwiftUI

@main
struct IPanoramaxApp: App {
    @State private var settings = AppSettings()
    @State private var location = LocationService()
    @State private var library = Library()
    @State private var account = Account()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(location)
                .environment(library)
                .environment(account)
                .task { account.restore(for: settings.instance) }
                .onChange(of: settings.instanceChoice) { account.restore(for: settings.instance) }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem { Label("Aufnahme", systemImage: "camera") }
            LibraryView()
                .tabItem { Label("Serien", systemImage: "photo.stack") }
            AccountView()
                .tabItem { Label("Konto", systemImage: "person.crop.circle") }
        }
    }
}
