import Foundation

public struct ProxyEngine: Sendable {
    public var config: RelayDogConfig
    public var upstreamClient: any UpstreamClient
    public var eventLogger: (any ProxyEventLogging)?
    public var routingState: RoutingState
    public var healthState: HealthState
    public var statisticsStore: StatisticsStore?

    static let maxLoggedResponseBodyBytes = 10 * 1024 * 1024

    private static let strippedForwardedHeaders: Set<String> = [
        "host",
        "content-length",
        "transfer-encoding",
        "accept-encoding",
        "connection",
        "keep-alive",
        "proxy-authorization",
        "te",
        "trailer",
        "upgrade"
    ]

    private static let redactedHeaderNames: Set<String> = [
        "authorization",
        "proxy-authorization",
        "x-api-key",
        "cookie",
        "set-cookie"
    ]

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
        if isStatusRequest(request) {
            return statusResponse()
        }

        switch prepareForwarding(request) {
        case .respond(let response):
            return response
        case .forward(let context):
            let started = Date()
            do {
                let response = try await upstreamClient.send(context.forwarded)
                recordStatistic(proto: context.proto, upstreamID: context.forwarded.upstreamID, response: response, started: started, error: nil)
                await recordEvent(localRequest: request, forwarded: context.forwarded, proto: context.proto, response: response, started: started, error: nil)
                return response
            } catch {
                recordStatistic(proto: context.proto, upstreamID: context.forwarded.upstreamID, response: nil, started: started, error: error)
                await recordEvent(localRequest: request, forwarded: context.forwarded, proto: context.proto, response: nil, started: started, error: String(describing: error))
                return errorResponse(statusCode: 502, message: "Upstream request failed: \(String(describing: error))")
            }
        }
    }

    public func handleStream(_ request: ProxyHTTPRequest, write: @Sendable (Data) async -> Void) async {
        if isStatusRequest(request) {
            await write(HTTPMessageCodec.encodeResponse(statusResponse()))
            return
        }

        let context: ForwardingContext
        switch prepareForwarding(request) {
        case .respond(let response):
            await write(HTTPMessageCodec.encodeResponse(response))
            return
        case .forward(let prepared):
            context = prepared
        }

        let started = Date()
        let streaming: UpstreamStreamingResponse
        do {
            streaming = try await upstreamClient.stream(context.forwarded)
        } catch {
            recordStatistic(proto: context.proto, upstreamID: context.forwarded.upstreamID, response: nil, started: started, error: error)
            await recordEvent(localRequest: request, forwarded: context.forwarded, proto: context.proto, response: nil, started: started, error: String(describing: error))
            await write(HTTPMessageCodec.encodeResponse(errorResponse(statusCode: 502, message: "Upstream request failed: \(String(describing: error))")))
            return
        }

        await write(HTTPMessageCodec.encodeResponseHead(statusCode: streaming.statusCode, headers: streaming.headers))

        var collectedBody = Data()
        var streamError: String?
        do {
            for try await chunk in streaming.body {
                await write(chunk)
                if collectedBody.count < Self.maxLoggedResponseBodyBytes {
                    collectedBody.append(chunk)
                }
            }
        } catch {
            streamError = String(describing: error)
        }

        let response = ProxyHTTPResponse(statusCode: streaming.statusCode, headers: streaming.headers, body: collectedBody)
        recordStatistic(
            proto: context.proto,
            upstreamID: context.forwarded.upstreamID,
            response: streamError == nil ? response : nil,
            started: started,
            error: streamError.map { _ in URLError(.networkConnectionLost) }
        )
        await recordEvent(
            localRequest: request,
            forwarded: context.forwarded,
            proto: context.proto,
            response: response,
            started: started,
            error: streamError
        )
    }

    private struct ForwardingContext {
        var proto: ProxyProtocol
        var forwarded: ForwardedHTTPRequest
    }

    private enum ForwardingPreparation {
        case forward(ForwardingContext)
        case respond(ProxyHTTPResponse)
    }

    private func prepareForwarding(_ request: ProxyHTTPRequest) -> ForwardingPreparation {
        let detection = ProtocolDetector.detect(path: request.path, headers: request.headers)

        guard let proto = detection.protocol else {
            return .respond(errorResponse(statusCode: 400, message: detection.reason))
        }

        let selected: SelectedUpstream
        do {
            selected = try routingState.select(protocol: proto, from: config, health: healthState)
        } catch let error as UpstreamSelectionError {
            return .respond(errorResponse(statusCode: 503, message: error.errorDescription ?? "No enabled upstream"))
        } catch {
            return .respond(errorResponse(statusCode: 503, message: String(describing: error)))
        }

        do {
            let forwarded = try buildForwardedRequest(localRequest: request, proto: proto, selected: selected)
            return .forward(ForwardingContext(proto: proto, forwarded: forwarded))
        } catch {
            return .respond(errorResponse(statusCode: 502, message: String(describing: error)))
        }
    }

    private func isStatusRequest(_ request: ProxyHTTPRequest) -> Bool {
        guard request.method == "GET" || request.method == "HEAD" else {
            return false
        }
        let path = UpstreamURLBuilder.splitPathAndQuery(request.path).path
        return path == "/" || path == "/health"
    }

    private func statusResponse() -> ProxyHTTPResponse {
        let body = (try? JSONSerialization.data(
            withJSONObject: ["service": "relaydog", "status": "ok"],
            options: [.sortedKeys]
        )) ?? Data()
        return ProxyHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: body)
    }

    private func buildForwardedRequest(
        localRequest: ProxyHTTPRequest,
        proto: ProxyProtocol,
        selected: SelectedUpstream
    ) throws -> ForwardedHTTPRequest {
        let mappings = effectiveMappings(proto: proto, capability: selected.capability)
        let rewrite = try ModelMapper.rewriteRequestBody(localRequest.body, mappings: mappings)
        let modelRewrite = rewrite.originalModel == nil && rewrite.mappedModel == nil ? nil : rewrite

        return ForwardedHTTPRequest(
            protocol: proto,
            upstreamID: selected.upstream.id,
            method: localRequest.method,
            url: try UpstreamURLBuilder.url(baseURL: selected.capability.baseURL, requestPath: localRequest.path),
            headers: buildHeaders(from: localRequest.headers, proto: proto, capability: selected.capability),
            body: rewrite.body,
            timeoutSeconds: selected.upstream.timeoutSeconds,
            modelRewrite: modelRewrite
        )
    }

    private func effectiveMappings(proto: ProxyProtocol, capability: ProtocolCapabilityConfig) -> [String: String] {
        let global = config.globalModelMappings[proto] ?? [:]
        return global.merging(capability.modelMappings) { _, upstreamSpecific in upstreamSpecific }
    }

    private func buildHeaders(
        from originalHeaders: [String: String],
        proto: ProxyProtocol,
        capability: ProtocolCapabilityConfig
    ) -> [String: String] {
        var headers = originalHeaders.filter { key, _ in
            !Self.strippedForwardedHeaders.contains(key.lowercased())
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

    private func errorResponse(statusCode: Int, message: String) -> ProxyHTTPResponse {
        let body = (try? JSONSerialization.data(withJSONObject: ["error": message], options: [.sortedKeys])) ?? Data()
        return ProxyHTTPResponse(
            statusCode: statusCode,
            headers: ["content-type": "application/json"],
            body: body
        )
    }

    static func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, entry in
            if redactedHeaderNames.contains(entry.key.lowercased()) {
                result[entry.key] = redactedValue(entry.value)
            } else {
                result[entry.key] = entry.value
            }
        }
    }

    private static func redactedValue(_ value: String) -> String {
        if value.lowercased().hasPrefix("bearer ") {
            return "Bearer ***"
        }
        return "***"
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
            requestHeaders: Self.redactedHeaders(forwarded.headers),
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
