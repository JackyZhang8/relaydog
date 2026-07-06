import Foundation

public struct ProtocolDetection: Equatable, Sendable {
    public let `protocol`: ProxyProtocol?
    public let reason: String

    public init(protocol proto: ProxyProtocol?, reason: String) {
        self.protocol = proto
        self.reason = reason
    }
}

public enum ProtocolDetector {
    private static let openAIPaths = [
        "/v1/chat/completions",
        "/v1/responses",
        "/v1/completions",
        "/v1/embeddings",
        "/v1/images",
        "/v1/audio",
        "/v1/models"
    ]

    private static let claudePaths = [
        "/v1/messages",
        "/v1/complete"
    ]

    public static func detect(path: String, headers: [String: String]) -> ProtocolDetection {
        let normalizedPath = normalizePath(path)

        if openAIPaths.contains(where: { normalizedPath == $0 || normalizedPath.hasPrefix($0 + "/") }) {
            return ProtocolDetection(protocol: .openAI, reason: "Matched OpenAI path \(normalizedPath)")
        }

        if claudePaths.contains(where: { normalizedPath == $0 || normalizedPath.hasPrefix($0 + "/") }) {
            return ProtocolDetection(protocol: .claude, reason: "Matched Claude path \(normalizedPath)")
        }

        let normalizedHeaders = Dictionary(uniqueKeysWithValues: headers.map { key, value in
            (key.lowercased(), value)
        })

        if normalizedHeaders["anthropic-version"] != nil || normalizedHeaders["anthropic-beta"] != nil {
            return ProtocolDetection(protocol: .claude, reason: "Matched Claude header")
        }

        if normalizedHeaders["x-api-key"] != nil && normalizedHeaders["authorization"] == nil {
            return ProtocolDetection(protocol: .claude, reason: "Matched Claude API key header")
        }

        if normalizedHeaders["authorization"]?.lowercased().hasPrefix("bearer ") == true {
            return ProtocolDetection(protocol: .openAI, reason: "Matched OpenAI authorization header")
        }

        return ProtocolDetection(protocol: nil, reason: "Unable to identify protocol for \(normalizedPath)")
    }

    private static func normalizePath(_ path: String) -> String {
        guard let question = path.firstIndex(of: "?") else {
            return path
        }
        return String(path[..<question])
    }
}
