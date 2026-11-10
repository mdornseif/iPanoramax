// SPDX-License-Identifier: MIT
import Foundation
import Observation
import PanoramaxKit

/// Alle Einstellungen der Ein-Nutzer-App, in UserDefaults abgelegt.
@MainActor
@Observable
final class AppSettings {
    enum InstanceChoice: String, CaseIterable, Identifiable {
        case openStreetMapFrance
        case ign

        var id: String { rawValue }

        var label: String {
            switch self {
            case .openStreetMapFrance: "OSM France (CC-BY-SA 4.0)"
            case .ign: "IGN (Licence Ouverte 2.0)"
            }
        }

        var instance: PanoramaxInstance {
            switch self {
            case .openStreetMapFrance: .openStreetMapFrance
            case .ign: .ign
            }
        }
    }

    private let defaults = UserDefaults.standard

    var instanceChoice: InstanceChoice {
        didSet { defaults.set(instanceChoice.rawValue, forKey: Keys.instance) }
    }

    /// Schlechtere Positionen sperren den Auslöser.
    var maximumAccuracy: Double {
        didSet { defaults.set(maximumAccuracy, forKey: Keys.accuracy) }
    }

    /// Abstand zwischen zwei Fotos einer Serie, in Metern.
    var sequenceDistance: Double {
        didSet { defaults.set(sequenceDistance, forKey: Keys.distance) }
    }

    var instance: PanoramaxInstance { instanceChoice.instance }

    init() {
        instanceChoice = defaults.string(forKey: Keys.instance)
            .flatMap(InstanceChoice.init(rawValue:)) ?? .openStreetMapFrance
        let accuracy = defaults.double(forKey: Keys.accuracy)
        maximumAccuracy = accuracy > 0 ? accuracy : 10
        let distance = defaults.double(forKey: Keys.distance)
        sequenceDistance = distance > 0 ? distance : 5
    }

    private enum Keys {
        static let instance = "instance"
        static let accuracy = "maximumAccuracy"
        static let distance = "sequenceDistance"
    }
}
