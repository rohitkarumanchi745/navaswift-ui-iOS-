import SwiftUI
import CoreLocation
import NavCore
import NavNetworking
import NavServices

struct CreateEventView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date().addingTimeInterval(3600)
    @State private var locationName = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var isCreating = false
    @State private var showLocationSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            TextField("Event name", text: $title)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(AppColors.darkCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            TextEditor(text: $description)
                                .scrollContentBackground(.hidden)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(minHeight: 80)
                                .padding(12)
                                .background(AppColors.darkCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Date & Time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date & Time")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            DatePicker(
                                "Event date",
                                selection: $eventDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppColors.purpleAccent)
                            .colorScheme(.dark)
                            .padding(14)
                            .background(AppColors.darkCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createEvent() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
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

    private func createEvent() async {
        isCreating = true
        defer { isCreating = false }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        do {
            var body: [String: Any] = [
                "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
                "event_date": isoFormatter.string(from: eventDate),
            ]
            let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !desc.isEmpty { body["description"] = desc }
            // Filter out null island (0,0)
            if let latitude, let longitude, abs(latitude) > 0.1 || abs(longitude) > 0.1 {
                body["latitude"] = latitude
                body["longitude"] = longitude
            }
            if !locationName.isEmpty { body["locality"] = locationName }

            let _: EventCreateResponse = try await APIService.shared.post(
                path: "/events",
                body: body
            )
            dismiss()
        } catch {
            NavLog.warning("Create event failed: \(error.localizedDescription)", category: .network)
        }
    }
}
