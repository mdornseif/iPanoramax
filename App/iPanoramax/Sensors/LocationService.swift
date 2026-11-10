// SPDX-License-Identifier: MIT
import CoreLocation
import GeoKit
import Observation
import UIKit

/// Hält GPS und Kompass dauerhaft aktiv, solange die App im Vordergrund ist.
///
/// Das ist der eigentliche Unterschied zur Kamera-App: Der Empfänger ist beim
/// Auslösen schon „warm“, und `FixFilter` gibt den Auslöser erst frei, wenn
/// die Position gut genug ist. Ein per Bluetooth gekoppelter MFi-Empfänger
/// (z. B. Bad Elf) kommt automatisch über CoreLocation herein.
@MainActor
@Observable
final class LocationService: NSObject {
    private(set) var latestFix: Fix?
    private(set) var latestHeading: HeadingReading?
    private(set) var authorization: CLAuthorizationStatus

    /// Wird bei jeder neuen Position aufgerufen; treibt den Serien-Auslöser.
    @ObservationIgnored var onFix: (@MainActor (Fix) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        authorization = .notDetermined
        super.init()
        authorization = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.headingFilter = 1
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        updateHeadingOrientation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    /// Der Kompass misst relativ zur Geräteausrichtung; im Querformat muss
    /// CoreLocation das wissen, sonst ist der Kurs um 90° verdreht.
    func updateHeadingOrientation() {
        let orientation = UIDevice.current.orientation
        let mapped: CLDeviceOrientation = switch orientation {
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        case .portraitUpsideDown: .portraitUpsideDown
        default: .portrait
        }
        manager.headingOrientation = mapped
    }

    /// Alter der letzten Position, für die Anzeige.
    func age(of fix: Fix, now: Date = .now) -> TimeInterval {
        now.timeIntervalSince(fix.timestamp)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let fix = Fix(
            coordinate: Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed,
            course: location.course,
            timestamp: location.timestamp
        )
        MainActor.assumeIsolated {
            latestFix = fix
            onFix?(fix)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let reading = HeadingReading(
            trueHeading: newHeading.trueHeading,
            accuracy: newHeading.headingAccuracy,
            timestamp: newHeading.timestamp
        )
        MainActor.assumeIsolated {
            latestHeading = reading
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                start()
            }
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}
