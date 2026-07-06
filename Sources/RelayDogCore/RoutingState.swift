import Foundation

public final class RoutingState: @unchecked Sendable {
    private let lock = NSLock()
    private var roundRobinIndexes: [ProxyProtocol: Int] = [:]

    public init() {}

    public func select(
        protocol proto: ProxyProtocol,
        from config: RelayDogConfig,
        health: HealthState = HealthState()
    ) throws -> SelectedUpstream {
        let candidates = enabledCandidates(for: proto, in: config)

        guard !candidates.isEmpty else {
            throw UpstreamSelectionError.noEnabledUpstream(proto)
        }

        let routing = config.routing[proto] ?? RoutingConfig(mode: .single, selectedUpstreamID: nil)

        switch routing.mode {
        case .single:
            return try selectSingle(routing: routing, proto: proto, candidates: candidates)
        case .roundRobin:
            return nextRoundRobin(protocol: proto, candidates: reachableCandidates(candidates, proto: proto, health: health))
        case .weightedRoundRobin:
            return nextRoundRobin(protocol: proto, candidates: weightedCandidates(reachableCandidates(candidates, proto: proto, health: health)))
        case .failover:
            return firstReachable(candidates, proto: proto, health: health)
        case .lowestLatency:
            return lowestLatency(candidates, proto: proto, health: health)
        }
    }

    private func selectSingle(
        routing: RoutingConfig,
        proto: ProxyProtocol,
        candidates: [SelectedUpstream]
    ) throws -> SelectedUpstream {
        guard let selectedID = routing.selectedUpstreamID else {
            return candidates[0]
        }

        guard let selected = candidates.first(where: { $0.upstream.id == selectedID }) else {
            throw UpstreamSelectionError.selectedUpstreamUnavailable(selectedID, proto)
        }

        return selected
    }

    private func nextRoundRobin(protocol proto: ProxyProtocol, candidates: [SelectedUpstream]) -> SelectedUpstream {
        lock.lock()
        defer { lock.unlock() }

        let index = roundRobinIndexes[proto, default: 0]
        let selected = candidates[index % candidates.count]
        roundRobinIndexes[proto] = (index + 1) % candidates.count
        return selected
    }

    private func firstReachable(
        _ candidates: [SelectedUpstream],
        proto: ProxyProtocol,
        health: HealthState
    ) -> SelectedUpstream {
        candidates.first { health.isReachable(upstreamID: $0.upstream.id, proto: proto) != false } ?? candidates[0]
    }

    private func lowestLatency(
        _ candidates: [SelectedUpstream],
        proto: ProxyProtocol,
        health: HealthState
    ) -> SelectedUpstream {
        let measured = candidates.compactMap { candidate -> (SelectedUpstream, Int)? in
            guard let upstreamHealth = health.health(upstreamID: candidate.upstream.id, proto: proto),
                  upstreamHealth.isReachable,
                  let latency = upstreamHealth.latencyMilliseconds else {
                return nil
            }
            return (candidate, latency)
        }

        if let fastest = measured.min(by: { $0.1 < $1.1 }) {
            return fastest.0
        }

        return firstReachable(candidates, proto: proto, health: health)
    }

    private func reachableCandidates(
        _ candidates: [SelectedUpstream],
        proto: ProxyProtocol,
        health: HealthState
    ) -> [SelectedUpstream] {
        let reachable = candidates.filter { health.isReachable(upstreamID: $0.upstream.id, proto: proto) != false }
        return reachable.isEmpty ? candidates : reachable
    }

    private func weightedCandidates(_ candidates: [SelectedUpstream]) -> [SelectedUpstream] {
        candidates.flatMap { candidate in
            Array(repeating: candidate, count: max(1, candidate.upstream.weight))
        }
    }

    private func enabledCandidates(for proto: ProxyProtocol, in config: RelayDogConfig) -> [SelectedUpstream] {
        UpstreamSelector.enabledCandidates(for: proto, in: config)
    }
}
