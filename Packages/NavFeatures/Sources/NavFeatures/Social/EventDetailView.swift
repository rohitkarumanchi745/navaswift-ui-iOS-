import SwiftUI
import MapKit
import NavCore
import NavNetworking

struct EventDetailView: View {
    let event: Event

    @State private var rsvpCount: Int
    @State private var isRsvped: Bool
    @State private var isLoading = false

    init(event: Event) {
        self.event = event
        _rsvpCount = State(initialValue: event.rsvpCount ?? 0)
        _isRsvped = State(initialValue: event.isRsvped)
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text(event.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    // Creator
                    HStack(spacing: 10) {
                        AsyncImage(url: URL(string: event.creatorPhoto ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(AppColors.darkCard)
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hosted by")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(event.creatorName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }

                    // Date & Location
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 18))
                                .foregroundStyle(AppColors.purpleAccent)
                                .frame(width: 28)

                            Text(formatEventDate(event.eventDate))
                                .font(.system(size: 15))
                                .foregroundStyle(.white)

                            Spacer()
                        }

                        if let locality = event.locality {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppColors.purpleAccent)
                                    .frame(width: 28)

                                Text(locality)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)

                                Spacer()
                            }
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(AppColors.purpleAccent)
                                .frame(width: 28)

                            Text("\(rsvpCount) going")
                                .font(.system(size: 15))
                                .foregroundStyle(.white)

                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(AppColors.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Description
                    if let desc = event.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            Text(desc)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Map preview
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: event.latitude,
                            longitude: event.longitude
                        ),
                        latitudinalMeters: 1000,
                        longitudinalMeters: 1000
                    ))) {
                        Marker(event.title, coordinate: CLLocationCoordinate2D(
                            latitude: event.latitude,
                            longitude: event.longitude
                        ))
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)

                    // RSVP button
                    Button {
                        Task { await toggleRsvp() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isRsvped ? "checkmark.circle.fill" : "calendar.badge.plus")
                                .font(.system(size: 18))
                            Text(isRsvped ? "Going" : "RSVP")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isRsvped ? Color.green.opacity(0.7) : AppColors.purpleAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading)
                }
                .padding(20)
            }
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func toggleRsvp() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: EventRsvpResponse = try await APIService.shared.post(
                path: "/events/\(event.id)/rsvp",
                body: [:]
            )
            isRsvped.toggle()
            if let count = response.rsvpCount {
                rsvpCount = count
            } else {
                rsvpCount += isRsvped ? 1 : -1
            }
        } catch {
            NavLog.warning("Event RSVP failed: \(error.localizedDescription)", category: .network)
        }
    }

    private func formatEventDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: dateString)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateString)
        }
        guard let date else { return dateString }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d · h:mm a"
        return formatter.string(from: date)
    }
}
