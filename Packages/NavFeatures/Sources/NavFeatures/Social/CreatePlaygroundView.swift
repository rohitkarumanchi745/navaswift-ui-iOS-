import SwiftUI
import CoreLocation
import NavCore
import NavNetworking
import NavServices

struct CreatePlaygroundView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedType: PlaygroundType = .hangout
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
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            TextField("Give it a name", text: $name)
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

                        // Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(PlaygroundType.allCases) { type in
                                        Button {
                                            selectedType = type
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: type.icon)
                                                    .font(.system(size: 13))
                                                Text(type.displayName)
                                                    .font(.system(size: 14, weight: .medium))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedType == type ? AppColors.purpleAccent : AppColors.darkCard)
                                            .foregroundStyle(selectedType == type ? .white : .white.opacity(0.7))
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }

                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location (optional)")
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
            .navigationTitle("New Playground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createPlayground() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
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
        }
    }

    private func createPlayground() async {
        isCreating = true
        defer { isCreating = false }

        do {
            var body: [String: Any] = [
                "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                "type": selectedType.rawValue,
            ]
            let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !desc.isEmpty { body["description"] = desc }
            if let latitude { body["latitude"] = latitude }
            if let longitude { body["longitude"] = longitude }
            if !locationName.isEmpty { body["locality"] = locationName }

            let _: PlaygroundActionResponse = try await APIService.shared.post(
                path: "/playgrounds",
                body: body
            )
            dismiss()
        } catch {
            NavLog.warning("Create playground failed: \(error.localizedDescription)", category: .network)
        }
    }
}
