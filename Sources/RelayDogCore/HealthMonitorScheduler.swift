import Foundation

public final class HealthMonitorScheduler: @unchecked Sendable {
    private let monitor: HealthMonitor
    private let healthState: HealthState
    private let intervalSeconds: Int
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    public init(
        monitor: HealthMonitor = HealthMonitor(transport: URLSessionHTTPTransport()),
        healthState: HealthState,
        intervalSeconds: Int = 60
    ) {
        self.monitor = monitor
        self.healthState = healthState
        self.intervalSeconds = max(1, intervalSeconds)
    }

    public func start(config: RelayDogConfig) {
        stop()

        let task = Task { [monitor, healthState, intervalSeconds] in
            while !Task.isCancelled {
                await Self.checkAll(config: config, monitor: monitor, healthState: healthState)
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
            }
        }

        lock.lock()
        self.task = task
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        let task = self.task
        self.task = nil
        lock.unlock()
        task?.cancel()
    }

    public static func checkAll(config: RelayDogConfig, monitor: HealthMonitor, healthState: HealthState) async {
        for upstream in config.upstreams where upstream.enabled {
            for proto in ProxyProtocol.allCases {
                if Task.isCancelled {
                    return
                }
                if let health = await monitor.check(upstream: upstream, proto: proto) {
                    healthState.update(health)
                }
            }
        }
    }
}
