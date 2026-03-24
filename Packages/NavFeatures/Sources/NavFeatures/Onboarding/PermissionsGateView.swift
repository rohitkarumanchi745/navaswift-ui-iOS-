import SwiftUI
import CoreLocation
import AVFoundation
import CoreBluetooth
import NavCore
import NavServices

/// Shown before onboarding for new users.
/// All four permissions (location, camera, microphone, bluetooth) must be granted to proceed.
public struct PermissionsGateView: View {
    @EnvironmentObject var locationManager: LocationManager
    let onAllGranted: () -> Void

    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var locationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus
    @State private var bluetoothStatus: CBManagerAuthorization = .notDetermined
    @State private var btManager: CBCentralManager? = nil
    @State private var floatOffset: CGFloat = 0
    @State private var appear = false

    private var allGranted: Bool {
        cameraStatus == .authorized &&
        micStatus == .authorized &&
        (locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways) &&
        bluetoothStatus == .allowedAlways
    }

    public init(onAllGranted: @escaping () -> Void) {
        self.onAllGranted = onAllGranted
    }

    public var body: some View {
        ZStack {
            // Match LandingView gradient background
            AppColors.darkGradient
                .ignoresSafeArea()

            // Floating orbs matching app style
            Circle()
                .fill(AppColors.primary.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 120, y: -260 + floatOffset)

            Circle()
                .fill(AppColors.secondary.opacity(0.2))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: -100, y: 200 - floatOffset)

            Circle()
                .fill(AppColors.purpleAccent.opacity(0.08))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 60, y: 80 + floatOffset * 0.5)

            VStack(spacing: 0) {
                Spacer()

                // Header icon and text
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.purpleAccent.opacity(0.15))
                            .frame(width: 88, height: 88)
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.purpleAccent, AppColors.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .opacity(appear ? 1 : 0)
                    .scaleEffect(appear ? 1 : 0.8)

                    Text("Before we begin")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 10)

                    Text("Nava needs a few permissions to give you the best experience.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 10)
                }

                Spacer().frame(height: 40)

                // Permission rows
                VStack(spacing: 12) {
                    permissionRow(
                        icon: "location.circle.fill",
                        iconGradient: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                        title: "Location",
                        description: "Show you people nearby",
                        status: locationPermissionGranted
                    )
                    permissionRow(
                        icon: "camera.circle.fill",
                        iconGradient: [AppColors.primary, Color(hex: "FF8E53")],
                        title: "Camera",
                        description: "Upload photos and video reels",
                        status: cameraStatus == .authorized
                    )
                    permissionRow(
                        icon: "mic.circle.fill",
                        iconGradient: [Color(hex: "00B894"), Color(hex: "4ECDC4")],
                        title: "Microphone",
                        description: "Voice notes and video calls",
                        status: micStatus == .authorized
                    )
                    permissionRow(
                        icon: "airpodsmax",
                        iconGradient: [AppColors.purpleAccent, Color(hex: "845EC2")],
                        title: "Bluetooth",
                        description: "Audio routing to headphones & speakers",
                        status: bluetoothStatus == .allowedAlways
                    )
                }
                .padding(.horizontal, 24)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

                Spacer()

                // Action buttons
                VStack(spacing: 14) {
                    if allGranted {
                        Button { onAllGranted() } label: {
                            Text("Continue")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.darkBg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        Button { requestAll() } label: {
                            Text("Allow Access")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.purpleAccent, AppColors.secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        if anyDenied {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "gear")
                                        .font(.system(size: 13))
                                    Text("Open Settings")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
            }
        }
        .onAppear {
            refreshStatuses()
            withAnimation(.easeOut(duration: 0.7)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = 18
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshStatuses()
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            locationStatus = status
        }
    }

    private var locationPermissionGranted: Bool {
        locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
    }

    private var anyDenied: Bool {
        cameraStatus == .denied || micStatus == .denied ||
        locationStatus == .denied || locationStatus == .restricted ||
        bluetoothStatus == .denied || bluetoothStatus == .restricted
    }

    private func permissionRow(
        icon: String,
        iconGradient: [Color],
        title: String,
        description: String,
        status: Bool
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        status
                            ? AnyShapeStyle(AppColors.verified.opacity(0.12))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: iconGradient.map { $0.opacity(0.15) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        status
                            ? AnyShapeStyle(AppColors.verified)
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: iconGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Image(systemName: status ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(status ? AppColors.verified : .white.opacity(0.15))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(status ? 0.06 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    status ? AppColors.verified.opacity(0.25) : .white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    private func requestAll() {
        locationManager.requestPermission()

        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { cameraStatus = granted ? .authorized : .denied }
        }

        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { micStatus = granted ? .authorized : .denied }
        }

        // Triggering CBCentralManager init prompts the Bluetooth permission dialog
        btManager = CBCentralManager(delegate: nil, queue: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            refreshStatuses()
        }
    }

    private func refreshStatuses() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        locationStatus = locationManager.authorizationStatus
        bluetoothStatus = CBCentralManager.authorization
    }
}
