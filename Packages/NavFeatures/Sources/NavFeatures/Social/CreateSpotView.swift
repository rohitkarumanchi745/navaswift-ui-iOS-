import SwiftUI
import CoreLocation
import NavCore
import NavNetworking
import NavServices

struct CreateSpotView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var content = ""
    @State private var locationName = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var isPosting = false
    @State private var showLocationSheet = false

    private let charLimit = 280

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What's happening?")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            TextEditor(text: $content)
                                .scrollContentBackground(.hidden)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(AppColors.darkCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            HStack {
                                Spacer()
                                Text("\(content.count)/\(charLimit)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(content.count > charLimit ? .red : .white.opacity(0.4))
                            }
                        }

                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            Button {
                                showLocationSheet = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AppColors.purpleAccent)

                                    Text(locationName.isEmpty ? "Add location" : locationName)
                                        .font(.system(size: 15))
                                        .foregroundStyle(locationName.isEmpty ? .white.opacity(0.4) : .white)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding(14)
                                .background(AppColors.darkCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task { await postSpot() }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.count > charLimit || isPosting)
                    .font(.system(size: 16, weight: .semibold))
                }
            }
            .sheet(isPresented: $showLocationSheet) {
                SocialLocationSearchSheet(
                    selectedLocation: $locationName,
                    selectedLatitude: $latitude,
                    selectedLongitude: $longitude,
                    userLocation: locationManager.location
                )
            }
            .onAppear {
                // Auto-populate location from device
                if locationName.isEmpty, let loc = locationManager.location {
                    latitude = loc.coordinate.latitude
                    longitude = loc.coordinate.longitude
                    let city = locationManager.city
                    let country = locationManager.country
                    if !city.isEmpty {
                        locationName = country.isEmpty ? city : "\(city), \(country)"
                    }
                }
            }
        }
    }

    private func postSpot() async {
        isPosting = true
        defer { isPosting = false }

        do {
            var body: [String: Any] = [
                "content": content.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
            // Filter out null island (0,0)
            if let latitude, let longitude, abs(latitude) > 0.1 || abs(longitude) > 0.1 {
                body["latitude"] = latitude
                body["longitude"] = longitude
            }
            if !locationName.isEmpty { body["locality"] = locationName }

            let _: SpotCreateResponse = try await APIService.shared.post(
                path: "/spots",
                body: body
            )
            dismiss()
        } catch {
            NavLog.warning("Create spot failed: \(error.localizedDescription)", category: .network)
        }
    }
}
