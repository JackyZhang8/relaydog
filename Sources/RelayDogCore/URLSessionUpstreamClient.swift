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

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> HTTPTransportResponse
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

        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }

        return HTTPTransportResponse(statusCode: httpResponse.statusCode, headers: headers, body: data)
    }
}

public struct URLSessionUpstreamClient: UpstreamClient {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    public func send(_ request: ForwardedHTTPRequest) async throws -> ProxyHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        if let timeoutSeconds = request.timeoutSeconds, timeoutSeconds > 0 {
            urlRequest.timeoutInterval = TimeInterval(timeoutSeconds)
        }

        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let response = try await transport.data(for: urlRequest)
        return ProxyHTTPResponse(statusCode: response.statusCode, headers: response.headers, body: response.body)
    }
}
