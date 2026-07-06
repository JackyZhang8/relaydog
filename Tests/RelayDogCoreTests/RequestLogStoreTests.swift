import XCTest
@testable import RelayDogCore

final class RequestLogStoreTests: XCTestCase {
    func testRequestLogRecordIsSendable() {
        assertSendable(RequestLogRecord.self)
    }

    func testAppendsJsonLine() throws {
        let temp = try TemporaryDirectory()
        let store = RequestLogStore(logsDirectory: temp.url, maxFileBytes: 1024, retentionDays: 7, compressor: RecordingCompressor())

        try store.append(.fixture(id: "req-1", path: "/v1/responses"))

        let files = try FileManager.default.contentsOfDirectory(atPath: temp.url.path)
        XCTAssertEqual(files, ["request-current.jsonl"])
        let text = try String(contentsOf: temp.url.appendingPathComponent("request-current.jsonl"), encoding: .utf8)
        XCTAssertTrue(text.contains("\"id\":\"req-1\""))
        XCTAssertTrue(text.hasSuffix("\n"))
    }

    func testRotatesAndCompressesWhenFileWouldExceedLimit() throws {
        let temp = try TemporaryDirectory()
        let compressor = RecordingCompressor()
        let store = RequestLogStore(logsDirectory: temp.url, maxFileBytes: 60, retentionDays: 7, compressor: compressor)

        try store.append(.fixture(id: "req-1", path: "/v1/responses"))
        try store.append(.fixture(id: "req-2", path: "/v1/messages"))

        XCTAssertEqual(compressor.compressedSources.count, 1)
        XCTAssertTrue(compressor.compressedSources[0].lastPathComponent.hasPrefix("request-"))
    }

    func testPruneRemovesExpiredArchivesButKeepsCurrentFile() throws {
        let temp = try TemporaryDirectory()
        let store = RequestLogStore(logsDirectory: temp.url, maxFileBytes: 1024, retentionDays: 7, compressor: RecordingCompressor())
        let oldDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let archive = temp.url.appendingPathComponent("request-2020-01-01-000000-001.jsonl.gz")
        let current = temp.url.appendingPathComponent("request-current.jsonl")
        try Data("old".utf8).write(to: archive)
        try Data("{}\n".utf8).write(to: current)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: archive.path)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: current.path)

        try store.append(.fixture(id: "req-1", path: "/v1/responses"))

        let files = try FileManager.default.contentsOfDirectory(atPath: temp.url.path)
        XCTAssertEqual(files, ["request-current.jsonl"])
        let text = try String(contentsOf: current, encoding: .utf8)
        XCTAssertTrue(text.contains("\"id\":\"req-1\""))
    }

    #if canImport(Compression)
    func testGzipCompressorProducesGzipFileAndRemovesSource() throws {
        let temp = try TemporaryDirectory()
        let source = temp.url.appendingPathComponent("request-old.jsonl")
        let destination = source.appendingPathExtension("gz")
        try Data(String(repeating: "{\"ok\":true}\n", count: 100).utf8).write(to: source)

        try GzipLogCompressor().compress(source, to: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        let compressed = try Data(contentsOf: destination)
        XCTAssertEqual(Array(compressed.prefix(2)), [0x1f, 0x8b])
        XCTAssertLessThan(compressed.count, 100 * 12)
    }
    #endif

    func testConcurrentAppendsPreserveEveryJsonLine() async throws {
        let temp = try TemporaryDirectory()
        let store = RequestLogStore(logsDirectory: temp.url, maxFileBytes: 1024 * 1024, retentionDays: 7, compressor: RecordingCompressor())

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    try store.append(.fixture(id: "event-\(index)", path: "/v1/responses"))
                }
            }
            try await group.waitForAll()
        }

        let text = try String(contentsOf: temp.url.appendingPathComponent("request-current.jsonl"), encoding: .utf8)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 100)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let ids = try lines.map { line in
            let data = try XCTUnwrap(String(line).data(using: .utf8))
            return try decoder.decode(RequestLogRecord.self, from: data).id
        }
        XCTAssertEqual(Set(ids).count, 100)
    }
}

private final class RecordingCompressor: LogCompressor {
    private(set) var compressedSources: [URL] = []

    func compress(_ source: URL, to destination: URL) throws {
        compressedSources.append(source)
        try Data().write(to: destination)
        try FileManager.default.removeItem(at: source)
    }
}

private func assertSendable<T: Sendable>(_ type: T.Type) {}

private extension RequestLogRecord {
    static func fixture(id: String, path: String) -> RequestLogRecord {
        RequestLogRecord(
            id: id,
            timestamp: Date(timeIntervalSince1970: 1_782_604_800),
            proto: .openAI,
            method: "POST",
            path: path,
            upstreamID: "glm",
            upstreamURL: "https://example.com",
            requestHeaders: ["content-type": "application/json"],
            requestBody: #"{"model":"gpt-5.5"}"#,
            originalModel: "gpt-5.5",
            mappedModel: "glm5.2",
            responseStatus: 200,
            responseHeaders: ["content-type": "application/json"],
            responseBody: #"{"ok":true}"#,
            durationMilliseconds: 120,
            error: nil
        )
    }
}

private struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relaydog-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
