import SwiftUI
import PhotosUI
import NavCore
import NavNetworking
import NavServices

public struct UpdateProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var locationManager: LocationManager
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

    // Education
    @State private var university = ""
    @State private var universityLocation = ""
    @State private var study = ""

    // Student Verification (inline in onboarding)
    @State private var studentEmail = ""
    @State private var studentOtp: [String] = Array(repeating: "", count: 6)
    @State private var studentVerifyStep: StudentVerifyStep = .idle
    @State private var isSendingCode = false
    @State private var isVerifyingCode = false
    @State private var studentVerifyMessage = ""
    @State private var studentResendTimer = 0
    @State private var detectedUniversityName = ""
    @FocusState private var otpFocusField: Int?

    enum StudentVerifyStep { case idle, enterEmail, enterOtp, verified, skipped }

    // Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [PlatformImage] = []
    @State private var showNoFaceAlert = false
    @State private var noFaceCount = 0

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var detectingLocation = false
    @State private var showSelfieVerification = false

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
        .alert("Face Not Detected", isPresented: $showNoFaceAlert) {
            Button("OK") {}
        } message: {
            Text(noFaceCount == 1
                 ? "The photo you selected doesn't contain a visible face. Please upload a photo that clearly shows your face."
                 : "\(noFaceCount) photos were rejected because no face was detected. Please upload photos that clearly show your face.")
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
                university = user.university ?? ""
                universityLocation = user.universityLocation ?? ""
                study = user.study ?? ""
            }
            // Auto-fill location from device GPS if not already set
            if location.isEmpty && locationManager.city != "Unknown" {
                location = locationManager.city
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = 20
            }
        }
        .onChange(of: locationManager.city) { _, newCity in
            if newCity != "Unknown" && (location.isEmpty || detectingLocation) {
                location = newCity
                detectingLocation = false
            }
        }
        .navigationDestination(isPresented: $showSelfieVerification) {
            OnboardingSelfieView {
                // Called after verify or skip — finalize onboarding
                Task { await auth.refreshProfile() }
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
                    HStack {
                        sectionLabel("LOCATION")
                        Spacer()
                        Button {
                            detectingLocation = true
                            locationManager.updateLocation()
                        } label: {
                            HStack(spacing: 4) {
                                if locationManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white.opacity(0.5))
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 11))
                                }
                                Text("Detect")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        }
                    }
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

                // Education picker
                UniversityPickerView(
                    selectedUniversity: $university,
                    selectedLocation: $universityLocation,
                    selectedStudy: $study,
                    countryCode: locationManager.countryCode
                )
                .onChange(of: university) { _, newUni in
                    // Show email verification prompt when university is selected
                    if !newUni.isEmpty && studentVerifyStep == .idle {
                        studentVerifyStep = .enterEmail
                    } else if newUni.isEmpty {
                        studentVerifyStep = .idle
                    }
                }

                // Inline student verification
                if !university.isEmpty {
                    studentVerificationSection
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionLabel("HEIGHT")
                        Spacer()
                        let feet = heightCm * 100 / 3048
                        let inches = (heightCm * 100 % 3048) * 12 / 3048
                        Text("\(heightCm) cm · \(feet)'\(inches)\"")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    HStack(spacing: 16) {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.3))
                            .scaleEffect(y: 0.7)

                        Slider(value: Binding(
                            get: { Double(heightCm) },
                            set: { heightCm = Int($0) }
                        ), in: 140...220, step: 1)
                        .tint(.white)

                        Image(systemName: "figure.stand")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(16)
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )

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

                Text("Add up to 3 photos with your face visible")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { index in
                    if index < photoImages.count {
                        ZStack(alignment: .topTrailing) {
                            platformImageView(photoImages[index])
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
                                var rejected = 0
                                for item in items {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = decodeImageData(data) {
                                        if imageContainsFace(image) {
                                            photoImages.append(image)
                                        } else {
                                            rejected += 1
                                        }
                                    }
                                }
                                selectedPhotos = []
                                if rejected > 0 {
                                    noFaceCount = rejected
                                    showNoFaceAlert = true
                                }
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

    // MARK: - Student Verification (Inline)

    private var isValidStudentEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.edu(\.[a-z]{2})?$"#
        return studentEmail.range(of: pattern, options: .regularExpression) != nil
    }

    @ViewBuilder
    private var studentVerificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "4ECDC4"))
                sectionLabel("VERIFY STUDENT STATUS")
            }

            switch studentVerifyStep {
            case .verified:
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: "4ECDC4"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Student Verified")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        if !detectedUniversityName.isEmpty {
                            Text(detectedUniversityName)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color(hex: "4ECDC4").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(hex: "4ECDC4").opacity(0.3), lineWidth: 1)
                )

            case .skipped:
                HStack(spacing: 10) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("You can verify later from your profile")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                    Spacer()
                    Button {
                        studentVerifyStep = .enterEmail
                    } label: {
                        Text("Verify")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "4ECDC4"))
                    }
                }
                .padding(14)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            case .enterEmail:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter your university email to get a verified student badge")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))

                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.3))
                        TextField("", text: $studentEmail,
                                  prompt: Text("you@university.edu").foregroundStyle(.white.opacity(0.2)))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    .padding(14)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )

                    if !studentEmail.isEmpty && !isValidStudentEmail {
                        Text("Please enter a valid .edu email")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(hex: "FF5864"))
                    }

                    HStack(spacing: 10) {
                        Button {
                            sendStudentVerificationCode()
                        } label: {
                            HStack(spacing: 6) {
                                if isSendingCode {
                                    ProgressView().scaleEffect(0.7).tint(.white)
                                }
                                Text(isSendingCode ? "Sending..." : "Send Code")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(isValidStudentEmail ? bg : bg.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(isValidStudentEmail ? .white : .white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!isValidStudentEmail || isSendingCode)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                studentVerifyStep = .skipped
                            }
                        } label: {
                            Text("Skip")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                }
                .padding(14)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )

            case .enterOtp:
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter the 6-digit code sent to")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(studentEmail)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { index in
                            TextField("", text: $studentOtp[index])
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(height: 48)
                                .background(studentOtp[index].isEmpty ? .white.opacity(0.06) : .white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(studentOtp[index].isEmpty ? .white.opacity(0.1) : Color(hex: "4ECDC4").opacity(0.5), lineWidth: 1)
                                )
                                .focused($otpFocusField, equals: index)
                                .onChange(of: studentOtp[index]) { _, newValue in
                                    if newValue.count > 1 { studentOtp[index] = String(newValue.last!) }
                                    if !newValue.isEmpty && index < 5 { otpFocusField = index + 1 }
                                }
                        }
                    }

                    if !studentVerifyMessage.isEmpty {
                        Text(studentVerifyMessage)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(hex: "FF5864"))
                    }

                    HStack(spacing: 10) {
                        Button {
                            verifyStudentOtp()
                        } label: {
                            HStack(spacing: 6) {
                                if isVerifyingCode {
                                    ProgressView().scaleEffect(0.7).tint(.white)
                                }
                                Text(isVerifyingCode ? "Verifying..." : "Verify")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(!studentOtp.contains("") ? bg : bg.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(!studentOtp.contains("") ? .white : .white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(studentOtp.contains("") || isVerifyingCode)

                        Button {
                            if studentResendTimer == 0 { sendStudentVerificationCode() }
                        } label: {
                            Text(studentResendTimer > 0 ? "Resend (\(studentResendTimer)s)" : "Resend")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(studentResendTimer > 0 ? .white.opacity(0.2) : .white.opacity(0.4))
                        }
                        .disabled(studentResendTimer > 0)

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                studentVerifyStep = .enterEmail
                                studentOtp = Array(repeating: "", count: 6)
                                studentVerifyMessage = ""
                            }
                        } label: {
                            Text("Back")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                }
                .padding(14)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )

            case .idle:
                EmptyView()
            }
        }
    }

    private func sendStudentVerificationCode() {
        isSendingCode = true
        studentVerifyMessage = ""
        Task {
            do {
                struct VerifyResponse: Codable { let message: String?; let university_name: String? }
                let result: VerifyResponse = try await APIService.shared.post(
                    path: "/student/verify", body: ["email": studentEmail])
                detectedUniversityName = result.university_name ?? ""
                withAnimation(.easeInOut(duration: 0.25)) {
                    studentVerifyStep = .enterOtp
                }
                startStudentResendTimer()
            } catch {
                studentVerifyMessage = "Failed to send code. Check your email and try again."
            }
            isSendingCode = false
        }
    }

    private func verifyStudentOtp() {
        isVerifyingCode = true
        studentVerifyMessage = ""
        Task {
            do {
                let otpString = studentOtp.joined()
                struct OtpResponse: Codable { let verified: Bool?; let university_name: String? }
                var body: [String: Any] = ["email": studentEmail, "otp": otpString]
                if !detectedUniversityName.isEmpty { body["university_name"] = detectedUniversityName }
                let _: OtpResponse = try await APIService.shared.post(
                    path: "/student/verify-otp", body: body)
                await auth.refreshProfile()
                withAnimation(.spring(response: 0.4)) {
                    studentVerifyStep = .verified
                }
            } catch {
                studentVerifyMessage = "Invalid code. Please try again."
            }
            isVerifyingCode = false
        }
    }

    private func startStudentResendTimer() {
        studentResendTimer = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if studentResendTimer > 0 { studentResendTimer -= 1 }
            else { timer.invalidate() }
        }
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

                // Encode photos as base64 data URIs
                var photoVars: [String: Any] = [:]
                for (index, image) in photoImages.prefix(3).enumerated() {
                    if let data = imageToJPEGData(image, compressionQuality: 0.8) {
                        let base64 = data.base64EncodedString()
                        photoVars["profile_photo_\(index + 1)"] = "data:image/jpeg;base64,\(base64)"
                    }
                }

                // Build mutation with optional photo fields
                var photoParams = ""
                var photoArgs = ""
                for i in 1...3 {
                    let key = "profile_photo_\(i)"
                    if photoVars[key] != nil {
                        photoParams += ",\n                    $\(key): String"
                        photoArgs += ",\n                        \(key): $\(key)"
                    }
                }

                let query = """
                mutation UpdateProfile(
                    $name: String!,
                    $dob: String!,
                    $gender: String!,
                    $bio: String!,
                    $location: String!,
                    $looking_for: String!,
                    $interests: [String!]!,
                    $languages: [String!]!,
                    $height_cm: Int,
                    $profession_category: String,
                    $profession_title: String,
                    $university: String,
                    $university_location: String,
                    $study: String\(photoParams)
                ) {
                    update_profile(
                        name: $name,
                        dob: $dob,
                        gender: $gender,
                        bio: $bio,
                        location: $location,
                        looking_for: $looking_for,
                        interests: $interests,
                        languages: $languages,
                        height_cm: $height_cm,
                        profession_category: $profession_category,
                        profession_title: $profession_title,
                        university: $university,
                        university_location: $university_location,
                        study: $study\(photoArgs)
                    )
                }
                """

                var variables: [String: Any] = [
                    "name": name,
                    "dob": dobString,
                    "gender": gender,
                    "bio": bio,
                    "location": location,
                    "looking_for": lookingFor,
                    "interests": Array(selectedInterests),
                    "languages": Array(selectedLanguages),
                    "height_cm": heightCm,
                    "profession_category": professionCategory,
                    "profession_title": professionTitle,
                    "university": university,
                    "university_location": universityLocation,
                    "study": study,
                ]
                for (key, value) in photoVars {
                    variables[key] = value
                }

                let _: [String: Any] = try await APIService.shared.graphQL(
                    query: query,
                    variables: variables
                )
                // Navigate to selfie verification instead of finishing onboarding immediately
                showSelfieVerification = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

// MARK: - Onboarding Selfie Verification

struct OnboardingSelfieView: View {
    @EnvironmentObject var auth: AuthManager
    @StateObject private var camera = SelfieCameraModel()
    @State private var selfieImage: PlatformImage? = nil
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var floatOffset: CGFloat = 0
    @State private var flashOpacity: Double = 0

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1B2E"), Color(hex: "2D1B4E"), Color(hex: "1A1B2E")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "4ECDC4").opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: -80, y: -200 + floatOffset)

            Circle()
                .fill(Color(hex: "6A4C93").opacity(0.15))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 90, y: 100 - floatOffset)

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "shield.checkmark.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "4ECDC4"), Color(hex: "45B7D1")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(.bottom, 20)

                Text("Verify your identity")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text("Take a real-time selfie to earn a verified\nbadge and build trust with matches")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                // Live camera preview or captured photo
                ZStack {
                    if camera.permissionDenied {
                        // Camera permission not granted
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("Camera Access Required")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Please enable camera access in Settings to take a selfie.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Open Settings")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "1A1B2E"))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.06))
                    } else if let image = selfieImage {
                        platformImageView(image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        SelfieCameraPreview(session: camera.session)

                        // Face guide hint
                        VStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 13))
                                Text("Position your face in the frame")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 12)
                        }
                    }

                    // Shutter flash
                    Color.white
                        .opacity(flashOpacity)
                        .allowsHitTesting(false)
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.bottom, 24)

                if selfieImage == nil && !camera.permissionDenied {
                    // Capture button
                    Button { takeSelfie() } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 3)
                                    .frame(width: 28, height: 28)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 20, height: 20)
                            }
                            Text("Take Selfie")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color(hex: "1A1B2E"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(camera.isReady ? .white : .white.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!camera.isReady)
                    .padding(.bottom, 16)
                } else {
                    // Retake / Verify buttons
                    HStack(spacing: 12) {
                        Button {
                            selfieImage = nil
                            camera.reset()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Retake")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.25), lineWidth: 1.5)
                            )
                        }

                        Button { verifySelfie() } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView().tint(Color(hex: "1A1B2E"))
                                }
                                Image(systemName: "checkmark.shield.fill")
                                Text(isSubmitting ? "Verifying..." : "Verify & Continue")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Color(hex: "1A1B2E"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(!isSubmitting ? .white : .white.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(.bottom, 16)
                }

                // Skip button
                Button {
                    onComplete()
                } label: {
                    Text("Skip for now")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()
                    .frame(height: 50)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            camera.start()
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = 20
            }
        }
        .onDisappear { camera.stop() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if camera.permissionDenied {
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                if status == .authorized {
                    camera.permissionDenied = false
                    camera.start()
                }
            }
        }
        .onChange(of: camera.capturedPhoto) { _, photo in
            if let photo { selfieImage = photo }
        }
        .alert("Verification", isPresented: $showAlert) {
            Button("Continue") { onComplete() }
        } message: {
            Text(alertMessage)
        }
    }

    private func takeSelfie() {
        withAnimation(.easeOut(duration: 0.1)) { flashOpacity = 0.6 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.2)) { flashOpacity = 0 }
        }
        camera.capturePhoto()
    }

    private func verifySelfie() {
        guard let image = selfieImage else { return }
        isSubmitting = true
        Task {
            // Check selfie contains a face
            guard imageContainsFace(image) else {
                alertMessage = "No face detected in your selfie. Please take a clearer photo."
                selfieImage = nil
                camera.reset()
                isSubmitting = false; showAlert = true; return
            }

            // Compare selfie against profile photos (skip for demo mode or no photos)
            if let photos = auth.user?.photos, !photos.isEmpty, auth.token != nil {
                let referenceImages = await downloadProfilePhotos(photos)
                if !referenceImages.isEmpty {
                    let result = selfieFaceMatchesAnyReference(
                        selfie: image,
                        references: referenceImages
                    )
                    guard result.matches else {
                        alertMessage = "Your selfie doesn't appear to match your profile photos. Please take a selfie of yourself."
                        selfieImage = nil
                        camera.reset()
                        isSubmitting = false; showAlert = true; return
                    }
                }
            }

            await uploadSelfie(image)
        }
    }

    private func uploadSelfie(_ image: PlatformImage) async {
        guard let imageData = imageToJPEGData(image, compressionQuality: 0.8) else {
            alertMessage = "Could not process image."
            isSubmitting = false; showAlert = true; return
        }
        do {
            struct VerifyResponse: Codable {
                let verified: Bool?
                let message: String?
                let confidence: Double?
            }
            let result: VerifyResponse = try await APIService.shared.multipartUpload(
                path: "/verify/selfie",
                fileData: imageData,
                fileName: "selfie.jpg",
                mimeType: "image/jpeg",
                fileField: "selfie"
            )
            await auth.refreshProfile()
            if result.verified == true {
                alertMessage = "Verification successful! You now have a verified badge."
            } else {
                alertMessage = result.message ?? "Verification could not be completed. You can try again later from your profile."
            }
        } catch {
            alertMessage = "Verification failed: \(error.localizedDescription)\nYou can try again later from your profile."
        }
        isSubmitting = false
        showAlert = true
    }

    private func downloadProfilePhotos(_ photoPaths: [String]) async -> [PlatformImage] {
        var images: [PlatformImage] = []
        for path in photoPaths {
            guard let url = AppConfig.resolvePhotoURL(path) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = decodeImageData(data) {
                    images.append(image)
                }
            } catch {
                continue
            }
        }
        return images
    }
}

#Preview {
    NavigationStack {
        UpdateProfileView()
            .environmentObject(AuthManager())
            .environmentObject(LocationManager())
    }
}
