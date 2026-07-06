import Foundation

public struct UpstreamDebugResult: Equatable, Sendable {
    public var requestText: String
    public var responseText: String

    public init(requestText: String, responseText: String) {
        self.requestText = requestText
        self.responseText = responseText
    }
}

public struct UpstreamDebugClient: Sendable {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    public func sendTestPrompt(
        upstream: UpstreamConfig,
        protocol proto: ProxyProtocol,
        model: String,
        prompt: String
    ) async throws -> UpstreamDebugResult {
        guard upstream.enabled, let capability = upstream.protocols[proto], capability.enabled else {
            throw ModelManagerError.protocolUnavailable(upstream.id, proto)
        }

        var request = URLRequest(url: try debugURL(baseURL: capability.baseURL, proto: proto))
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(upstream.timeoutSeconds)
        request.httpBody = try requestBody(proto: proto, model: model, prompt: prompt)
        applyHeaders(to: &request, proto: proto, capability: capability)

        let response = try await transport.data(for: request)
        return UpstreamDebugResult(
            requestText: renderRequest(request),
            responseText: renderResponse(response)
        )
    }

    private func debugURL(baseURL: String, proto: ProxyProtocol) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }

        let basePath = stripTrailingSlash(components.path)
        let endpoint: String
        switch proto {
        case .openAI:
            endpoint = "/chat/completions"
        case .claude:
            endpoint = "/messages"
        }

        components.path = basePath.hasSuffix("/v1") ? basePath + endpoint : basePath + "/v1" + endpoint

        guard let url = components.url else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }
        return url
    }

    private func requestBody(proto: ProxyProtocol, model: String, prompt: String) throws -> Data {
        let body: [String: Any]
        switch proto {
        case .openAI:
            body = [
                "model": model,
                "stream": false,
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ]
        case .claude:
            body = [
                "model": model,
                "max_tokens": 256,
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ]
        }

        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    private func applyHeaders(to request: inout URLRequest, proto: ProxyProtocol, capability: ProtocolCapabilityConfig) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch proto {
        case .openAI:
            request.setValue("Bearer \(capability.apiKey)", forHTTPHeaderField: "Authorization")
        case .claude:
            request.setValue(capability.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        for (name, value) in capability.headerOverrides {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }

    private func renderRequest(_ request: URLRequest) -> String {
        var lines: [String] = []
        lines.append("\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")

        for (name, value) in sortedHeaders(request.allHTTPHeaderFields ?? [:]) {
            lines.append("\(name): \(value)")
        }

        lines.append("")
        if let body = request.httpBody {
            lines.append(prettyBody(body))
        }
        return lines.joined(separator: "\n")
    }

    private func renderResponse(_ response: HTTPTransportResponse) -> String {
        var lines: [String] = ["HTTP \(response.statusCode)"]

        for (name, value) in sortedHeaders(response.headers) {
            lines.append("\(name): \(value)")
        }

        lines.append("")
        lines.append(prettyBody(response.body))
        return lines.joined(separator: "\n")
    }

    private func prettyBody(_ data: Data) -> String {
        guard !data.isEmpty else {
            return ""
        }

        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
            return String(decoding: pretty, as: UTF8.self)
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func sortedHeaders(_ headers: [String: String]) -> [(String, String)] {
        headers.sorted { lhs, rhs in lhs.key.lowercased() < rhs.key.lowercased() }
    }

    private func stripTrailingSlash(_ value: String) -> String {
        guard value.count > 1, value.hasSuffix("/") else {
            return value
        }
        return String(value.dropLast())
    }
}
