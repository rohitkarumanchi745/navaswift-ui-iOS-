import SwiftUI
import NavCore
import NavNetworking

struct PreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var ageMin = "24"
    @State private var ageMax = "32"
    @State private var distance = "25"
    @State private var intent = "long_term"
    @State private var languages: Set<String> = []
    @State private var genders: Set<String> = []
    @State private var onlyVerified = false
    @State private var loading = true
    @State private var saving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let intentOptions = [
        ("long_term", "Long-term"), ("short_term", "Short-term"),
        ("casual", "Casual"), ("friendship", "Friendship"),
        ("figuring_out", "Figuring it out"),
    ]

    private let languageOptions = [
        "Telugu", "Hindi", "English", "Tamil", "Kannada", "Malayalam", "Marathi", "Bengali", "Urdu", "Gujarati"
    ]

    private let genderOptions = [
        ("male", "Men"), ("female", "Women"),
        ("nonbinary", "Non-binary"), ("everyone", "Everyone"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if loading {
                    ProgressView("Loading preferences...")
                        .padding(.top, 60)
                } else {
                    preferenceSection(title: "Age Range") {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Min").font(.caption).foregroundColor(AppColors.textSecondary)
                                TextField("18", text: $ageMin)
                                    .keyboardType(.numberPad).textFieldStyle(.plain).padding(12)
                                    .background(Color(hex: "F7F7F7"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Max").font(.caption).foregroundColor(AppColors.textSecondary)
                                TextField("50", text: $ageMax)
                                    .keyboardType(.numberPad).textFieldStyle(.plain).padding(12)
                                    .background(Color(hex: "F7F7F7"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    preferenceSection(title: "What are you looking for?") {
                        FlowLayout(spacing: 10) {
                            ForEach(intentOptions, id: \.0) { option in
                                chipButton(label: option.1, isSelected: intent == option.0) { intent = option.0 }
                            }
                        }
                    }

                    preferenceSection(title: "Languages") {
                        FlowLayout(spacing: 10) {
                            ForEach(languageOptions, id: \.self) { lang in
                                chipButton(label: lang, isSelected: languages.contains(lang)) {
                                    if languages.contains(lang) { languages.remove(lang) }
                                    else { languages.insert(lang) }
                                }
                            }
                        }
                    }

                    preferenceSection(title: "Show me") {
                        FlowLayout(spacing: 10) {
                            ForEach(genderOptions, id: \.0) { option in
                                chipButton(label: option.1, isSelected: genders.contains(option.0)) {
                                    if genders.contains(option.0) { genders.remove(option.0) }
                                    else { genders.insert(option.0) }
                                }
                            }
                        }
                    }

                    preferenceSection(title: "Maximum Distance") {
                        HStack {
                            TextField("25", text: $distance)
                                .keyboardType(.numberPad).textFieldStyle(.plain).padding(12)
                                .background(Color(hex: "F7F7F7"))
                                .clipShape(RoundedRectangle(cornerRadius: 12)).frame(width: 80)
                            Text("miles").font(.subheadline).foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                    }

                    preferenceSection(title: "Verification") {
                        Toggle(isOn: $onlyVerified) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill").foregroundColor(AppColors.secondary)
                                Text("Only show verified profiles").font(.subheadline)
                            }
                        }
                        .tint(AppColors.verifyGreen)
                    }

                    Button { savePreferences() } label: {
                        HStack {
                            if saving { ProgressView().tint(.white) }
                            Text(saving ? "Saving..." : "Save Preferences").font(.headline)
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(AppColors.verifyGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(saving).padding(.top, 8)
                }
            }
            .padding(24)
        }
        .background(AppColors.peachBackground)
        .navigationTitle("Dating Preferences").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .alert("Preferences", isPresented: $showAlert) { Button("OK") {} } message: { Text(alertMessage) }
        .task { await loadPreferences() }
    }

    // MARK: - Helpers

    private func preferenceSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundColor(AppColors.textPrimary)
            content()
        }
        .padding(20).background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.subheadline)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(isSelected ? AppColors.verifyGreen : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? AppColors.verifyGreen : AppColors.border, lineWidth: 1))
        }
    }

    // MARK: - API

    private func loadPreferences() async {
        loading = true
        do {
            let query = """
            query MyPreferences {
                myPreferences {
                    minAge maxAge maxDistanceKm preferredGenders onlyVerified
                }
            }
            """
            let result: [String: Any] = try await APIService.shared.graphQL(query: query)
            if let prefs = result["myPreferences"] as? [String: Any] {
                if let min = prefs["minAge"] as? Int { ageMin = String(min) }
                if let max = prefs["maxAge"] as? Int { ageMax = String(max) }
                if let km = prefs["maxDistanceKm"] as? Int { distance = String(Int(Double(km) * 0.621)) }
                if let g = prefs["preferredGenders"] as? [String] { genders = Set(g) }
                if let v = prefs["onlyVerified"] as? Bool { onlyVerified = v }
            }
        } catch {}
        loading = false
    }

    private func savePreferences() {
        saving = true
        Task {
            do {
                let distanceMiles = Int(distance) ?? 25
                let distanceKm = Int(Double(distanceMiles) / 0.621)
                let mutation = """
                mutation SavePreferences($input: PreferencesInput!) {
                    savePreferences(input: $input)
                }
                """
                let variables: [String: Any] = [
                    "input": [
                        "minAge": Int(ageMin) ?? 18, "maxAge": Int(ageMax) ?? 50,
                        "maxDistanceKm": distanceKm, "preferredGenders": Array(genders),
                        "onlyVerified": onlyVerified,
                    ]
                ]
                let _: [String: Any] = try await APIService.shared.graphQL(query: mutation, variables: variables)
                alertMessage = "Preferences saved successfully!"
            } catch {
                alertMessage = "Failed to save. Please try again."
            }
            saving = false; showAlert = true
        }
    }
}

#Preview {
    NavigationStack { PreferencesView() }
}
