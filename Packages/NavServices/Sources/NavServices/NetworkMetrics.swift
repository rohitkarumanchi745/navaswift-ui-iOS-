import Foundation
import NavCore
import NavNetworking

// MARK: - Request Metric

/// A single recorded API request metric.
public struct RequestMetric: Sendable {
    public let endpoint: String
    public let method: String
    public let statusCode: Int?
    public let latencyMs: Double
    public let errorMessage: String?
    public let timestamp: Date

    public init(endpoint: String, method: String, statusCode: Int?, latencyMs: Double, errorMessage: String?, timestamp: Date) {
        self.endpoint = endpoint
        self.method = method
        self.statusCode = statusCode
        self.latencyMs = latencyMs
        self.errorMessage = errorMessage
        self.timestamp = timestamp
    }

    public var isError: Bool {
        if errorMessage != nil { return true }
        guard let code = statusCode else { return true }
        return code >= 400
    }
}

// MARK: - Network Metrics

/// Collects request latency, error rates, and throughput metrics for mobile observability.
/// Thread-safe singleton that accumulates metrics and provides summary snapshots.
@MainActor
public class NetworkMetrics: ObservableObject {
    public static let shared = NetworkMetrics()

    /// Rolling window of recent request metrics (bounded to prevent memory growth).
    @Published public private(set) var recentMetrics: [RequestMetric] = []

    /// Summary stats updated after each request.
    @Published public private(set) var totalRequests: Int = 0
    @Published public private(set) var totalErrors: Int = 0
    @Published public private(set) var averageLatencyMs: Double = 0

    private let maxMetrics = 200
    private var latencySum: Double = 0
    private var consecutiveFlushFailures: Int = 0
    private let maxFlushBackoffSeconds: TimeInterval = 3600 // Cap at 1 hour
    /// After this many consecutive flush failures, the circuit opens and flushes pause
    /// until `resetCircuitBreaker()` is called (e.g. when network connectivity is restored).
    private let circuitBreakerThreshold = 5
    private var circuitOpen = false

    private init() {}

    // MARK: - Recording

    /// Records a completed request metric.
    public func record(_ metric: RequestMetric) {
        recentMetrics.append(metric)
        if recentMetrics.count > maxMetrics {
            let removed = recentMetrics.removeFirst()
            latencySum -= removed.latencyMs
        }

        totalRequests += 1
        latencySum += metric.latencyMs
        averageLatencyMs = latencySum / Double(recentMetrics.count)

        if metric.isError {
            totalErrors += 1
        }

        NavLog.debug(
            "Metric: \(metric.method) \(metric.endpoint) → \(metric.statusCode ?? 0) in \(Int(metric.latencyMs))ms",
            category: .network
        )
    }

    /// Convenience to record a successful request.
    public func recordSuccess(endpoint: String, method: String, statusCode: Int, latencyMs: Double) {
        record(RequestMetric(
            endpoint: endpoint,
            method: method,
            statusCode: statusCode,
            latencyMs: latencyMs,
            errorMessage: nil,
            timestamp: Date()
        ))
    }

    /// Convenience to record a failed request.
    public func recordError(endpoint: String, method: String, statusCode: Int?, latencyMs: Double, error: String) {
        record(RequestMetric(
            endpoint: endpoint,
            method: method,
            statusCode: statusCode,
            latencyMs: latencyMs,
            errorMessage: error,
            timestamp: Date()
        ))
    }

    // MARK: - Summary

    /// Error rate as a percentage (0–100) over the rolling window.
    public var errorRatePercent: Double {
        guard !recentMetrics.isEmpty else { return 0 }
        let errors = recentMetrics.filter(\.isError).count
        return Double(errors) / Double(recentMetrics.count) * 100
    }

    /// p95 latency over the rolling window.
    public var p95LatencyMs: Double {
        guard !recentMetrics.isEmpty else { return 0 }
        let sorted = recentMetrics.map(\.latencyMs).sorted()
        let index = min(Int(Double(sorted.count) * 0.95), sorted.count - 1)
        return sorted[index]
    }

    /// Returns a snapshot dictionary suitable for sending to an observability backend.
    public var snapshot: [String: Any] {
        [
            "total_requests": totalRequests,
            "total_errors": totalErrors,
            "avg_latency_ms": Int(averageLatencyMs),
            "p95_latency_ms": Int(p95LatencyMs),
            "error_rate_percent": String(format: "%.1f", errorRatePercent),
            "window_size": recentMetrics.count,
        ]
    }

    /// Resets all accumulated metrics.
    public func reset() {
        recentMetrics.removeAll()
        totalRequests = 0
        totalErrors = 0
        averageLatencyMs = 0
        latencySum = 0
    }

    // MARK: - Telemetry Flush

    private var flushTask: Task<Void, Never>?

    /// Starts a periodic flush of metrics to the backend telemetry endpoint.
    /// Sends snapshots every `intervalSeconds` while the app is active.
    /// Uses exponential backoff when the server is unavailable.
    public func startPeriodicFlush(intervalSeconds: TimeInterval = 300) {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                let failures = await self?.consecutiveFlushFailures ?? 0
                let backoff = min(
                    intervalSeconds * pow(2.0, Double(failures)),
                    await self?.maxFlushBackoffSeconds ?? 3600
                )
                let delay = max(intervalSeconds, backoff)

                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }
                await self?.flushToBackend()
            }
        }
    }

    /// Stops the periodic flush loop.
    public func stopPeriodicFlush() {
        flushTask?.cancel()
        flushTask = nil
    }

    /// Sends the current snapshot to the backend telemetry endpoint.
    /// Tracks consecutive failures for exponential backoff in the flush loop.
    /// Opens a circuit breaker after `circuitBreakerThreshold` consecutive failures.
    public func flushToBackend() async {
        guard totalRequests > 0 else { return }
        guard !circuitOpen else {
            NavLog.debug("Telemetry circuit breaker open — skipping flush", category: .network)
            return
        }

        let payload = snapshot
        NavLog.debug("Flushing metrics to backend (failures: \(consecutiveFlushFailures)): \(payload)", category: .network)

        struct TelemetryResponse: Decodable {
            let success: Bool?
        }

        do {
            let _: TelemetryResponse = try await APIService.shared.post(
                path: "/api/telemetry/client-metrics",
                body: [
                    "platform": "ios",
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                    "device_model": deviceModel(),
                    "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
                    "metrics": payload,
                ]
            )
            consecutiveFlushFailures = 0
            NavLog.info("Metrics flushed to backend successfully", category: .network)
        } catch {
            consecutiveFlushFailures += 1
            if consecutiveFlushFailures >= circuitBreakerThreshold {
                circuitOpen = true
                NavLog.warning(
                    "Telemetry circuit breaker opened after \(consecutiveFlushFailures) consecutive failures — pausing flushes until connectivity changes",
                    category: .network
                )
            } else {
                let nextBackoff = min(300.0 * pow(2.0, Double(consecutiveFlushFailures)), maxFlushBackoffSeconds)
                NavLog.debug(
                    "Metrics flush failed (\(consecutiveFlushFailures) consecutive, next in \(Int(nextBackoff))s): \(error.localizedDescription)",
                    category: .network
                )
            }
        }
    }

    /// Resets the circuit breaker so flushes resume. Call when network connectivity is restored.
    public func resetCircuitBreaker() {
        guard circuitOpen else { return }
        circuitOpen = false
        consecutiveFlushFailures = 0
        NavLog.info("Telemetry circuit breaker reset — flushes will resume", category: .network)
    }

    private nonisolated func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }
}
