import Foundation

public struct ProxyHTTPRequest: Equatable, Sendable {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: Data

    public init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public struct ForwardedHTTPRequest: Equatable, Sendable {
    public var `protocol`: ProxyProtocol
    public var upstreamID: String
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data
    public var timeoutSeconds: Int?
    public var modelRewrite: ModelRewriteResult?

    public init(
        protocol proto: ProxyProtocol,
        upstreamID: String,
        method: String,
        url: URL,
        headers: [String: String],
        body: Data,
        timeoutSeconds: Int? = nil,
        modelRewrite: ModelRewriteResult?
    ) {
        self.protocol = proto
        self.upstreamID = upstreamID
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeoutSeconds = timeoutSeconds
        self.modelRewrite = modelRewrite
    }
}

public struct ProxyHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public struct UpstreamStreamingResponse: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: AsyncThrowingStream<Data, Error>

    public init(statusCode: Int, headers: [String: String], body: AsyncThrowingStream<Data, Error>) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public protocol UpstreamClient: Sendable {
    func send(_ request: ForwardedHTTPRequest) async throws -> ProxyHTTPResponse
    func stream(_ request: ForwardedHTTPRequest) async throws -> UpstreamStreamingResponse
}

public extension UpstreamClient {
    func stream(_ request: ForwardedHTTPRequest) async throws -> UpstreamStreamingResponse {
        let response = try await send(request)
        return UpstreamStreamingResponse(
            statusCode: response.statusCode,
            headers: response.headers,
            body: AsyncThrowingStream { continuation in
                if !response.body.isEmpty {
                    continuation.yield(response.body)
                }
                continuation.finish()
            }
        )
    }
}
