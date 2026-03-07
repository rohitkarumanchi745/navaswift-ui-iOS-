import Foundation
import Combine
import NavNetworking

/// Real-time WebSocket chat client matching the Rust backend `/ws/chat` protocol.
/// Message format: `{ "type": "message"|"typing"|"read", "content": "...", "message_id": N }`
@MainActor
public class ChatWebSocket: ObservableObject {
    @Published public var incomingMessages: [IncomingChatEvent] = []
    @Published public var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var matchId: String = ""
    private var token: String = ""
    private var pingTask: Task<Void, Never>?

    public struct IncomingChatEvent: Identifiable {
        public let id = UUID()
        public let type: String       // "message", "typing", "read", "connected"
        public let senderId: Int?
        public let content: String?
        public let messageId: Int?
        public let timestamp: String?

        public init(type: String, senderId: Int? = nil, content: String? = nil, messageId: Int? = nil, timestamp: String? = nil) {
            self.type = type
            self.senderId = senderId
            self.content = content
            self.messageId = messageId
            self.timestamp = timestamp
        }
    }

    public init() {}

    public func connect(matchId: String, token: String) {
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

    public func disconnect() {
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - Send

    public func sendMessage(_ content: String) {
        let payload: [String: Any] = ["type": "message", "content": content]
        sendJSON(payload)
    }

    public func sendTyping() {
        sendJSON(["type": "typing"])
    }

    public func sendRead(messageId: Int) {
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
