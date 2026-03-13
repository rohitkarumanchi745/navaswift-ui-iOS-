import SwiftUI
import NavCore

struct StudentFilterSheet: View {
    @Binding var filters: StudentFilters
    @Environment(\.dismiss) private var dismiss
    var onApply: () -> Void

    @State private var university: String = ""
    @State private var city: String = ""
    @State private var country: String = ""
    @State private var gender: String = ""
    @State private var minAge: Double = 18
    @State private var maxAge: Double = 30
    @State private var tier: String = ""
    @State private var classYear: String = ""
    @State private var alumniOnly: Bool = false

    private let countryOptions = ["", "IND", "USA", "GBR", "AUS"]
    private let countryLabels = ["All", "India", "USA", "UK", "Australia"]
    private let genderOptions = ["", "male", "female"]
    private let genderLabels = ["All", "Male", "Female"]
    private let tierOptions = ["", "top_private", "top_public"]
    private let tierLabels = ["All", "Top Private", "Top Public"]
    private let classYearOptions = ["", "2024", "2025", "2026", "2027", "2028"]
    private let classYearLabels = ["All", "2024", "2025", "2026", "2027", "2028"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // University
                    filterSection("University") {
                        TextField("Type university name...", text: $university)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(hex: "2D3047"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }

                    // City
                    filterSection("City") {
                        TextField("Type city name...", text: $city)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(hex: "2D3047"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }

                    // Country
                    filterSection("Country") {
                        chipRow(options: countryOptions, labels: countryLabels, selected: $country)
                    }

                    // Gender
                    filterSection("Gender") {
                        chipRow(options: genderOptions, labels: genderLabels, selected: $gender)
                    }

                    // Age Range
                    filterSection("Age Range") {
                        VStack(spacing: 8) {
                            HStack {
                                Text("\(Int(minAge))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(hex: "C9A0DC"))
                                Spacer()
                                Text("\(Int(maxAge))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(hex: "C9A0DC"))
                            }
                            HStack(spacing: 12) {
                                Slider(value: $minAge, in: 18...40, step: 1)
                                    .tint(Color(hex: "C9A0DC"))
                                Slider(value: $maxAge, in: 18...40, step: 1)
                                    .tint(Color(hex: "C9A0DC"))
                            }
                        }
                    }

                    // University Tier
                    filterSection("University Tier") {
                        chipRow(options: tierOptions, labels: tierLabels, selected: $tier)
                    }

                    // Class Year
                    filterSection("Class Year") {
                        chipRow(options: classYearOptions, labels: classYearLabels, selected: $classYear)
                    }

                    // Alumni Only
                    filterSection("Alumni") {
                        Toggle(isOn: $alumniOnly) {
                            HStack(spacing: 8) {
                                Image(systemName: "graduationcap.fill")
                                    .foregroundColor(Color(hex: "7ED4A6"))
                                Text("Show alumni only")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                        .tint(Color(hex: "6C5CE7"))
                    }

                    // Apply button
                    Button {
                        filters.university = university
                        filters.city = city
                        filters.country = country
                        filters.gender = gender
                        filters.minAge = Int(minAge)
                        filters.maxAge = Int(maxAge)
                        filters.tier = tier
                        filters.classYear = classYear
                        filters.alumniOnly = alumniOnly
                        onApply()
                        dismiss()
                    } label: {
                        Text("Apply Filters")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "6C5CE7"), Color(hex: "845EC2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Clear button
                    Button {
                        university = ""
                        city = ""
                        country = ""
                        gender = ""
                        minAge = 18
                        maxAge = 30
                        tier = ""
                        classYear = ""
                        alumniOnly = false
                    } label: {
                        Text("Clear All")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(Color(hex: "1A1B2E").ignoresSafeArea())
            .navigationTitle("Filter Students")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            university = filters.university
            city = filters.city
            country = filters.country
            gender = filters.gender
            minAge = Double(filters.minAge)
            maxAge = Double(filters.maxAge)
            tier = filters.tier
            classYear = filters.classYear
            alumniOnly = filters.alumniOnly
        }
    }

    // MARK: - Helpers

    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            content()
        }
    }

    private func chipRow(options: [String], labels: [String], selected: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(zip(options, labels)), id: \.0) { value, label in
                    let isSelected = selected.wrappedValue == value
                    Button {
                        selected.wrappedValue = value
                    } label: {
                        Text(label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color(hex: "6C5CE7") : Color(hex: "2D3047"))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? .clear : .white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
}
