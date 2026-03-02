import SwiftUI

struct UpdateProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var step = 0
    @State private var name = ""
    @State private var gender = ""
    @State private var profession = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var floatOffset: CGFloat = 0

    private let totalSteps = 4
    private let genders = ["Man", "Woman", "Non-binary", "Other"]

    var body: some View {
        ZStack {
            // Deep dark background
            Color(hex: "0F0F1A").ignoresSafeArea()

            // Subtle floating orbs
            Circle()
                .fill(Color(hex: "FF5864").opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 130, y: -280 + floatOffset)

            Circle()
                .fill(Color(hex: "6A4C93").opacity(0.1))
                .frame(width: 220, height: 220)
                .blur(radius: 80)
                .offset(x: -120, y: 250 - floatOffset)

            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.top, 16)
                    .padding(.horizontal, 40)

                Spacer()

                // Step content with transitions
                Group {
                    switch step {
                    case 0: nameStep
                    case 1: genderStep
                    case 2: professionStep
                    case 3: bioStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)

                Spacer()

                // Continue button
                VStack(spacing: 16) {
                    Button {
                        advance()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(Color(hex: "0F0F1A"))
                            } else {
                                Text(step == totalSteps - 1 ? "Finish" : "Continue")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundStyle(Color(hex: "0F0F1A"))
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
                            Text("Skip for now")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step -= 1
                        }
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
                profession = user.professionTitle ?? ""
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = 20
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? .white : .white.opacity(0.15))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
    }

    // MARK: - Step Views

    private var nameStep: some View {
        VStack(spacing: 20) {
            Text("What's your\nfirst name?")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("This is how you'll appear on NAVA")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))

            TextField("", text: $name, prompt: Text("Your name").foregroundStyle(.white.opacity(0.25)))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.horizontal, 60)
                .padding(.top, 20)
        }
        .padding(.horizontal, 32)
    }

    private var genderStep: some View {
        VStack(spacing: 28) {
            Text("I identify as")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                ForEach(genders, id: \.self) { g in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            gender = g
                        }
                    } label: {
                        Text(g)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(gender == g ? Color(hex: "0F0F1A") : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(gender == g ? .white : .white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(gender == g ? 0 : 0.1), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 32)
    }

    private var professionStep: some View {
        VStack(spacing: 20) {
            Text("What do\nyou do?")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("Your profession helps find better matches")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))

            TextField("", text: $profession, prompt: Text("e.g. Software Engineer").foregroundStyle(.white.opacity(0.25)))
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
        }
        .padding(.horizontal, 32)
    }

    private var bioStep: some View {
        VStack(spacing: 20) {
            Text("Tell us about\nyourself")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("A short bio helps people get to know you")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))

            ZStack(alignment: .topLeading) {
                if bio.isEmpty {
                    Text("Write something interesting...")
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(.white.opacity(0.2))
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                }
                TextEditor(text: $bio)
                    .font(.system(size: 17, design: .rounded))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(height: 140)
                    .padding(12)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .padding(.top, 12)

            // Character count
            HStack {
                Spacer()
                Text("\(bio.count)/300")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Logic

    private var canAdvance: Bool {
        switch step {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !gender.isEmpty
        case 2: return !profession.trimmingCharacters(in: .whitespaces).isEmpty
        case 3: return true
        default: return false
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.35)) {
                step += 1
            }
        } else {
            saveProfile()
        }
    }

    private func saveProfile() {
        isSaving = true
        Task {
            do {
                let query = """
                mutation UpdateProfile($input: UpdateProfileInput!) {
                  updateProfile(input: $input) {
                    id isProfileComplete
                  }
                }
                """
                let _: [String: Any] = try await APIService.shared.graphQL(
                    query: query,
                    variables: ["input": [
                        "name": name,
                        "gender": gender,
                        "bio": bio,
                        "professionTitle": profession,
                    ]]
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
