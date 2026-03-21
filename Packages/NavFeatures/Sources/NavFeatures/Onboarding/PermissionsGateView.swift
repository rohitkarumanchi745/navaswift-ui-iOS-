import SwiftUI
import CoreLocation
import AVFoundation
import CoreBluetooth
import NavCore
import NavServices

/// Shown before onboarding for new users.
/// All three permissions (location, camera, microphone) must be granted to proceed.
public struct PermissionsGateView: View {
    @EnvironmentObject var locationManager: LocationManager
    let onAllGranted: () -> Void

    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var locationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus
    @State private var bluetoothStatus: CBManagerAuthorization = .notDetermined
    @State private var btManager: CBCentralManager? = nil

    private var allGranted: Bool {
        cameraStatus == .authorized &&
        micStatus == .authorized &&
        (locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways) &&
        bluetoothStatus == .allowedAlways
    }

    private let bg = Color(hex: "0F0F1A")
    private let coral = Color(hex: "FF5864")
    private let purple = Color(hex: "6A4C93")

    public init(onAllGranted: @escaping () -> Void) {
        self.onAllGranted = onAllGranted
    }

    public var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            Circle()
                .fill(coral.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 130, y: -280)

            Circle()
                .fill(purple.opacity(0.1))
                .frame(width: 220, height: 220)
                .blur(radius: 80)
                .offset(x: -120, y: 250)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(coral)

                    Text("Before we begin")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Nava needs a few permissions to give you the best experience. All are required to continue.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 48)

                VStack(spacing: 16) {
                    permissionRow(
                        icon: "location.fill",
                        title: "Location",
                        description: "Show you people nearby",
                        status: locationPermissionGranted
                    )
                    permissionRow(
                        icon: "camera.fill",
                        title: "Camera",
                        description: "Upload photos and video reels",
                        status: cameraStatus == .authorized
                    )
                    permissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Voice notes and video calls",
                        status: micStatus == .authorized
                    )
                    permissionRow(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Bluetooth",
                        description: "Audio routing to headphones & speakers",
                        status: bluetoothStatus == .allowedAlways
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 14) {
                    if allGranted {
                        Button { onAllGranted() } label: {
                            Text("Continue")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        Button { requestAll() } label: {
                            Text("Allow Access")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        if anyDenied {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Open Settings")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear { refreshStatuses() }
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

    private func permissionRow(icon: String, title: String, description: String, status: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(status ? Color(hex: "4ECDC4").opacity(0.15) : .white.opacity(0.06))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(status ? Color(hex: "4ECDC4") : .white.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: status ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(status ? Color(hex: "4ECDC4") : .white.opacity(0.2))
        }
        .padding(16)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(status ? Color(hex: "4ECDC4").opacity(0.3) : .white.opacity(0.08), lineWidth: 1)
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
