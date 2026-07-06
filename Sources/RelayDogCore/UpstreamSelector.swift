import Foundation

public struct SelectedUpstream: Equatable, Sendable {
    public var upstream: UpstreamConfig
    public var capability: ProtocolCapabilityConfig

    public init(upstream: UpstreamConfig, capability: ProtocolCapabilityConfig) {
        self.upstream = upstream
        self.capability = capability
    }
}

public enum UpstreamSelectionError: Error, Equatable, LocalizedError, Sendable {
    case noEnabledUpstream(ProxyProtocol)
    case selectedUpstreamUnavailable(String, ProxyProtocol)

    public var errorDescription: String? {
        switch self {
        case .noEnabledUpstream(let proto):
            return "No enabled upstream for \(proto.rawValue)"
        case .selectedUpstreamUnavailable(let upstreamID, let proto):
            return "Selected upstream \(upstreamID) is unavailable for \(proto.rawValue)"
        }
    }
}

public enum UpstreamSelector {
    public static func select(protocol proto: ProxyProtocol, from config: RelayDogConfig) throws -> SelectedUpstream {
        let routing = config.routing[proto]
        let candidates = enabledCandidates(for: proto, in: config)

        guard !candidates.isEmpty else {
            throw UpstreamSelectionError.noEnabledUpstream(proto)
        }

        if routing?.mode == .single, let selectedID = routing?.selectedUpstreamID {
            guard let selected = candidates.first(where: { $0.upstream.id == selectedID }) else {
                throw UpstreamSelectionError.selectedUpstreamUnavailable(selectedID, proto)
            }
            return selected
        }

        return candidates[0]
    }

    private static func enabledCandidates(for proto: ProxyProtocol, in config: RelayDogConfig) -> [SelectedUpstream] {
        config.upstreams.compactMap { upstream in
            guard upstream.enabled, let capability = upstream.protocols[proto], capability.enabled else {
                return nil
            }
            return SelectedUpstream(upstream: upstream, capability: capability)
        }
    }
}
