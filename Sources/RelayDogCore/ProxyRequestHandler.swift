import Foundation

public struct ProxyRequestHandler: Sendable {
    public var engine: ProxyEngine

    public init(engine: ProxyEngine) {
        self.engine = engine
    }

    public func handle(_ rawRequest: Data) async throws -> Data {
        do {
            let request = try HTTPMessageCodec.parseRequest(rawRequest)
            let response = try await engine.handle(request)
            return HTTPMessageCodec.encodeResponse(response)
        } catch let error as HTTPMessageCodecError {
            return HTTPMessageCodec.encodeResponse(
                ProxyHTTPResponse(
                    statusCode: 400,
                    headers: ["content-type": "application/json"],
                    body: errorBody("Bad request: \(error)")
                )
            )
        }
    }

    private func errorBody(_ message: String) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["error": message], options: [.sortedKeys])) ?? Data()
    }
}
