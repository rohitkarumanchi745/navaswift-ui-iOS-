import SwiftUI
import NavCore
import NavServices

struct AddSpotView: View {
    @EnvironmentObject var outdoorService: OutdoorService
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var category: SpotCategory = .viewpoint
    @State private var bestTimeOfDay = "any"
    @State private var selectedMonths: Set<Int> = []
    @State private var isSubmitting = false
    @State private var didCreate = false

    private let timeOptions = [
        ("any", "Any Time"),
        ("sunrise", "Sunrise"),
        ("morning", "Morning"),
        ("afternoon", "Afternoon"),
        ("golden_hour", "Golden Hour"),
        ("sunset", "Sunset"),
        ("evening", "Evening"),
        ("night", "Night"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                if didCreate {
                    createdConfirmation
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            nameField
                            descriptionField
                            categoryPicker
                            bestTimePicker
                            monthSelector
                            locationInfo
                            submitButton
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Add Outdoor Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Form Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spot Name")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            TextField("e.g., Durgam Cheruvu Sunset Point", text: $name)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            TextField("Describe the spot...", text: $description, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .lineLimit(3...6)
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SpotCategory.allCases) { cat in
                        Button {
                            category = cat
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 12))
                                Text(cat.displayName)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(category == cat ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(category == cat ? Color(hex: "4ECDC4").opacity(0.3) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(category == cat ? Color(hex: "4ECDC4").opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private var bestTimePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Best Time to Visit")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(timeOptions, id: \.0) { value, label in
                        Button {
                            bestTimeOfDay = value
                        } label: {
                            Text(label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(bestTimeOfDay == value ? .white : .white.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(bestTimeOfDay == value ? Color(hex: "F7DC6F").opacity(0.25) : Color.white.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(bestTimeOfDay == value ? Color(hex: "F7DC6F").opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    private var monthSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Best Months")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    let isSelected = selectedMonths.contains(month)
                    Button {
                        if isSelected {
                            selectedMonths.remove(month)
                        } else {
                            selectedMonths.insert(month)
                        }
                    } label: {
                        Text(monthName(month))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color(hex: "96CEB4").opacity(0.3) : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isSelected ? Color(hex: "96CEB4").opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var locationInfo: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .foregroundStyle(Color(hex: "4ECDC4"))
            Text("Location: \(locationManager.city)")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            if let loc = locationManager.location {
                Text("\(String(format: "%.3f", loc.coordinate.latitude)), \(String(format: "%.3f", loc.coordinate.longitude))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 6) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Spot")
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(name.isEmpty ? Color.white.opacity(0.1) : Color(hex: "4ECDC4"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(name.isEmpty || isSubmitting)
    }

    // MARK: - Created Confirmation

    private var createdConfirmation: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "4ECDC4"))

            Text("Spot Added!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("\(name) has been added to the outdoor map")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color(hex: "4ECDC4"))
                .clipShape(Capsule())
                .padding(.top, 10)
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard let location = locationManager.location else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let result = await outdoorService.createSpot(
            name: name,
            description: description,
            category: category,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            bestMonths: Array(selectedMonths).sorted(),
            bestTimeOfDay: bestTimeOfDay == "any" ? nil : bestTimeOfDay
        )

        if result != nil {
            withAnimation { didCreate = true }
        }
    }

    // MARK: - Helpers

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var components = DateComponents()
        components.month = month
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date)
    }
}
