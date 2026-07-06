import XCTest
@testable import RelayDogCore

final class URLSessionUpstreamClientTests: XCTestCase {
    func testSendsForwardedRequestThroughTransport() async throws {
        let transport = RecordingHTTPTransport(response: HTTPTransportResponse(statusCode: 201, headers: ["x-upstream": "ok"], body: Data("created".utf8)))
        let client = URLSessionUpstreamClient(transport: transport)
        let request = ForwardedHTTPRequest(
            protocol: .openAI,
            upstreamID: "glm",
            method: "POST",
            url: URL(string: "https://example.com/v1/responses")!,
            headers: ["Authorization": "Bearer key"],
            body: Data(#"{"model":"glm5.2"}"#.utf8),
            timeoutSeconds: 9,
            modelRewrite: nil
        )

        let response = try await client.send(request)

        XCTAssertEqual(response.statusCode, 201)
        XCTAssertEqual(response.headers["x-upstream"], "ok")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "created")
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].httpMethod, "POST")
        XCTAssertEqual(transport.requests[0].timeoutInterval, 9)
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer key")
        XCTAssertEqual(transport.bodies[0], Data(#"{"model":"glm5.2"}"#.utf8))
    }
}

private final class RecordingHTTPTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    private(set) var bodies: [Data] = []
    private let response: HTTPTransportResponse

    init(response: HTTPTransportResponse) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> HTTPTransportResponse {
        requests.append(request)
        bodies.append(request.httpBody ?? Data())
        return response
    }
}
