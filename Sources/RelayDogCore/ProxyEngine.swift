import Foundation

public struct ProxyEngine: Sendable {
    public var config: RelayDogConfig
    public var upstreamClient: any UpstreamClient
    public var eventLogger: (any ProxyEventLogging)?
    public var routingState: RoutingState
    public var healthState: HealthState
    public var statisticsStore: StatisticsStore?

    public init(
        config: RelayDogConfig,
        upstreamClient: any UpstreamClient,
        eventLogger: (any ProxyEventLogging)? = nil,
        routingState: RoutingState = RoutingState(),
        healthState: HealthState = HealthState(),
        statisticsStore: StatisticsStore? = nil
    ) {
        self.config = config
        self.upstreamClient = upstreamClient
        self.eventLogger = eventLogger
        self.routingState = routingState
        self.healthState = healthState
        self.statisticsStore = statisticsStore
    }

    public func handle(_ request: ProxyHTTPRequest) async throws -> ProxyHTTPResponse {
        let detection = ProtocolDetector.detect(path: request.path, headers: request.headers)

        guard let proto = detection.protocol else {
            return errorResponse(statusCode: 400, message: detection.reason)
        }

        let selected: SelectedUpstream
        do {
            selected = try routingState.select(protocol: proto, from: config, health: healthState)
        } catch let error as UpstreamSelectionError {
            return errorResponse(statusCode: 503, message: error.errorDescription ?? "No enabled upstream")
        }

        let started = Date()
        let forwarded = try buildForwardedRequest(
            localRequest: request,
            proto: proto,
            selected: selected
        )

        do {
            let response = try await upstreamClient.send(forwarded)
            recordStatistic(proto: proto, upstreamID: forwarded.upstreamID, response: response, started: started, error: nil)
            await recordEvent(
                localRequest: request,
                forwarded: forwarded,
                proto: proto,
                response: response,
                started: started,
                error: nil
            )
            return response
        } catch {
            recordStatistic(proto: proto, upstreamID: forwarded.upstreamID, response: nil, started: started, error: error)
            await recordEvent(
                localRequest: request,
                forwarded: forwarded,
                proto: proto,
                response: nil,
                started: started,
                error: String(describing: error)
            )
            throw error
        }
    }

    private func buildForwardedRequest(
        localRequest: ProxyHTTPRequest,
        proto: ProxyProtocol,
        selected: SelectedUpstream
    ) throws -> ForwardedHTTPRequest {
        let modelRewrite: ModelRewriteResult?
        let body: Data

        if proto == .openAI {
            let mappings = effectiveMappings(proto: proto, capability: selected.capability)
            let rewrite = try ModelMapper.rewriteRequestBody(localRequest.body, mappings: mappings)
            modelRewrite = rewrite.originalModel == nil && rewrite.mappedModel == nil ? nil : rewrite
            body = rewrite.body
        } else {
            modelRewrite = nil
            body = localRequest.body
        }

        return ForwardedHTTPRequest(
            protocol: proto,
            upstreamID: selected.upstream.id,
            method: localRequest.method,
            url: try buildUpstreamURL(baseURL: selected.capability.baseURL, requestPath: localRequest.path),
            headers: buildHeaders(from: localRequest.headers, proto: proto, capability: selected.capability),
            body: body,
            timeoutSeconds: selected.upstream.timeoutSeconds,
            modelRewrite: modelRewrite
        )
    }

    private func effectiveMappings(proto: ProxyProtocol, capability: ProtocolCapabilityConfig) -> [String: String] {
        capability.modelMappings
    }

    private func buildHeaders(
        from originalHeaders: [String: String],
        proto: ProxyProtocol,
        capability: ProtocolCapabilityConfig
    ) -> [String: String] {
        var headers = originalHeaders.filter { key, _ in
            let lowercased = key.lowercased()
            return lowercased != "host" && lowercased != "content-length"
        }

        switch proto {
        case .openAI:
            setHeader("Authorization", value: "Bearer \(capability.apiKey)", in: &headers)
        case .claude:
            setHeader("x-api-key", value: capability.apiKey, in: &headers)
        }

        for (key, value) in capability.headerOverrides {
            setHeader(key, value: value, in: &headers)
        }

        return headers
    }

    private func setHeader(_ name: String, value: String, in headers: inout [String: String]) {
        let lowercased = name.lowercased()
        for key in Array(headers.keys) where key.lowercased() == lowercased {
            headers.removeValue(forKey: key)
        }
        headers[name] = value
    }

    private func buildUpstreamURL(baseURL: String, requestPath: String) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }

        let split = splitPathAndQuery(requestPath)
        let basePath = stripTrailingSlash(components.path)
        let pathToAppend = stripLocalVersionPrefixIfNeeded(basePath: basePath, requestPath: split.path)
        components.path = joinPath(basePath, pathToAppend)
        components.percentEncodedQuery = split.query

        guard let url = components.url else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }
        return url
    }

    private func splitPathAndQuery(_ path: String) -> (path: String, query: String?) {
        guard let question = path.firstIndex(of: "?") else {
            return (path, nil)
        }
        return (String(path[..<question]), String(path[path.index(after: question)...]))
    }

    private func stripLocalVersionPrefixIfNeeded(basePath: String, requestPath: String) -> String {
        if basePath.hasSuffix("/v1"), requestPath == "/v1" {
            return ""
        }

        if basePath.hasSuffix("/v1"), requestPath.hasPrefix("/v1/") {
            return String(requestPath.dropFirst("/v1".count))
        }

        return requestPath
    }

    private func joinPath(_ basePath: String, _ requestPath: String) -> String {
        let trimmedBase = stripTrailingSlash(basePath)
        let trimmedRequest = requestPath.hasPrefix("/") ? String(requestPath.dropFirst()) : requestPath

        if trimmedBase.isEmpty {
            return "/" + trimmedRequest
        }

        if trimmedRequest.isEmpty {
            return trimmedBase
        }

        return trimmedBase + "/" + trimmedRequest
    }

    private func stripTrailingSlash(_ value: String) -> String {
        guard value.count > 1, value.hasSuffix("/") else {
            return value
        }
        return String(value.dropLast())
    }

    private func errorResponse(statusCode: Int, message: String) -> ProxyHTTPResponse {
        let body = (try? JSONSerialization.data(withJSONObject: ["error": message], options: [.sortedKeys])) ?? Data()
        return ProxyHTTPResponse(
            statusCode: statusCode,
            headers: ["content-type": "application/json"],
            body: body
        )
    }

    private func recordEvent(
        localRequest: ProxyHTTPRequest,
        forwarded: ForwardedHTTPRequest,
        proto: ProxyProtocol,
        response: ProxyHTTPResponse?,
        started: Date,
        error: String?
    ) async {
        guard let eventLogger else {
            return
        }

        let event = ProxyEvent(
            id: UUID().uuidString,
            timestamp: started,
            proto: proto,
            method: localRequest.method,
            path: localRequest.path,
            upstreamID: forwarded.upstreamID,
            upstreamURL: forwarded.url.absoluteString,
            requestHeaders: forwarded.headers,
            requestBody: String(decoding: forwarded.body, as: UTF8.self),
            originalModel: forwarded.modelRewrite?.originalModel,
            mappedModel: forwarded.modelRewrite?.mappedModel,
            responseStatus: response?.statusCode,
            responseHeaders: response?.headers ?? [:],
            responseBody: response.map { String(decoding: $0.body, as: UTF8.self) },
            durationMilliseconds: max(0, Int(Date().timeIntervalSince(started) * 1000)),
            error: error
        )

        await eventLogger.record(event)
    }

    private func recordStatistic(
        proto: ProxyProtocol,
        upstreamID: String,
        response: ProxyHTTPResponse?,
        started: Date,
        error: Error?
    ) {
        guard let statisticsStore else {
            return
        }

        statisticsStore.record(.init(
            proto: proto,
            upstreamID: upstreamID,
            succeeded: error == nil && (response?.statusCode ?? 599) < 500,
            durationMilliseconds: max(0, Int(Date().timeIntervalSince(started) * 1000))
        ))
    }
}

public enum ProxyEngineError: Error, Equatable {
    case invalidBaseURL(String)
}
