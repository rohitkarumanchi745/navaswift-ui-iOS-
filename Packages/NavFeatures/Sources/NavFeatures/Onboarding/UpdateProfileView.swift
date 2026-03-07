import SwiftUI
import PhotosUI
import NavCore
import NavNetworking
import NavServices

public struct UpdateProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var step = 0
    @State private var floatOffset: CGFloat = 0

    // Basics
    @State private var name = ""
    @State private var dob = Calendar.current.date(byAdding: .year, value: -22, to: Date()) ?? Date()
    @State private var gender = ""

    // Vibe
    @State private var lookingFor = ""
    @State private var selectedInterests: Set<String> = []
    @State private var selectedLanguages: Set<String> = []

    // About
    @State private var location = ""
    @State private var professionTitle = ""
    @State private var professionCategory = ""
    @State private var heightCm: Int = 170
    @State private var bio = ""

    // Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let totalSteps = 4

    private let genders = [
        ("male", "Man"),
        ("female", "Woman"),
        ("non_binary", "Non-binary"),
        ("other", "Other"),
    ]
    private let lookingForOptions = [
        ("long_term", "Serious"),
        ("casual", "Casual"),
        ("fun", "Fun"),
        ("friends", "Friends"),
    ]
    private let allInterests = [
        "Travel", "Music", "Foodie", "Fitness", "Photography",
        "Art", "Gaming", "Movies", "Reading", "Cooking",
        "Hiking", "Yoga", "Dancing", "Coffee", "Tech",
        "Fashion", "Sports", "Dogs", "Cats", "Volunteering",
    ]
    private let allLanguages = [
        "English", "Telugu", "Hindi", "Tamil", "Kannada",
        "Malayalam", "Marathi", "Bengali", "Gujarati", "Punjabi",
    ]
    private let professionCategories = [
        "Tech", "Healthcare", "Finance", "Education",
        "Creative", "Business", "Student", "Other",
    ]

    private let bg = Color(hex: "0F0F1A")
    private let coral = Color(hex: "FF5864")
    private let purple = Color(hex: "6A4C93")

    public init() {}

    public var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            Circle()
                .fill(coral.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 130, y: -280 + floatOffset)

            Circle()
                .fill(purple.opacity(0.1))
                .frame(width: 220, height: 220)
                .blur(radius: 80)
                .offset(x: -120, y: 250 - floatOffset)

            VStack(spacing: 0) {
                // Progress
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? .white : .white.opacity(0.12))
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: step)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 32)

                // Step content
                Group {
                    switch step {
                    case 0: basicsStep
                    case 1: vibeStep
                    case 2: aboutStep
                    case 3: photosStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)

                // Bottom button
                VStack(spacing: 14) {
                    Button {
                        advance()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(bg)
                            } else {
                                Text(step == totalSteps - 1 ? "Complete Profile" : "Continue")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundStyle(bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canAdvance ? .white : .white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!canAdvance || isSaving)

                    if step == totalSteps - 1 {
                        Button {
                            saveProfile()
                        } label: {
                            Text("Skip photos for now")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if let user = auth.user {
                name = user.name ?? ""
                bio = user.bio ?? ""
                gender = user.gender ?? ""
                professionTitle = user.professionTitle ?? ""
                professionCategory = user.professionCategory ?? ""
                location = user.location ?? ""
                lookingFor = user.lookingFor ?? ""
                if let h = user.heightCm { heightCm = h }
                if let i = user.interests { selectedInterests = Set(i) }
                if let l = user.languages { selectedLanguages = Set(l) }
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = 20
            }
        }
    }

    // MARK: - Step 1: The Basics

    private var basicsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("The basics")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Let's start with who you are")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("YOUR NAME")
                    TextField("", text: $name, prompt: Text("First name").foregroundStyle(.white.opacity(0.2)))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("BIRTHDAY")
                    DatePicker("", selection: $dob,
                               in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!,
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(.white)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("I IDENTIFY AS")
                    HStack(spacing: 8) {
                        ForEach(genders, id: \.0) { (value, label) in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { gender = value }
                            } label: {
                                Text(label)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(gender == value ? bg : .white.opacity(0.7))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(gender == value ? .white : .white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.white.opacity(gender == value ? 0 : 0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Step 2: Your Vibe

    private var vibeStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Your vibe")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("What are you looking for?")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("LOOKING FOR")
                    HStack(spacing: 8) {
                        ForEach(lookingForOptions, id: \.0) { (value, label) in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { lookingFor = value }
                            } label: {
                                Text(label)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(lookingFor == value ? bg : .white.opacity(0.7))
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(lookingFor == value ? .white : .white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.white.opacity(lookingFor == value ? 0 : 0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionLabel("INTERESTS")
                        Spacer()
                        Text("\(selectedInterests.count) selected")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(allInterests, id: \.self) { interest in
                            let on = selectedInterests.contains(interest)
                            Button {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    if on { selectedInterests.remove(interest) }
                                    else { selectedInterests.insert(interest) }
                                }
                            } label: {
                                Text(interest)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(on ? bg : .white.opacity(0.65))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(on ? .white : .white.opacity(0.06))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(.white.opacity(on ? 0 : 0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("LANGUAGES")

                    FlowLayout(spacing: 8) {
                        ForEach(allLanguages, id: \.self) { lang in
                            let on = selectedLanguages.contains(lang)
                            Button {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    if on { selectedLanguages.remove(lang) }
                                    else { selectedLanguages.insert(lang) }
                                }
                            } label: {
                                Text(lang)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(on ? bg : .white.opacity(0.65))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(on ? .white : .white.opacity(0.06))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(.white.opacity(on ? 0 : 0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Step 3: About You

    private var aboutStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("About you")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("A few more details")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("LOCATION")
                    TextField("", text: $location, prompt: Text("e.g. Hyderabad, India").foregroundStyle(.white.opacity(0.2)))
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("PROFESSION")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(professionCategories, id: \.self) { cat in
                                let on = professionCategory == cat
                                Button {
                                    withAnimation(.easeInOut(duration: 0.12)) { professionCategory = cat }
                                } label: {
                                    Text(cat)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(on ? bg : .white.opacity(0.6))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(on ? .white : .white.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    TextField("", text: $professionTitle, prompt: Text("Job title").foregroundStyle(.white.opacity(0.2)))
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionLabel("HEIGHT")
                        Spacer()
                        let feet = heightCm * 100 / 3048
                        let inches = (heightCm * 100 % 3048) * 12 / 3048
                        Text("\(heightCm) cm · \(feet)'\(inches)\"")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Slider(value: Binding(
                        get: { Double(heightCm) },
                        set: { heightCm = Int($0) }
                    ), in: 140...220, step: 1)
                    .tint(.white)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionLabel("BIO")
                        Spacer()
                        Text("\(bio.count)/300")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                    }

                    ZStack(alignment: .topLeading) {
                        if bio.isEmpty {
                            Text("Write something about yourself...")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundStyle(.white.opacity(0.2))
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                        }
                        TextEditor(text: $bio)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .frame(height: 100)
                            .padding(12)
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Step 4: Photos

    private var photosStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Show yourself")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Add up to 3 photos")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { index in
                    if index < photoImages.count {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photoImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 18))

                            Button {
                                photoImages.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white, .black.opacity(0.5))
                                    .offset(x: 6, y: -6)
                            }
                        }
                    } else if index == photoImages.count {
                        PhotosPicker(selection: $selectedPhotos,
                                     maxSelectionCount: 3 - photoImages.count,
                                     matching: .images) {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.white.opacity(0.06))
                                .frame(width: 100, height: 150)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .strokeBorder(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                )
                                .overlay(
                                    VStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 24, weight: .light))
                                        Text("Add")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                    .foregroundStyle(.white.opacity(0.35))
                                )
                        }
                        .onChange(of: selectedPhotos) { items in
                            Task {
                                for item in items {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        photoImages.append(image)
                                    }
                                }
                                selectedPhotos = []
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.white.opacity(0.03))
                            .frame(width: 100, height: 150)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                            )
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.35))
            .tracking(1.2)
    }

    private var canAdvance: Bool {
        switch step {
        case 0:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && !gender.isEmpty
        case 1:
            return !lookingFor.isEmpty && selectedInterests.count >= 3 && !selectedLanguages.isEmpty
        case 2:
            return !location.trimmingCharacters(in: .whitespaces).isEmpty
        case 3:
            return true
        default:
            return false
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.35)) { step += 1 }
        } else {
            saveProfile()
        }
    }

    private func saveProfile() {
        isSaving = true
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dobString = dateFormatter.string(from: dob)

                let query = """
                mutation UpdateProfile(
                    $name: String!,
                    $dob: String!,
                    $gender: String!,
                    $bio: String!,
                    $location: String!,
                    $lookingFor: String!,
                    $interests: [String!]!,
                    $languages: [String!]!,
                    $heightCm: Int,
                    $professionCategory: String,
                    $professionTitle: String
                ) {
                    updateProfile(
                        name: $name,
                        dob: $dob,
                        gender: $gender,
                        bio: $bio,
                        location: $location,
                        lookingFor: $lookingFor,
                        interests: $interests,
                        languages: $languages,
                        heightCm: $heightCm,
                        professionCategory: $professionCategory,
                        professionTitle: $professionTitle
                    )
                }
                """
                let _: [String: Any] = try await APIService.shared.graphQL(
                    query: query,
                    variables: [
                        "name": name,
                        "dob": dobString,
                        "gender": gender,
                        "bio": bio,
                        "location": location,
                        "lookingFor": lookingFor,
                        "interests": Array(selectedInterests),
                        "languages": Array(selectedLanguages),
                        "heightCm": heightCm,
                        "professionCategory": professionCategory,
                        "professionTitle": professionTitle,
                    ]
                )
                await auth.refreshProfile()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    NavigationStack {
        UpdateProfileView()
            .environmentObject(AuthManager())
    }
}
