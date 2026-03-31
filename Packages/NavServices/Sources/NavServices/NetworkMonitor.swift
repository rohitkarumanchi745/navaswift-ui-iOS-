import Foundation
import Network
import NavCore

/// Monitors network connectivity using NWPathMonitor.
/// Publishes connectivity state so views can show offline banners.
@MainActor
public class NetworkMonitor: ObservableObject {
    @Published public var isConnected = true
    @Published public var connectionType: ConnectionType = .unknown
    /// True when the connection is metered (e.g. cellular or personal hotspot).
    @Published public var isExpensive = false

    public enum ConnectionType: String {
        case wifi, cellular, wired, unknown
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.nava.networkmonitor")

    public init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive

                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wired
                } else {
                    self.connectionType = .unknown
                }

                if wasConnected && !self.isConnected {
                    NavLog.warning("Network connectivity lost", category: .network)
                } else if !wasConnected && self.isConnected {
                    NavLog.info("Network connectivity restored (\(self.connectionType.rawValue))", category: .network)
                }
            }
        }
        monitor.start(queue: queue)
    }
}
