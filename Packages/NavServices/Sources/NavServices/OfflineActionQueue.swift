import Foundation
import Combine
import NavCore
import NavNetworking

/// Persists failed swipe/like/pass actions to disk and replays them when connectivity is restored.
@MainActor
public final class OfflineActionQueue: ObservableObject {
    public static let shared = OfflineActionQueue()

    @Published public private(set) var pendingCount: Int = 0

    private var networkCancellable: AnyCancellable?

    private init() {
        pendingCount = loadActions().count
    }

    // MARK: - Action Model

    public enum ActionType: String, Codable {
        case like, pass, superLike
    }

    struct PendingAction: Codable, Identifiable {
        let id: String
        let targetUserId: String
        let actionType: ActionType
        let createdAt: Date

        init(targetUserId: String, actionType: ActionType) {
            self.id = UUID().uuidString
            self.targetUserId = targetUserId
            self.actionType = actionType
            self.createdAt = Date()
        }
    }

    // MARK: - Public API

    /// Enqueue a swipe action. If online, fires immediately; if offline, persists to disk.
    public func enqueue(targetUserId: String, action: ActionType) {
        let pending = PendingAction(targetUserId: targetUserId, actionType: action)
        Task {
            let success = await execute(pending)
            if !success {
                var actions = loadActions()
                actions.append(pending)
                saveActions(actions)
                pendingCount = actions.count
                NavLog.debug("OfflineActionQueue: queued \(action.rawValue) for user \(targetUserId) (\(actions.count) pending)", category: .network)
            }
        }
    }

    /// Starts observing network connectivity to auto-flush when online.
    public func observeNetwork(_ monitor: NetworkMonitor) {
        networkCancellable = monitor.$isConnected
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.flush()
                }
            }
    }

    /// Flush all pending actions. Called when connectivity is restored.
    public func flush() async {
        var actions = loadActions()
        guard !actions.isEmpty else { return }

        NavLog.info("OfflineActionQueue: flushing \(actions.count) pending actions", category: .network)

        var remaining: [PendingAction] = []
        for action in actions {
            let success = await execute(action)
            if !success {
                // Only keep actions less than 24h old
                if Date().timeIntervalSince(action.createdAt) < 86400 {
                    remaining.append(action)
                }
            }
        }

        saveActions(remaining)
        pendingCount = remaining.count

        if remaining.isEmpty {
            NavLog.info("OfflineActionQueue: all actions flushed successfully", category: .network)
        } else {
            NavLog.warning("OfflineActionQueue: \(remaining.count) actions still pending", category: .network)
        }
    }

    /// Clear all pending actions (e.g. on logout).
    public func clearAll() {
        saveActions([])
        pendingCount = 0
    }

    // MARK: - Execution

    private func execute(_ action: PendingAction) async -> Bool {
        do {
            switch action.actionType {
            case .like:
                let query = """
                mutation LikeUser($targetUserId: Int!) {
                  likeUser(targetUserId: $targetUserId) { success isMutual matchId }
                }
                """
                let _: [String: Any] = try await APIService.shared.graphQL(
                    query: query,
                    variables: ["targetUserId": Int(action.targetUserId) ?? 0]
                )
            case .pass:
                let query = "mutation PassUser($targetUserId: Int!) { passUser(targetUserId: $targetUserId) }"
                let _: [String: Any] = try await APIService.shared.graphQL(
                    query: query,
                    variables: ["targetUserId": Int(action.targetUserId) ?? 0]
                )
            case .superLike:
                struct SuperLikeResponse: Decodable {
                    let message: String?
                    let matchId: String?
                    let isMutual: Bool?
                    let isSuperLike: Bool?
                    enum CodingKeys: String, CodingKey {
                        case message
                        case matchId = "match_id"
                        case isMutual = "is_mutual"
                        case isSuperLike = "is_super_like"
                    }
                }
                let _: SuperLikeResponse = try await APIService.shared.post(
                    path: "/match/super-like",
                    body: ["target_user_id": Int(action.targetUserId) ?? 0]
                )
            }
            return true
        } catch {
            NavLog.debug("OfflineActionQueue: execute \(action.actionType.rawValue) failed for \(action.targetUserId): \(error.localizedDescription)", category: .network)
            return false
        }
    }

    // MARK: - Persistence

    private func loadActions() -> [PendingAction] {
        guard let data = LocalCache.shared.loadStale([PendingAction].self, forKey: .offlineActions) else {
            return []
        }
        return data
    }

    private func saveActions(_ actions: [PendingAction]) {
        if actions.isEmpty {
            LocalCache.shared.remove(forKey: .offlineActions)
        } else {
            LocalCache.shared.save(actions, forKey: .offlineActions)
        }
    }
}
