// SPDX-License-Identifier: MIT
import Foundation
import Observation
import PanoramaxKit

/// Anmeldung per „generate & claim“: Die App erzeugt ein Token, du ordnest es
/// im Browser deinem Konto zu, die App wartet darauf.
@MainActor
@Observable
final class Account {
    enum State: Equatable {
        case signedOut
        case waitingForClaim(URL)
        case signedIn(userName: String)
        case failed(String)
    }

    private(set) var state: State = .signedOut
    private(set) var client: PanoramaxClient?
    private var host = ""

    var isSignedIn: Bool {
        if case .signedIn = state { true } else { false }
    }

    func restore(for instance: PanoramaxInstance) {
        host = instance.apiBaseURL.host() ?? instance.apiBaseURL.absoluteString
        if let stored = Keychain.load(host: host) {
            client = PanoramaxClient(instance: instance, token: stored.jwt, userAgent: Self.userAgent)
            state = .signedIn(userName: stored.userName ?? "angemeldet")
        } else {
            client = PanoramaxClient(instance: instance, userAgent: Self.userAgent)
            state = .signedOut
        }
    }

    /// Erzeugt ein Token und liefert die URL, die im Browser geöffnet werden muss.
    func beginSignIn() async -> URL? {
        guard let client else { return nil }
        do {
            let token = try await client.generateToken(description: "iPanoramax (Ein-Nutzer-Build)")
            guard let claimURL = token.claimURL else {
                state = .failed("Server hat keinen Claim-Link geliefert.")
                return nil
            }
            state = .waitingForClaim(claimURL)
            Task { await self.finishSignIn(token: token) }
            return claimURL
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    private func finishSignIn(token: PanoramaxToken) async {
        guard let client else { return }
        do {
            let user = try await client.waitForTokenClaim()
            try Keychain.save(.init(id: token.id, jwt: token.jwtToken, userName: user.name), host: host)
            state = .signedIn(userName: user.name)
        } catch {
            state = .failed("Anmeldung nicht abgeschlossen: \(error.localizedDescription)")
        }
    }

    func signOut() async {
        if let stored = Keychain.load(host: host), let client {
            try? await client.revokeToken(id: stored.id)
            await client.setToken(nil)
        }
        Keychain.delete(host: host)
        state = .signedOut
    }

    static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "iPanoramax/\(version)"
    }()
}
