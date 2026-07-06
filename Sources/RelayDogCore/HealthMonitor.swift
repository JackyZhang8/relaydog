import Foundation

public struct UpstreamHealth: Equatable, Sendable {
    public var upstreamID: String
    public var proto: ProxyProtocol
    public var isReachable: Bool
    public var latencyMilliseconds: Int?
    public var lastError: String?
    public var checkedAt: Date

    public init(
        upstreamID: String,
        proto: ProxyProtocol,
        isReachable: Bool,
        latencyMilliseconds: Int?,
        lastError: String?,
        checkedAt: Date
    ) {
        self.upstreamID = upstreamID
        self.proto = proto
        self.isReachable = isReachable
        self.latencyMilliseconds = latencyMilliseconds
        self.lastError = lastError
        self.checkedAt = checkedAt
    }
}

public final class HealthState: @unchecked Sendable {
    private let lock = NSLock()
    private var records: [HealthKey: UpstreamHealth] = [:]

    public init() {}

    public func update(_ health: UpstreamHealth) {
        lock.lock()
        defer { lock.unlock() }
        records[HealthKey(upstreamID: health.upstreamID, proto: health.proto)] = health
    }

    public func health(upstreamID: String, proto: ProxyProtocol) -> UpstreamHealth? {
        lock.lock()
        defer { lock.unlock() }
        return records[HealthKey(upstreamID: upstreamID, proto: proto)]
    }

    public func isReachable(upstreamID: String, proto: ProxyProtocol) -> Bool? {
        health(upstreamID: upstreamID, proto: proto)?.isReachable
    }
}

public struct HealthMonitor: Sendable {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    public func check(upstream: UpstreamConfig, proto: ProxyProtocol, now: Date = Date()) async -> UpstreamHealth? {
        guard upstream.enabled, let capability = upstream.protocols[proto], capability.enabled else {
            return nil
        }

        let started = Date()

        do {
            let url = try healthCheckURL(baseURL: capability.baseURL, healthCheckPath: capability.healthCheckPath)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = TimeInterval(upstream.timeoutSeconds)
            applyHeaders(to: &request, proto: proto, capability: capability)

            let response = try await transport.data(for: request)
            let isReachable = (200..<400).contains(response.statusCode)
            return UpstreamHealth(
                upstreamID: upstream.id,
                proto: proto,
                isReachable: isReachable,
                latencyMilliseconds: elapsedMilliseconds(since: started),
                lastError: isReachable ? nil : "HTTP \(response.statusCode)",
                checkedAt: now
            )
        } catch {
            return UpstreamHealth(
                upstreamID: upstream.id,
                proto: proto,
                isReachable: false,
                latencyMilliseconds: nil,
                lastError: String(describing: error),
                checkedAt: now
            )
        }
    }

    private func healthCheckURL(baseURL: String, healthCheckPath: String) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }

        let basePath = stripTrailingSlash(components.path)
        let normalizedHealthCheckPath = stripLocalVersionPrefixIfNeeded(
            basePath: basePath,
            healthCheckPath: healthCheckPath
        )
        let checkPath = normalizedHealthCheckPath.hasPrefix("/") ? String(normalizedHealthCheckPath.dropFirst()) : normalizedHealthCheckPath
        components.path = basePath.isEmpty ? "/" + checkPath : basePath + "/" + checkPath

        guard let url = components.url else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }
        return url
    }

    private func applyHeaders(to request: inout URLRequest, proto: ProxyProtocol, capability: ProtocolCapabilityConfig) {
        switch proto {
        case .openAI:
            request.setValue("Bearer \(capability.apiKey)", forHTTPHeaderField: "Authorization")
        case .claude:
            request.setValue(capability.apiKey, forHTTPHeaderField: "x-api-key")
        }

        for (name, value) in capability.headerOverrides {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }

    private func elapsedMilliseconds(since started: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(started) * 1000))
    }

    private func stripTrailingSlash(_ value: String) -> String {
        guard value.count > 1, value.hasSuffix("/") else {
            return value
        }
        return String(value.dropLast())
    }

    private func stripLocalVersionPrefixIfNeeded(basePath: String, healthCheckPath: String) -> String {
        if basePath.hasSuffix("/v1"), healthCheckPath == "/v1" {
            return ""
        }

        if basePath.hasSuffix("/v1"), healthCheckPath.hasPrefix("/v1/") {
            return String(healthCheckPath.dropFirst("/v1".count))
        }

        return healthCheckPath
    }
}

private struct HealthKey: Hashable {
    var upstreamID: String
    var proto: ProxyProtocol
}
