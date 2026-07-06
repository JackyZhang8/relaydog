import XCTest
@testable import RelayDogCore

final class ProxyEventLoggerTests: XCTestCase {
    func testProxyEngineRecordsSuccessfulRequestEvent() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: ["content-type": "application/json"], body: Data(#"{"ok":true}"#.utf8)))
        let logger = RecordingProxyEventLogger()
        let engine = ProxyEngine(
            config: TestConfigs.proxyEngineConfig(),
            upstreamClient: client,
            eventLogger: logger
        )

        _ = try await engine.handle(
            ProxyHTTPRequest(
                method: "POST",
                path: "/v1/responses",
                headers: ["content-type": "application/json"],
                body: Data(#"{"model":"gpt-5.5"}"#.utf8)
            )
        )

        let event = try XCTUnwrap(logger.events.first)
        XCTAssertEqual(event.proto, .openAI)
        XCTAssertEqual(event.path, "/v1/responses")
        XCTAssertEqual(event.upstreamID, "glm")
        XCTAssertEqual(event.responseStatus, 200)
        XCTAssertEqual(event.originalModel, "gpt-5.5")
        XCTAssertEqual(event.mappedModel, "glm5.2")
        XCTAssertNil(event.error)
    }

    func testRequestLogEventLoggerWritesJsonLine() async throws {
        let temp = try TemporaryProxyEventLogDirectory()
        let store = RequestLogStore(logsDirectory: temp.url, maxFileBytes: 1024, retentionDays: 7, compressor: NoopCompressor())
        let logger = RequestLogEventLogger(store: store, recordResponseBody: true)

        await logger.record(
            ProxyEvent(
                id: "event-1",
                timestamp: Date(timeIntervalSince1970: 1_782_604_800),
                proto: .openAI,
                method: "POST",
                path: "/v1/responses",
                upstreamID: "glm",
                upstreamURL: "https://example.com/openai/v1/responses",
                requestHeaders: ["content-type": "application/json"],
                requestBody: #"{"model":"glm5.2"}"#,
                originalModel: "gpt-5.5",
                mappedModel: "glm5.2",
                responseStatus: 200,
                responseHeaders: ["content-type": "application/json"],
                responseBody: #"{"ok":true}"#,
                durationMilliseconds: 10,
                error: nil
            )
        )

        let log = try String(contentsOf: temp.url.appendingPathComponent("request-current.jsonl"), encoding: .utf8)
        XCTAssertTrue(log.contains("\"id\":\"event-1\""))
        XCTAssertTrue(log.contains("\"mappedModel\":\"glm5.2\""))
    }
}

final class RecordingProxyEventLogger: ProxyEventLogging, @unchecked Sendable {
    private(set) var events: [ProxyEvent] = []

    func record(_ event: ProxyEvent) async {
        events.append(event)
    }
}

private struct NoopCompressor: LogCompressor {
    func compress(_ source: URL, to destination: URL) throws {}
}

private struct TemporaryProxyEventLogDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relaydog-event-log-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
