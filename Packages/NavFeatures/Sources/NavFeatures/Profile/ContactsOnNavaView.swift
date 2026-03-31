import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct ContactsOnNavaView: View {
    @EnvironmentObject var contactService: ContactMatchingService

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if contactService.contactsPermissionStatus != .authorized {
                permissionPrompt
            } else if contactService.isSyncing {
                ProgressView()
                    .tint(AppColors.purpleAccent)
                    .scaleEffect(1.2)
            } else if contactService.friends.isEmpty {
                emptyState
            } else {
                friendsList
            }
        }
        .navigationTitle("Friends on NAVA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Friends List

    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(contactService.friends) { friend in
                    HStack(spacing: 14) {
                        if let photoPath = friend.photo,
                           let url = AppConfig.resolvePhotoURL(photoPath) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                default:
                                    friendPlaceholder
                                }
                            }
                        } else {
                            friendPlaceholder
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(friend.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)

                            if let age = friend.age {
                                Text("\(age) years old")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    if friend.id != contactService.friends.last?.id {
                        Rectangle()
                            .fill(.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.leading, 82)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var friendPlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 42))
            .foregroundStyle(.white.opacity(0.2))
            .frame(width: 48, height: 48)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "7BB3FF").opacity(0.5))

            Text("No Friends Found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("None of your contacts are on NAVA yet. Invite them to join!")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Permission Prompt

    private var permissionPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color(hex: "7BB3FF").opacity(0.6))

            Text("Find Friends on NAVA")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("Allow contact access to discover which of your friends are already on NAVA. Your contacts are hashed for privacy.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if contactService.contactsPermissionStatus == .notDetermined {
                Button {
                    Task { await contactService.requestAndSync() }
                } label: {
                    Text("Allow Access")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "6C5CE7"), Color(hex: "845EC2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
            } else {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.darkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 40)

                Text("Contacts access was denied. Open Settings to allow it.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}
