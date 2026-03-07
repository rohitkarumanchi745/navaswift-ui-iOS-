import SwiftUI
import Combine
import CoreLocation
import NavNetworking

@MainActor
public class LocationManager: NSObject, ObservableObject {
    @Published public var location: CLLocation?
    @Published public var city: String = "Unknown"
    @Published public var isLoading = false
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    public func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    public func updateLocation() {
        isLoading = true
        manager.requestLocation()
    }

    public var displayLocation: String {
        city == "Unknown" ? "Tap to update location" : city
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let placemark = placemarks?.first
            Task { @MainActor in
                self?.city = placemark?.locality ?? "Unknown"
                self?.isLoading = false
                self?.sendToBackend(location, placemark: placemark)
            }
        }
    }

    private func sendToBackend(_ location: CLLocation, placemark: CLPlacemark?) {
        Task {
            struct LocationResponse: Codable { let success: Bool? }
            let _: LocationResponse? = try? await APIService.shared.post(
                path: "/location/update",
                body: [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "accuracy": location.horizontalAccuracy,
                    "city": placemark?.locality ?? "",
                    "state": placemark?.administrativeArea ?? "",
                    "country": placemark?.country ?? "",
                ]
            )
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.location = location
            reverseGeocode(location)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
