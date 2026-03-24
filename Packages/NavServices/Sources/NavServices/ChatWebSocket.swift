import Foundation
import UIKit
import NavCore
import NavNetworking

/// Real-time WebSocket chat client matching the Rust backend `/ws/chat` protocol.
/// Message format: `{ "type": "message"|"typing"|"read", "content": "...", "message_id": N }`
@MainActor
public class ChatWebSocket: ObservableObject {
    // MARK: - Connection State

    public enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
    }

    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var incomingMessages: [IncomingChatEvent] = []

    /// Partner presence state — updated via WebSocket "presence" events
    @Published public var partnerIsOnline: Bool = false
    @Published public var partnerLastSeen: Date?

    /// Backward-compatible convenience accessor
    public var isConnected: Bool { connectionState == .connected }

    private var webSocketTask: URLSessionWebSocketTask?
    private var matchId: String = ""
    private var token: String = ""
    private var pingTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let maxQueuedMessages = 50
    private let maxStoredEvents = 500

    /// Messages queued while disconnected, sent on reconnect
    private var pendingMessages: [[String: Any]] = []

    /// Whether to broadcast our own online presence (respects privacy setting)
    private var broadcastPresence = true

    /// Foreground observer
    private var foregroundObserver: NSObjectProtocol?

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

    public init() {
        setupForegroundObserver()
    }

    deinit {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Lifecycle

    private func setupForegroundObserver() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.matchId.isEmpty && self.connectionState != .connected && self.connectionState != .connecting {
                    NavLog.info("App foregrounded, reconnecting WebSocket", category: .chat)
                    self.reconnectAttempts = 0
                    self.doConnect()
                }
            }
        }
    }

    public func connect(matchId: String, token: String, showOnlineStatus: Bool = true) {
        self.matchId = matchId
        self.token = token
        self.broadcastPresence = showOnlineStatus
        reconnectAttempts = 0
        partnerIsOnline = false
        partnerLastSeen = nil
        doConnect()
    }

    private func doConnect() {
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)

        let base = AppConfig.shared.wsBaseURL
        guard let url = URL(string: "\(base)/ws/chat?match_id=\(matchId)&token=\(token)") else {
            NavLog.error("Invalid WebSocket URL for match: \(matchId)", category: .chat)
            return
        }

        connectionState = reconnectAttempts > 0 ? .reconnecting(attempt: reconnectAttempts) : .connecting
        NavLog.debug("WebSocket connecting to match \(matchId)", category: .chat)

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveLoop()
        startPing()
    }

    public func disconnect() {
        NavLog.debug("WebSocket disconnecting", category: .chat)
        sendPresence(online: false)
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        pendingMessages.removeAll()
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

    /// Sends our presence status. Respects the `broadcastPresence` privacy setting —
    /// if disabled, we still send "offline" but never "online".
    private func sendPresence(online: Bool) {
        let status = (online && broadcastPresence) ? "online" : "offline"
        sendJSON(["type": "presence", "status": status])
    }

    // MARK: - Private

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            NavLog.warning("Failed to serialize WebSocket message", category: .chat)
            return
        }

        guard connectionState == .connected, let task = webSocketTask else {
            if pendingMessages.count < maxQueuedMessages {
                pendingMessages.append(dict)
                NavLog.debug("Queued message (pending: \(pendingMessages.count))", category: .chat)
            } else {
                NavLog.warning("Message queue full, dropping message", category: .chat)
            }
            return
        }

        task.send(.string(str)) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    NavLog.warning("WebSocket send failed: \(error.localizedDescription)", category: .chat)
                    if let self, self.pendingMessages.count < self.maxQueuedMessages {
                        self.pendingMessages.append(dict)
                    }
                }
            }
        }
    }

    private func flushPendingMessages() {
        guard connectionState == .connected else { return }
        let messages = pendingMessages
        pendingMessages.removeAll()

        if !messages.isEmpty {
            NavLog.info("Flushing \(messages.count) queued messages", category: .chat)
            for msg in messages {
                sendJSON(msg)
            }
        }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    // Mark connected on first successful receive (handshake complete)
                    if self.connectionState != .connected {
                        self.connectionState = .connected
                        self.reconnectAttempts = 0
                        NavLog.info("WebSocket connected for match \(self.matchId)", category: .chat)
                        self.sendPresence(online: true)
                        self.flushPendingMessages()
                    }

                    if case .string(let text) = message {
                        self.handleMessage(text)
                    }
                    self.receiveLoop()
                case .failure(let error):
                    NavLog.warning("WebSocket receive failed: \(error.localizedDescription)", category: .chat)
                    self.connectionState = .disconnected
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            NavLog.debug("Received unparseable WebSocket message", category: .chat)
            return
        }

        // Handle presence events: { "type": "presence", "status": "online"|"offline", "last_seen": "ISO8601" }
        if type == "presence" {
            let status = json["status"] as? String ?? ""
            partnerIsOnline = (status == "online")
            if let lastSeenStr = json["last_seen"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                partnerLastSeen = formatter.date(from: lastSeenStr)
            }
            if !partnerIsOnline && partnerLastSeen == nil {
                partnerLastSeen = Date()
            }
            NavLog.debug("Partner presence: \(status)", category: .chat)
            return
        }

        let event = IncomingChatEvent(
            type: type,
            senderId: json["sender_id"] as? Int,
            content: json["content"] as? String,
            messageId: json["message_id"] as? Int,
            timestamp: json["timestamp"] as? String
        )

        // Bound the incoming messages array
        if incomingMessages.count >= maxStoredEvents {
            incomingMessages.removeFirst(incomingMessages.count - maxStoredEvents + 100)
        }
        incomingMessages.append(event)
    }

    private func startPing() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                webSocketTask?.sendPing { [weak self] error in
                    if let error {
                        Task { @MainActor [weak self] in
                            NavLog.debug("WebSocket ping failed: \(error.localizedDescription)", category: .chat)
                            guard let self, self.connectionState == .connected else { return }
                            self.connectionState = .disconnected
                            self.scheduleReconnect()
                        }
                    }
                }
            }
        }
    }

    private func scheduleReconnect() {
        guard !matchId.isEmpty, reconnectAttempts < maxReconnectAttempts else {
            if reconnectAttempts >= maxReconnectAttempts {
                NavLog.error("Max reconnect attempts (\(maxReconnectAttempts)) reached", category: .chat)
            }
            return
        }
        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts - 1)), 16.0)
        NavLog.info("Scheduling reconnect \(reconnectAttempts)/\(maxReconnectAttempts) in \(delay)s", category: .chat)

        Task {
            try? await Task.sleep(for: .seconds(delay))
            if self.connectionState != .connected {
                self.doConnect()
            }
        }
    }
}
