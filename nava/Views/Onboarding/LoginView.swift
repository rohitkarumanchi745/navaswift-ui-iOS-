import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var rawPhone = ""
    @State private var selectedCountry = Country.all.first(where: { $0.code == "IN" }) ?? Country.all[0]
    @State private var showCountryPicker = false
    @State private var countrySearch = ""
    @State private var countdown = 0
    @State private var isSubmitting = false
    @State private var isFocused = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToOtp = false
    @State private var fullPhoneNumber = ""

    private var phoneDigits: String {
        rawPhone.filter(\.isNumber)
    }

    private var canSubmit: Bool {
        phoneDigits.count >= selectedCountry.minLength && countdown == 0
    }

    private var filteredCountries: [Country] {
        if countrySearch.isEmpty { return Country.all }
        let search = countrySearch.lowercased()
        return Country.all.filter {
            $0.name.lowercased().contains(search) ||
            $0.dialCode.contains(search) ||
            $0.code.lowercased().contains(search)
        }
    }

    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background gradient matching landing
            LinearGradient(
                colors: [
                    Color(hex: "1A1B2E"),
                    Color(hex: "2D1B4E"),
                    Color(hex: "1A1B2E")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating orbs
            Circle()
                .fill(Color(hex: "FF5864").opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: 100, y: -250 + floatOffset)

            Circle()
                .fill(Color(hex: "6A4C93").opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -80, y: 150 - floatOffset)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                Image("NavaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                    .padding(.bottom, 32)

                // Title
                Text("Welcome back")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text("Enter your phone number to continue")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 36)

                // Returning user card
                if let user = auth.user, !user.id.isEmpty {
                    Button {
                        // Navigate to main app
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if let photo = user.primaryPhoto {
                                        AsyncImage(url: URL(string: photo)) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }

                            Text("Continue as \(user.displayName)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 20)
                }

                // Phone Input
                HStack(spacing: 0) {
                    Button {
                        showCountryPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedCountry.flag)
                                .font(.system(size: 20))
                            Text(selectedCountry.dialCode)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 1, height: 24)

                    TextField("Phone number", text: $rawPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)

                    if countdown > 0 {
                        Text("\(countdown)s")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.trailing, 14)
                    }
                }
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(isFocused ? 0.3 : 0.12), lineWidth: 1)
                )
                .padding(.bottom, 16)

                // Continue button
                Button {
                    handleSendOtp()
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(Color(hex: "1A1B2E"))
                        } else {
                            Text("Continue")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(Color(hex: "1A1B2E"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(canSubmit && !isSubmitting ? .white : .white.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canSubmit || isSubmitting)
                .padding(.bottom, 32)

                // Footer
                Text("By continuing, you agree to our **Terms** and **Privacy Policy**")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)

                Spacer()
                    .frame(height: 50)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = 20
            }
        }
        .navigationDestination(isPresented: $navigateToOtp) {
            OtpVerificationView(phoneNumber: fullPhoneNumber)
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(
                selectedCountry: $selectedCountry,
                isPresented: $showCountryPicker
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if countdown > 0 { countdown -= 1 }
        }
    }

    private func handleSendOtp() {
        guard phoneDigits.count >= selectedCountry.minLength else {
            errorMessage = "Please enter a valid \(selectedCountry.name) phone number."
            showError = true
            return
        }

        isSubmitting = true
        fullPhoneNumber = "\(selectedCountry.dialCode)\(phoneDigits)"
        navigateToOtp = true

        Task {
            do {
                try await auth.sendOtp(phoneNumber: fullPhoneNumber)
                countdown = 60
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthManager())
    }
}

// MARK: - Country Picker Sheet
struct CountryPickerSheet: View {
    @Binding var selectedCountry: Country
    @Binding var isPresented: Bool
    @State private var search = ""

    private var filtered: [Country] {
        if search.isEmpty { return Country.all }
        let s = search.lowercased()
        return Country.all.filter {
            $0.name.lowercased().contains(s) ||
            $0.dialCode.contains(s) ||
            $0.code.lowercased().contains(s)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selectedCountry = country
                    isPresented = false
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flag)
                            .font(.system(size: 24))

                        VStack(alignment: .leading) {
                            Text(country.name)
                                .font(.system(size: 16))
                            Text(country.dialCode)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedCountry.code == country.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $search, prompt: "Search")
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}
