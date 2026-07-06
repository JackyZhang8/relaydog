import XCTest
@testable import RelayDogCore

final class HTTPMessageCodecTests: XCTestCase {
    func testParsesCompleteHTTPRequestWithHeadersAndBody() throws {
        let raw = Data("""
        POST /v1/responses?trace=1 HTTP/1.1\r
        Host: 127.0.0.1:18787\r
        Content-Type: application/json\r
        Content-Length: 19\r
        \r
        {"model":"gpt-5.5"}
        """.utf8)

        let request = try HTTPMessageCodec.parseRequest(raw)

        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/v1/responses?trace=1")
        XCTAssertEqual(request.headers["Host"], "127.0.0.1:18787")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(String(decoding: request.body, as: UTF8.self), #"{"model":"gpt-5.5"}"#)
    }

    func testRejectsRequestWhenBodyIsShorterThanContentLength() {
        let raw = Data("POST /v1/responses HTTP/1.1\r\nContent-Length: 5\r\n\r\nhi".utf8)

        XCTAssertThrowsError(try HTTPMessageCodec.parseRequest(raw)) { error in
            XCTAssertEqual(error as? HTTPMessageCodecError, .incompleteBody(expected: 5, actual: 2))
        }
    }

    func testRequestBufferWaitsForCompleteHeaderAndBodyAcrossChunks() throws {
        var buffer = HTTPRequestBuffer()
        let first = Data("POST /v1/responses HTTP/1.1\r\nHost: localhost\r\nContent-Length: 11\r\n\r\nhello".utf8)
        let second = Data(" world".utf8)

        XCTAssertNil(try buffer.append(first))
        let complete = try XCTUnwrap(buffer.append(second))

        XCTAssertEqual(try HTTPMessageCodec.parseRequest(complete).body, Data("hello world".utf8))
    }

    func testEncodesHTTPResponseWithContentLength() throws {
        let response = ProxyHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: Data(#"{"ok":true}"#.utf8))

        let data = HTTPMessageCodec.encodeResponse(response)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(text.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(text.contains("content-type: application/json\r\n"))
        XCTAssertTrue(text.contains("Content-Length: 11\r\n"))
        XCTAssertTrue(text.hasSuffix("\r\n\r\n{\"ok\":true}"))
    }
}
