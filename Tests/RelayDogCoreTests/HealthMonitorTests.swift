import XCTest
@testable import RelayDogCore

final class HealthMonitorTests: XCTestCase {
    func testHealthCheckURLDoesNotDuplicateV1PathSegment() async throws {
        let transport = HealthRecordingHTTPTransport(response: .init(statusCode: 200, headers: [:], body: Data()))
        let monitor = HealthMonitor(transport: transport)
        let upstream = UpstreamConfig(
            id: "glm",
            name: "GLM Gateway",
            enabled: true,
            weight: 100,
            timeoutSeconds: 60,
            note: "",
            protocols: [
                .openAI: .init(
                    enabled: true,
                    baseURL: "https://example.com/openai/v1",
                    apiKey: "sk-plain-text",
                    headerOverrides: [:],
                    healthCheckPath: "/v1/models",
                    modelSync: .manual,
                    models: [],
                    modelMappings: [:]
                )
            ]
        )

        let checkedHealth = await monitor.check(upstream: upstream, proto: .openAI)
        let health = try XCTUnwrap(checkedHealth)

        XCTAssertTrue(health.isReachable)
        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "https://example.com/openai/v1/models")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-plain-text")
    }

    func testHealthCheckTreatsAuthenticationFailureAsUnreachable() async throws {
        let transport = HealthRecordingHTTPTransport(response: .init(statusCode: 401, headers: [:], body: Data()))
        let monitor = HealthMonitor(transport: transport)

        let checkedHealth = await monitor.check(upstream: openAIUpstream(), proto: .openAI)
        let health = try XCTUnwrap(checkedHealth)

        XCTAssertFalse(health.isReachable)
        XCTAssertEqual(health.lastError, "HTTP 401")
    }

    private func openAIUpstream() -> UpstreamConfig {
        UpstreamConfig(
            id: "glm",
            name: "GLM Gateway",
            enabled: true,
            weight: 100,
            timeoutSeconds: 60,
            note: "",
            protocols: [
                .openAI: .init(
                    enabled: true,
                    baseURL: "https://example.com/openai/v1",
                    apiKey: "sk-plain-text",
                    headerOverrides: [:],
                    healthCheckPath: "/v1/models",
                    modelSync: .manual,
                    models: [],
                    modelMappings: [:]
                )
            ]
        )
    }
}

private final class HealthRecordingHTTPTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    private let response: HTTPTransportResponse

    init(response: HTTPTransportResponse) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> HTTPTransportResponse {
        requests.append(request)
        return response
    }
}
