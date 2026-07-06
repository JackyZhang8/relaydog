import Foundation

public struct ProxyEvent: Equatable, Sendable {
    public var id: String
    public var timestamp: Date
    public var proto: ProxyProtocol
    public var method: String
    public var path: String
    public var upstreamID: String
    public var upstreamURL: String
    public var requestHeaders: [String: String]
    public var requestBody: String
    public var originalModel: String?
    public var mappedModel: String?
    public var responseStatus: Int?
    public var responseHeaders: [String: String]
    public var responseBody: String?
    public var durationMilliseconds: Int
    public var error: String?

    public init(
        id: String,
        timestamp: Date,
        proto: ProxyProtocol,
        method: String,
        path: String,
        upstreamID: String,
        upstreamURL: String,
        requestHeaders: [String: String],
        requestBody: String,
        originalModel: String?,
        mappedModel: String?,
        responseStatus: Int?,
        responseHeaders: [String: String],
        responseBody: String?,
        durationMilliseconds: Int,
        error: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.proto = proto
        self.method = method
        self.path = path
        self.upstreamID = upstreamID
        self.upstreamURL = upstreamURL
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.originalModel = originalModel
        self.mappedModel = mappedModel
        self.responseStatus = responseStatus
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.durationMilliseconds = durationMilliseconds
        self.error = error
    }
}

public protocol ProxyEventLogging: Sendable {
    func record(_ event: ProxyEvent) async
}

public struct RequestLogEventLogger: ProxyEventLogging {
    private let store: RequestLogStore
    private let recordResponseBody: Bool
    private let queue: DispatchQueue

    public init(store: RequestLogStore, recordResponseBody: Bool) {
        self.store = store
        self.recordResponseBody = recordResponseBody
        self.queue = DispatchQueue(label: "relaydog.request-log", qos: .utility)
    }

    /// Blocks until all queued log writes have been flushed. Intended for tests and shutdown.
    public func waitUntilDrained() {
        queue.sync {}
    }

    public func record(_ event: ProxyEvent) async {
        let record = RequestLogRecord(
            id: event.id,
            timestamp: event.timestamp,
            proto: event.proto,
            method: event.method,
            path: event.path,
            upstreamID: event.upstreamID,
            upstreamURL: event.upstreamURL,
            requestHeaders: event.requestHeaders,
            requestBody: event.requestBody,
            originalModel: event.originalModel,
            mappedModel: event.mappedModel,
            responseStatus: event.responseStatus,
            responseHeaders: event.responseHeaders,
            responseBody: recordResponseBody ? event.responseBody : nil,
            durationMilliseconds: event.durationMilliseconds,
            error: event.error
        )

        queue.async { [store] in
            try? store.append(record)
        }
    }
}
