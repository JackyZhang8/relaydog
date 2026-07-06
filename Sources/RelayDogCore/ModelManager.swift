import Foundation

public struct ModelMappingValidationIssue: Equatable, Sendable {
    public var clientModel: String
    public var targetModel: String

    public init(clientModel: String, targetModel: String) {
        self.clientModel = clientModel
        self.targetModel = targetModel
    }
}

public enum ModelManagerError: Error, Equatable, LocalizedError, Sendable {
    case protocolUnavailable(String, ProxyProtocol)
    case invalidModelListResponse
    case upstreamRejected(Int)

    public var errorDescription: String? {
        switch self {
        case .protocolUnavailable(let upstreamID, let proto):
            return "Upstream \(upstreamID) does not have enabled \(proto.rawValue) model sync"
        case .invalidModelListResponse:
            return "Unable to parse upstream model list"
        case .upstreamRejected(let statusCode):
            return "Upstream model list request failed with HTTP \(statusCode)"
        }
    }
}

public struct ModelManager: Sendable {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    public func resolveModels(upstream: UpstreamConfig, protocol proto: ProxyProtocol) async throws -> [String] {
        guard upstream.enabled, let capability = upstream.protocols[proto], capability.enabled else {
            throw ModelManagerError.protocolUnavailable(upstream.id, proto)
        }

        switch capability.modelSync {
        case .manual:
            return capability.models
        case .remote:
            return try await syncModels(upstream: upstream, protocol: proto, capability: capability)
        }
    }

    public static func parseModelIDs(from data: Data) throws -> [String] {
        let object = try JSONSerialization.jsonObject(with: data)

        if let dictionary = object as? [String: Any] {
            if let data = dictionary["data"] as? [Any] {
                return uniqueModelIDs(from: data)
            }

            if let models = dictionary["models"] as? [Any] {
                return uniqueModelIDs(from: models)
            }
        }

        if let array = object as? [Any] {
            return uniqueModelIDs(from: array)
        }

        throw ModelManagerError.invalidModelListResponse
    }

    public static func validateMappings(
        upstreamID: String,
        protocol proto: ProxyProtocol,
        in config: RelayDogConfig
    ) -> [ModelMappingValidationIssue] {
        guard let upstream = config.upstreams.first(where: { $0.id == upstreamID }),
              let capability = upstream.protocols[proto],
              !capability.models.isEmpty else {
            return []
        }

        let modelSet = Set(capability.models)
        let mappings = effectiveMappings(proto: proto, capability: capability, config: config)

        return mappings
            .filter { _, targetModel in !modelSet.contains(targetModel) }
            .map { clientModel, targetModel in
                ModelMappingValidationIssue(clientModel: clientModel, targetModel: targetModel)
            }
            .sorted { lhs, rhs in
                if lhs.clientModel == rhs.clientModel {
                    return lhs.targetModel < rhs.targetModel
                }
                return lhs.clientModel < rhs.clientModel
            }
    }

    private func syncModels(
        upstream: UpstreamConfig,
        protocol proto: ProxyProtocol,
        capability: ProtocolCapabilityConfig
    ) async throws -> [String] {
        var request = URLRequest(url: try modelListURL(baseURL: capability.baseURL))
        request.httpMethod = "GET"
        request.timeoutInterval = TimeInterval(upstream.timeoutSeconds)
        applyHeaders(to: &request, proto: proto, capability: capability)

        let response = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ModelManagerError.upstreamRejected(response.statusCode)
        }

        return try Self.parseModelIDs(from: response.body)
    }

    private func modelListURL(baseURL: String) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }

        let basePath = stripTrailingSlash(components.path)
        components.path = basePath.hasSuffix("/v1") ? basePath + "/models" : basePath + "/v1/models"

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

    private func stripTrailingSlash(_ value: String) -> String {
        guard value.count > 1, value.hasSuffix("/") else {
            return value
        }
        return String(value.dropLast())
    }

    private static func effectiveMappings(
        proto: ProxyProtocol,
        capability: ProtocolCapabilityConfig,
        config: RelayDogConfig
    ) -> [String: String] {
        capability.modelMappings
    }

    private static func uniqueModelIDs(from values: [Any]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values {
            guard let modelID = modelID(from: value), !seen.contains(modelID) else {
                continue
            }
            seen.insert(modelID)
            result.append(modelID)
        }

        return result
    }

    private static func modelID(from value: Any) -> String? {
        if let string = value as? String {
            return string
        }

        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        return dictionary["id"] as? String ?? dictionary["name"] as? String
    }
}
