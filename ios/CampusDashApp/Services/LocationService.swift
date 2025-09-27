import Foundation
import CoreLocation

final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    private let manager = CLLocationManager()
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentLocation: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    func requestPermissions() {
        manager.requestAlwaysAuthorization()
    }

    func startMonitoring(halls: [DiningHall]) {
        for hall in halls {
            let region = CLCircularRegion(center: hall.coordinate, radius: hall.geofenceRadius, identifier: hall.id)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }
        manager.startUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}
