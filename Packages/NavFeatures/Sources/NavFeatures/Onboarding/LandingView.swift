import SwiftUI
import NavCore
import NavServices

public struct LandingView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var appear = false
    @State private var floatOffset: CGFloat = 0

    public init() {}

    public var body: some View {
        ZStack {
            // Background gradient
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

            // Subtle floating orbs
            Circle()
                .fill(Color(hex: "FF5864").opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -80, y: -200 + floatOffset)

            Circle()
                .fill(Color(hex: "6A4C93").opacity(0.2))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 100, y: 100 - floatOffset)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                Image("NavaHero")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    .scaleEffect(appear ? 1 : 0.8)
                    .opacity(appear ? 1 : 0)
                    .padding(.bottom, 32)

                // Brand
                Text("NAVA")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(8)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

                Text("Where culture meets chemistry")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 6)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    NavigationLink(destination: LoginView()) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "1A1B2E"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    NavigationLink(destination: LoginView()) {
                        Text("I already have an account")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                            )
                    }

                    #if DEBUG
                    HStack(spacing: 12) {
                        Button {
                            auth.loginWithDemoUser()
                        } label: {
                            Text("Demo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Text("·").foregroundStyle(.white.opacity(0.2))

                        Button {
                            auth.loginWithDemoNewUser()
                        } label: {
                            Text("Demo (New)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 4)
                    #endif
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = 20
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationStack {
        LandingView()
            .environmentObject(AuthManager())
    }
}
