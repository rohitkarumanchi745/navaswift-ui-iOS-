import SwiftUI
import Combine

struct OtpVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    let phoneNumber: String

    @State private var otp = ""
    @State private var isVerifying = false
    @State private var cooldown = 0
    @State private var showError = false
    @State private var errorMessage = ""

    private let otpLength = 4

    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background gradient matching landing/login
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
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: -100, y: -180 + floatOffset)

            Circle()
                .fill(Color(hex: "6A4C93").opacity(0.15))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 90, y: 120 - floatOffset)

            VStack(spacing: 0) {
                Spacer()

                Text("Enter code")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 10)

                Text(phoneNumber)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
                    .padding(.bottom, 40)

                // OTP Input boxes
                HStack(spacing: 12) {
                    ForEach(0..<otpLength, id: \.self) { index in
                        let char = index < otp.count ? String(otp[otp.index(otp.startIndex, offsetBy: index)]) : ""
                        Text(char)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(.white.opacity(index < otp.count ? 0.15 : 0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        index == otp.count
                                            ? Color(hex: "FF5864")
                                            : .white.opacity(index < otp.count ? 0.2 : 0.08),
                                        lineWidth: index == otp.count ? 2 : 1
                                    )
                            )
                    }
                }
                .overlay {
                    TextField("", text: $otp)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .opacity(0.01)
                        .onChange(of: otp) { _, newValue in
                            otp = String(newValue.filter(\.isNumber).prefix(otpLength))
                        }
                }
                .padding(.bottom, 32)

                // Verify button
                Button {
                    handleVerify()
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView().tint(Color(hex: "1A1B2E"))
                        } else {
                            Text("Verify")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(Color(hex: "1A1B2E"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(otp.count == otpLength && !isVerifying ? .white : .white.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(otp.count != otpLength || isVerifying)
                .padding(.bottom, 20)

                // Resend
                Button {
                    handleResend()
                } label: {
                    if cooldown > 0 {
                        Text("Resend code in \(cooldown)s")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    } else {
                        Text("Resend code")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .disabled(cooldown > 0)

                Spacer()
                    .frame(height: 80)
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
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if cooldown > 0 { cooldown -= 1 }
        }
    }

    private func handleVerify() {
        guard otp.count == otpLength else { return }
        isVerifying = true

        Task {
            do {
                try await auth.verifyOtp(phoneNumber: phoneNumber, otp: otp)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isVerifying = false
        }
    }

    private func handleResend() {
        guard cooldown == 0 else { return }
        Task {
            do {
                try await auth.sendOtp(phoneNumber: phoneNumber)
                cooldown = 45
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
#Preview {
    NavigationStack {
        OtpVerificationView(phoneNumber: "+919876543210")
            .environmentObject(AuthManager())
    }
}

