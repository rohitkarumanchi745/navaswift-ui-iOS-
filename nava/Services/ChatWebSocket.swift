import Foundation
import Combine

/// Real-time WebSocket chat client matching the Rust backend `/ws/chat` protocol.
/// Message format: `{ "type": "message"|"typing"|"read", "content": "...", "message_id": N }`
@MainActor
class ChatWebSocket: ObservableObject {
    @Published var incomingMessages: [IncomingChatEvent] = []
    @Published var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var matchId: String = ""
    private var token: String = ""
    private var pingTask: Task<Void, Never>?

    struct IncomingChatEvent: Identifiable {
        let id = UUID()
        let type: String       // "message", "typing", "read", "connected"
        let senderId: Int?
        let content: String?
        let messageId: Int?
        let timestamp: String?
    }

    func connect(matchId: String, token: String) {
        self.matchId = matchId
        self.token = token

        let base = AppConfig.shared.wsBaseURL
        guard let url = URL(string: "\(base)/ws/chat?match_id=\(matchId)&token=\(token)") else { return }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        receiveLoop()
        startPing()
    }

    func disconnect() {
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - Send

    func sendMessage(_ content: String) {
        let payload: [String: Any] = ["type": "message", "content": content]
        sendJSON(payload)
    }

    func sendTyping() {
        sendJSON(["type": "typing"])
    }

    func sendRead(messageId: Int) {
        let payload: [String: Any] = ["type": "read", "message_id": messageId]
        sendJSON(payload)
    }

    // MARK: - Private

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(str)) { _ in }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self.handleMessage(text)
                    }
                    self.receiveLoop()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        let event = IncomingChatEvent(
            type: type,
            senderId: json["sender_id"] as? Int,
            content: json["content"] as? String,
            messageId: json["message_id"] as? Int,
            timestamp: json["timestamp"] as? String
        )
        incomingMessages.append(event)
    }

    private func startPing() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                webSocketTask?.sendPing { _ in }
            }
        }
    }

    private func scheduleReconnect() {
        guard !matchId.isEmpty else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            if !isConnected {
                connect(matchId: matchId, token: token)
            }
        }
    }
}
