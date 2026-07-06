import Foundation

public struct HTTPTransportResponse: Equatable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public struct HTTPTransportStreamResponse: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: AsyncThrowingStream<Data, Error>

    public init(statusCode: Int, headers: [String: String], body: AsyncThrowingStream<Data, Error>) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> HTTPTransportResponse
    func stream(for request: URLRequest) async throws -> HTTPTransportStreamResponse
}

public extension HTTPTransport {
    func stream(for request: URLRequest) async throws -> HTTPTransportStreamResponse {
        let response = try await data(for: request)
        return HTTPTransportStreamResponse(
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

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> HTTPTransportResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return HTTPTransportResponse(statusCode: 502, headers: [:], body: data)
        }

        return HTTPTransportResponse(
            statusCode: httpResponse.statusCode,
            headers: Self.headers(from: httpResponse),
            body: data
        )
    }

    public func stream(for request: URLRequest) async throws -> HTTPTransportStreamResponse {
        let delegate = StreamingTaskDelegate()
        let task = session.dataTask(with: request)
        task.delegate = delegate
        return try await delegate.start(task)
    }

    static func headers(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }
        return headers
    }
}

private final class StreamingTaskDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var headContinuation: CheckedContinuation<HTTPTransportStreamResponse, Error>?
    private var bodyContinuation: AsyncThrowingStream<Data, Error>.Continuation?

    func start(_ task: URLSessionDataTask) async throws -> HTTPTransportStreamResponse {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            headContinuation = continuation
            lock.unlock()
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let statusCode: Int
        let headers: [String: String]
        if let httpResponse = response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            headers = URLSessionHTTPTransport.headers(from: httpResponse)
        } else {
            statusCode = 502
            headers = [:]
        }

        let body = AsyncThrowingStream<Data, Error> { continuation in
            continuation.onTermination = { termination in
                if case .cancelled = termination {
                    dataTask.cancel()
                }
            }
            lock.lock()
            bodyContinuation = continuation
            lock.unlock()
        }

        resumeHead(with: .success(HTTPTransportStreamResponse(statusCode: statusCode, headers: headers, body: body)))
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        let continuation = bodyContinuation
        lock.unlock()
        continuation?.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = bodyContinuation
        bodyContinuation = nil
        lock.unlock()

        if let continuation {
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
            return
        }

        resumeHead(with: .failure(error ?? URLError(.unknown)))
    }

    private func resumeHead(with result: Result<HTTPTransportStreamResponse, Error>) {
        lock.lock()
        let continuation = headContinuation
        headContinuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

public struct URLSessionUpstreamClient: UpstreamClient {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    public func send(_ request: ForwardedHTTPRequest) async throws -> ProxyHTTPResponse {
        let response = try await transport.data(for: makeURLRequest(request))
        return ProxyHTTPResponse(statusCode: response.statusCode, headers: response.headers, body: response.body)
    }

    public func stream(_ request: ForwardedHTTPRequest) async throws -> UpstreamStreamingResponse {
        let response = try await transport.stream(for: makeURLRequest(request))
        return UpstreamStreamingResponse(statusCode: response.statusCode, headers: response.headers, body: response.body)
    }

    private func makeURLRequest(_ request: ForwardedHTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        if let timeoutSeconds = request.timeoutSeconds, timeoutSeconds > 0 {
            urlRequest.timeoutInterval = TimeInterval(timeoutSeconds)
        }

        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        return urlRequest
    }
}
