import SwiftUI
import MapKit
import CoreLocation
import NavCore
import NavServices

struct SocialLocationSearchSheet: View {
    @Binding var selectedLocation: String
    @Binding var selectedLatitude: Double?
    @Binding var selectedLongitude: Double?
    var userLocation: CLLocation?
    @EnvironmentObject var mapSearchService: MapSearchService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if let loc = userLocation {
                    Section {
                        Button {
                            selectCurrentLocation(loc)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Circle())

                                Text("Use Current Location")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)

                                Spacer()

                                if isSearching && searchText.isEmpty {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                }

                if !results.isEmpty {
                    Section("Nearby Places") {
                        ForEach(results, id: \.self) { item in
                            Button {
                                selectMapItem(item)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                        .frame(width: 32, height: 32)
                                        .background(Color.orange.opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        if let subtitle = formatSubtitle(item) {
                                            Text(subtitle)
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.5))
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.1, green: 0.1, blue: 0.14))
            .searchable(text: $searchText, prompt: "Search places")
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if !selectedLocation.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Remove") {
                            selectedLocation = ""
                            selectedLatitude = nil
                            selectedLongitude = nil
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                if let loc = userLocation {
                    searchNearby(location: loc)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func selectCurrentLocation(_ location: CLLocation) {
        isSearching = true
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            let placemark = placemarks?.first
            let city = placemark?.locality ?? "Unknown"
            let country = placemark?.country ?? ""
            selectedLocation = country.isEmpty ? city : "\(city), \(country)"
            selectedLatitude = location.coordinate.latitude
            selectedLongitude = location.coordinate.longitude

            mapSearchService.trackSearch(
                query: "current_location",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                placeName: selectedLocation
            )

            isSearching = false
            dismiss()
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        let name = item.name ?? ""
        let locality = item.placemark.locality ?? ""
        let country = item.placemark.country ?? ""

        if !locality.isEmpty && locality != name {
            selectedLocation = "\(name), \(locality)"
        } else if !country.isEmpty {
            selectedLocation = "\(name), \(country)"
        } else {
            selectedLocation = name
        }

        selectedLatitude = item.placemark.coordinate.latitude
        selectedLongitude = item.placemark.coordinate.longitude

        mapSearchService.trackSearch(
            query: searchText.isEmpty ? nil : searchText,
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude,
            placeName: name,
            category: item.pointOfInterestCategory?.rawValue
        )

        dismiss()
    }

    private func formatSubtitle(_ item: MKMapItem) -> String? {
        let parts = [
            item.placemark.locality,
            item.placemark.administrativeArea,
            item.placemark.country
        ].compactMap { $0 }
        let subtitle = parts.joined(separator: ", ")
        return subtitle.isEmpty ? nil : subtitle
    }

    private func performSearch(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            if let loc = userLocation {
                searchNearby(location: loc)
            } else {
                results = []
            }
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            if let loc = userLocation {
                request.region = MKCoordinateRegion(
                    center: loc.coordinate,
                    latitudinalMeters: 50_000,
                    longitudinalMeters: 50_000
                )
            }

            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = response.mapItems
                }
            } catch {
                // Search cancelled or failed
            }
        }
    }

    private func searchNearby(location: CLLocation) {
        searchTask?.cancel()
        searchTask = Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "restaurants cafes parks landmarks"
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 5_000,
                longitudinalMeters: 5_000
            )

            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = response.mapItems
                }
            } catch {
                // Search failed
            }
        }
    }
}
