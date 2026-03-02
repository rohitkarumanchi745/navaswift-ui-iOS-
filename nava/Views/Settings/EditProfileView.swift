import SwiftUI
import PhotosUI

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
        ("tech", "Technology"),
        ("healthcare", "Healthcare"),
        ("education", "Education"),
        ("business", "Business"),
        ("creative", "Creative"),
        ("legal", "Legal"),
        ("finance", "Finance"),
        ("engineering", "Engineering"),
        ("student", "Student"),
        ("other", "Other"),
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
                // Photos Section
                photoSection
                
                // Basic Info
                formSection(title: "Basic Info") {
                    VStack(alignment: .leading, spacing: 16) {
                        formField(title: "Name") {
                            TextField("Your name", text: $name)
                                .textFieldStyle(.plain)
                                .padding(16)
                                .background(Color(hex: "F8FAFC"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        formField(title: "Gender") {
                            HStack(spacing: 10) {
                                ForEach(genderOptions, id: \.self) { option in
                                    Button {
                                        gender = option.lowercased()
                                    } label: {
                                        Text(option)
                                            .font(.subheadline.bold())
                                            .foregroundColor(gender == option.lowercased() ? .white : Color(hex: "64748B"))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(gender == option.lowercased() ? Color(hex: "667EEA") : Color(hex: "F8FAFC"))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                            }
                        }
                        
                        formField(title: "Location") {
                            TextField("City, State", text: $location)
                                .textFieldStyle(.plain)
                                .padding(16)
                                .background(Color(hex: "F8FAFC"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        formField(title: "Height") {
                            Picker("Height", selection: $height) {
                                Text("Select").tag("")
                                ForEach(heightOptions, id: \.0) { option in
                                    Text(option.1).tag(option.0)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "F8FAFC"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                
                // About
                formSection(title: "About You") {
                    VStack(alignment: .leading, spacing: 16) {
                        formField(title: "Bio") {
                            TextField("Tell others about yourself...", text: $bio, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(4...8)
                                .padding(16)
                                .background(Color(hex: "F8FAFC"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        formField(title: "Interests (max 5)") {
                            FlowLayout(spacing: 8) {
                                ForEach(interestOptions, id: \.self) { interest in
                                    chipToggle(label: interest, isSelected: interests.contains(interest)) {
                                        if interests.contains(interest) {
                                            interests.remove(interest)
                                        } else if interests.count < 5 {
                                            interests.insert(interest)
                                        }
                                    }
                                }
                            }
                        }
                        
                        formField(title: "Languages") {
                            FlowLayout(spacing: 8) {
                                ForEach(languageOptions, id: \.self) { lang in
                                    chipToggle(label: lang, isSelected: languages.contains(lang)) {
                                        if languages.contains(lang) {
                                            languages.remove(lang)
                                        } else {
                                            languages.insert(lang)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Preferences
                formSection(title: "Preferences") {
                    VStack(alignment: .leading, spacing: 16) {
                        formField(title: "Looking for") {
                            VStack(spacing: 10) {
                                ForEach(lookingForOptions, id: \.0) { option in
                                    Button {
                                        lookingFor = option.0
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: option.2)
                                                .font(.title3)
                                                .foregroundColor(lookingFor == option.0 ? Color(hex: "667EEA") : Color(hex: "94A3B8"))
                                                .frame(width: 48, height: 48)
                                                .background(lookingFor == option.0 ? Color(hex: "667EEA").opacity(0.1) : Color(hex: "F8FAFC"))
                                                .clipShape(Circle())
                                            
                                            Text(option.1)
                                                .font(.subheadline)
                                                .foregroundColor(Color(hex: "1A1A2E"))
                                            
                                            Spacer()
                                            
                                            if lookingFor == option.0 {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color(hex: "667EEA"))
                                            }
                                        }
                                        .padding(12)
                                        .background(lookingFor == option.0 ? Color(hex: "667EEA").opacity(0.08) : Color(hex: "F8FAFC"))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(lookingFor == option.0 ? Color(hex: "667EEA") : .clear, lineWidth: 1.5)
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
                                .pickerStyle(.menu)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "F8FAFC"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                
                                TextField("Job title", text: $professionTitle)
                                    .textFieldStyle(.plain)
                                    .padding(16)
                                    .background(Color(hex: "F8FAFC"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
                
                // Save Button
                Button {
                    saveProfile()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "667EEA").opacity(0.3), radius: 8, y: 4)
                }
                .disabled(isSaving)
                .padding(.bottom, 32)
            }
            .padding(16)
        }
        .background(Color.white)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Profile", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("success") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadUserData()
        }
    }
    
    // MARK: - Photos Section
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
            
            HStack(spacing: 12) {
                // Main photo
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "F8FAFC"))
                        .frame(height: 200)
                        .overlay {
                            if let firstPhoto = auth.user?.photos?.first, !firstPhoto.isEmpty {
                                AsyncImage(url: URL(string: firstPhoto)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    addPhotoPlaceholder
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                addPhotoPlaceholder
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                // Side photos
                VStack(spacing: 12) {
                    ForEach(1..<3) { index in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "F8FAFC"))
                            .frame(height: 94)
                            .overlay {
                                let photos = auth.user?.photos ?? []
                                if index < photos.count, !photos[index].isEmpty {
                                    AsyncImage(url: URL(string: photos[index])) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        smallAddPlaceholder
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                } else {
                                    smallAddPlaceholder
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .frame(width: 100)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    private var addPhotoPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.title)
                .foregroundColor(Color(hex: "667EEA"))
            Text("Add Photo")
                .font(.caption)
                .foregroundColor(Color(hex: "64748B"))
        }
    }
    
    private var smallAddPlaceholder: some View {
        Image(systemName: "plus")
            .font(.title3)
            .foregroundColor(Color(hex: "94A3B8"))
    }
    
    // MARK: - Helpers
    
    private func formSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(Color(hex: "1A1A2E"))
            
            content()
        }
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
    
    private func formField(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(Color(hex: "64748B"))
            
            content()
        }
    }
    
    private func chipToggle(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(isSelected ? Color(hex: "667EEA") : Color(hex: "64748B"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color(hex: "667EEA").opacity(0.1) : Color(hex: "F8FAFC"))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color(hex: "667EEA") : Color(hex: "E2E8F0"), lineWidth: 1.5)
                )
        }
    }
    
    // MARK: - Data
    
    private func loadUserData() {
        guard let user = auth.user else { return }
        name = user.name ?? ""
        bio = user.bio ?? ""
        gender = user.gender ?? ""
        lookingFor = user.lookingFor ?? ""
        professionCategory = user.professionCategory ?? ""
        professionTitle = user.professionTitle ?? ""
        height = user.heightCm.map { String($0) } ?? ""
        location = user.location ?? ""
        interests = Set(user.interests ?? [])
        languages = Set(user.languages ?? [])
    }
    
    private func saveProfile() {
        isSaving = true
        Task {
            do {
                let mutation = """
                mutation UpdateProfile(
                    $name: String!, $bio: String!, $gender: String!, $location: String!,
                    $looking_for: String!, $interests: [String!]!, $languages: [String!]!,
                    $height_cm: Int, $profession_category: String, $profession_title: String
                ) {
                    updateProfile(
                        name: $name, bio: $bio, gender: $gender, location: $location,
                        looking_for: $looking_for, interests: $interests, languages: $languages,
                        height_cm: $height_cm, profession_category: $profession_category,
                        profession_title: $profession_title
                    )
                }
                """
                
                let variables: [String: Any] = [
                    "name": name,
                    "bio": bio,
                    "gender": gender,
                    "location": location,
                    "looking_for": lookingFor,
                    "interests": Array(interests),
                    "languages": Array(languages),
                    "height_cm": Int(height) as Any,
                    "profession_category": professionCategory,
                    "profession_title": professionTitle,
                ]
                
                let _: [String: Any] = try await APIService.shared.graphQL(query: mutation, variables: variables)
                await auth.refreshProfile()
                alertMessage = "Profile updated successfully!"
            } catch {
                alertMessage = "Failed to save. Please try again."
            }
            isSaving = false
            showAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthManager())
    }
}
