import SwiftUI
import PhotosUI
import NavCore
import NavNetworking
import NavServices

struct EditProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var bio = ""
    @State private var gender = ""
    @State private var lookingFor = ""
    @State private var professionCategory = ""
    @State private var professionTitle = ""
    @State private var height = ""
    @State private var location = ""
    @State private var interests: Set<String> = []
    @State private var languages: Set<String> = []
    @State private var university = ""
    @State private var universityLocation = ""
    @State private var study = ""
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []

    private let genderOptions = ["Male", "Female", "Non-binary"]

    private let lookingForOptions = [
        ("long_term", "Long-term", "heart.fill"),
        ("short_term", "Short-term", "clock.fill"),
        ("casual", "Casual", "figure.walk"),
        ("friendship", "Friendship", "person.2.fill"),
        ("figuring_out", "Figuring it out", "questionmark.circle.fill"),
    ]

    private let interestOptions = [
        "Travel", "Music", "Cooking", "Fitness", "Reading", "Movies",
        "Photography", "Art", "Dance", "Yoga", "Gaming", "Hiking",
        "Coffee", "Foodie", "Dogs", "Cats", "Tech", "Fashion",
        "Meditation", "Sports"
    ]

    private let languageOptions = [
        "Telugu", "Hindi", "English", "Tamil", "Kannada", "Malayalam",
        "Marathi", "Bengali", "Urdu", "Gujarati"
    ]

    private let professionCategories = [
        ("tech", "Technology"), ("healthcare", "Healthcare"),
        ("education", "Education"), ("business", "Business"),
        ("creative", "Creative"), ("legal", "Legal"),
        ("finance", "Finance"), ("engineering", "Engineering"),
        ("student", "Student"), ("other", "Other"),
    ]

    private let heightOptions: [(String, String)] = {
        var options: [(String, String)] = []
        for feet in 4...7 {
            for inches in 0...11 {
                let cm = Int(Double(feet * 12 + inches) * 2.54)
                options.append(("\(cm)", "\(feet)'\(inches)\" (\(cm) cm)"))
            }
        }
        return options
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                photoSection

                formSection(title: "Basic Info") {
                    VStack(alignment: .leading, spacing: 16) {
                        formField(title: "Name") {
                            TextField("Your name", text: $name)
                                .foregroundStyle(.white)
                                .textFieldStyle(.plain).padding(16)
                                .background(AppColors.darkInput)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        formField(title: "Gender") {
                            HStack(spacing: 10) {
                                ForEach(genderOptions, id: \.self) { option in
                                    Button { gender = option.lowercased() } label: {
                                        Text(option).font(.subheadline.bold())
                                            .foregroundColor(gender == option.lowercased() ? .white : .white.opacity(0.6))
                                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                                            .background(gender == option.lowercased() ? AppColors.purpleAccent : AppColors.darkInput)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                            }
                        }

                        formField(title: "Location") {
                            TextField("City, State", text: $location)
                                .foregroundStyle(.white)
                                .textFieldStyle(.plain).padding(16)
                                .background(AppColors.darkInput)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        formField(title: "Height") {
                            Picker("Height", selection: $height) {
                                Text("Select").tag("")
                                ForEach(heightOptions, id: \.0) { option in
                                    Text(option.1).tag(option.0)
                                }
                            }
                            .pickerStyle(.menu).padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.darkInput)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .tint(AppColors.purpleAccent)
                        }
                    }
                }

                formSection(title: "About You") {
                    VStack(alignment: .leading, spacing: 16) {
                        formField(title: "Bio") {
                            TextField("Tell others about yourself...", text: $bio, axis: .vertical)
                                .foregroundStyle(.white)
                                .textFieldStyle(.plain).lineLimit(4...8).padding(16)
                                .background(AppColors.darkInput)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        formField(title: "Interests (max 5)") {
                            FlowLayout(spacing: 8) {
                                ForEach(interestOptions, id: \.self) { interest in
                                    chipToggle(label: interest, isSelected: interests.contains(interest)) {
                                        if interests.contains(interest) { interests.remove(interest) }
                                        else if interests.count < 5 { interests.insert(interest) }
                                    }
                                }
                            }
                        }

                        formField(title: "Languages") {
                            FlowLayout(spacing: 8) {
                                ForEach(languageOptions, id: \.self) { lang in
                                    chipToggle(label: lang, isSelected: languages.contains(lang)) {
                                        if languages.contains(lang) { languages.remove(lang) }
                                        else { languages.insert(lang) }
                                    }
                                }
                            }
                        }
                    }
                }

                formSection(title: "Education") {
                    UniversityPickerView(
                        selectedUniversity: $university,
                        selectedLocation: $universityLocation,
                        selectedStudy: $study
                    )
                }

                formSection(title: "Preferences") {
                    VStack(alignment: .leading, spacing: 16) {
                        formField(title: "Looking for") {
                            VStack(spacing: 10) {
                                ForEach(lookingForOptions, id: \.0) { option in
                                    Button { lookingFor = option.0 } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: option.2).font(.title3)
                                                .foregroundColor(lookingFor == option.0 ? AppColors.purpleAccent : AppColors.darkTextMuted)
                                                .frame(width: 48, height: 48)
                                                .background(lookingFor == option.0 ? AppColors.purpleAccent.opacity(0.15) : AppColors.darkInput)
                                                .clipShape(Circle())
                                            Text(option.1).font(.subheadline).foregroundColor(AppColors.darkTextPrimary)
                                            Spacer()
                                            if lookingFor == option.0 {
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.purpleAccent)
                                            }
                                        }
                                        .padding(12)
                                        .background(lookingFor == option.0 ? AppColors.purpleAccent.opacity(0.08) : AppColors.darkInput)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(lookingFor == option.0 ? AppColors.purpleAccent : .clear, lineWidth: 1.5)
                                        )
                                    }
                                }
                            }
                        }

                        formField(title: "Work") {
                            VStack(spacing: 8) {
                                Picker("Category", selection: $professionCategory) {
                                    Text("Select category").tag("")
                                    ForEach(professionCategories, id: \.0) { cat in
                                        Text(cat.1).tag(cat.0)
                                    }
                                }
                                .pickerStyle(.menu).padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.darkInput)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .tint(AppColors.purpleAccent)

                                TextField("Job title", text: $professionTitle)
                                    .foregroundStyle(.white)
                                    .textFieldStyle(.plain).padding(16)
                                    .background(AppColors.darkInput)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                Button { saveProfile() } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Saving..." : "Save Changes").font(.headline)
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(LinearGradient(colors: [AppColors.purpleAccent, AppColors.secondary], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppColors.purpleAccent.opacity(0.3), radius: 8, y: 4)
                }
                .disabled(isSaving).padding(.bottom, 32)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.darkBg)
        .navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .alert("Profile", isPresented: $showAlert) {
            Button("OK") { if alertMessage.contains("success") { dismiss() } }
        } message: { Text(alertMessage) }
        .onAppear { loadUserData() }
    }

    // MARK: - Photos Section
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos").font(.headline).foregroundStyle(.white)
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images) {
                    RoundedRectangle(cornerRadius: 20).fill(AppColors.darkInput).frame(height: 200)
                        .overlay {
                            if let firstPhoto = auth.user?.photos?.first, !firstPhoto.isEmpty {
                                AsyncImage(url: AppConfig.resolvePhotoURL(firstPhoto)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { addPhotoPlaceholder }
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else { addPhotoPlaceholder }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                VStack(spacing: 12) {
                    ForEach(1..<3) { index in
                        RoundedRectangle(cornerRadius: 16).fill(AppColors.darkInput).frame(height: 94)
                            .overlay {
                                let photos = auth.user?.photos ?? []
                                if index < photos.count, !photos[index].isEmpty {
                                    AsyncImage(url: AppConfig.resolvePhotoURL(photos[index])) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: { smallAddPlaceholder }
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                } else { smallAddPlaceholder }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .frame(width: 100)
            }
        }
        .padding(16).background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var addPhotoPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill").font(.title).foregroundColor(AppColors.purpleAccent)
            Text("Add Photo").font(.caption).foregroundColor(AppColors.darkTextSecondary)
        }
    }

    private var smallAddPlaceholder: some View {
        Image(systemName: "plus").font(.title3).foregroundColor(AppColors.darkTextMuted)
    }

    // MARK: - Helpers

    private func formSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title3.bold()).foregroundColor(AppColors.darkTextPrimary)
            content()
        }
        .padding(20).background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func formField(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundColor(AppColors.darkTextSecondary)
            content()
        }
    }

    private func chipToggle(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.subheadline)
                .foregroundColor(isSelected ? AppColors.purpleAccent : AppColors.darkTextSecondary)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(isSelected ? AppColors.purpleAccent.opacity(0.15) : AppColors.darkInput)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? AppColors.purpleAccent : AppColors.darkDivider, lineWidth: 1.5))
        }
    }

    // MARK: - Data

    private func loadUserData() {
        guard let user = auth.user else { return }
        name = user.name ?? ""; bio = user.bio ?? ""; gender = user.gender ?? ""
        lookingFor = user.lookingFor ?? ""; professionCategory = user.professionCategory ?? ""
        professionTitle = user.professionTitle ?? ""; height = user.heightCm.map { String($0) } ?? ""
        location = user.location ?? ""; interests = Set(user.interests ?? [])
        languages = Set(user.languages ?? [])
        university = user.university ?? ""
        universityLocation = user.universityLocation ?? ""
        study = user.study ?? ""
    }

    private func saveProfile() {
        isSaving = true
        Task {
            do {
                let mutation = """
                mutation UpdateProfile(
                    $name: String!, $bio: String!, $gender: String!, $location: String!,
                    $looking_for: String!, $interests: [String!]!, $languages: [String!]!,
                    $height_cm: Int, $profession_category: String, $profession_title: String,
                    $university: String, $university_location: String, $study: String
                ) {
                    update_profile(
                        name: $name, bio: $bio, gender: $gender, location: $location,
                        looking_for: $looking_for, interests: $interests, languages: $languages,
                        height_cm: $height_cm, profession_category: $profession_category,
                        profession_title: $profession_title, university: $university,
                        university_location: $university_location, study: $study
                    )
                }
                """
                let variables: [String: Any] = [
                    "name": name, "bio": bio, "gender": gender, "location": location,
                    "looking_for": lookingFor, "interests": Array(interests),
                    "languages": Array(languages), "height_cm": Int(height) as Any,
                    "profession_category": professionCategory, "profession_title": professionTitle,
                    "university": university, "university_location": universityLocation, "study": study,
                ]
                let _: [String: Any] = try await APIService.shared.graphQL(query: mutation, variables: variables)
                await auth.refreshProfile()
                alertMessage = "Profile updated successfully!"
            } catch {
                alertMessage = "Failed to save. Please try again."
            }
            isSaving = false; showAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthManager())
    }
}
