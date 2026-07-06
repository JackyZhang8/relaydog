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
            return HTTPMessageCodec.encodeResponse(codecErrorResponse(error))
        } catch {
            return HTTPMessageCodec.encodeResponse(
                ProxyHTTPResponse(
                    statusCode: 502,
                    headers: ["content-type": "application/json"],
                    body: errorBody("Proxy error: \(error)")
                )
            )
        }
    }

    public func handleStream(_ rawRequest: Data, write: @escaping @Sendable (Data) async -> Void) async {
        let request: ProxyHTTPRequest
        do {
            request = try HTTPMessageCodec.parseRequest(rawRequest)
        } catch let error as HTTPMessageCodecError {
            await write(HTTPMessageCodec.encodeResponse(codecErrorResponse(error)))
            return
        } catch {
            await write(HTTPMessageCodec.encodeResponse(
                ProxyHTTPResponse(
                    statusCode: 400,
                    headers: ["content-type": "application/json"],
                    body: errorBody("Bad request: \(error)")
                )
            ))
            return
        }

        await engine.handleStream(request, write: write)
    }

    private func codecErrorResponse(_ error: HTTPMessageCodecError) -> ProxyHTTPResponse {
        if case .requestTooLarge(let limitBytes) = error {
            return ProxyHTTPResponse(
                statusCode: 413,
                headers: ["content-type": "application/json"],
                body: errorBody("Request body exceeds limit of \(limitBytes) bytes")
            )
        }

        return ProxyHTTPResponse(
            statusCode: 400,
            headers: ["content-type": "application/json"],
            body: errorBody("Bad request: \(error)")
        )
    }

    private func errorBody(_ message: String) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["error": message], options: [.sortedKeys])) ?? Data()
    }
}
