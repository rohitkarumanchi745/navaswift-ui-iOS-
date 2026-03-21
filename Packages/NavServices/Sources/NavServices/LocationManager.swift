import SwiftUI
import CoreLocation
import NavCore
import NavNetworking

@MainActor
public class LocationManager: NSObject, ObservableObject {
    @Published public var location: CLLocation?
    @Published public var city: String = "Unknown"
    @Published public var country: String = ""
    @Published public var countryCode: String = ""
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
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            let placemark = placemarks?.first
            if let error {
                NavLog.warning("Reverse geocode failed: \(error.localizedDescription)", category: .general)
            }
            Task { @MainActor in
                self?.city = placemark?.locality ?? "Unknown"
                self?.country = placemark?.country ?? ""
                self?.countryCode = placemark?.isoCountryCode ?? ""
                self?.isLoading = false
                self?.sendToBackend(location, placemark: placemark)
            }
        }
    }

    private func sendToBackend(_ location: CLLocation, placemark: CLPlacemark?) {
        Task {
            struct LocationResponse: Codable { let success: Bool? }
            do {
                let _: LocationResponse = try await APIService.shared.post(
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
            } catch {
                NavLog.warning("Location update to backend failed: \(error.localizedDescription)", category: .network)
            }
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
            NavLog.warning("Location manager error: \(error.localizedDescription)", category: .general)
            self.isLoading = false
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                updateLocation()
            }
        }
    }
}
