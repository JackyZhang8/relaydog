import XCTest
@testable import RelayDogCore

final class AppUpdateCheckerTests: XCTestCase {
    func testVersionComparison() throws {
        XCTAssertLessThan(try version("1.0.0"), try version("1.0.1"))
        XCTAssertLessThan(try version("1.9.0"), try version("1.10.0"))
        XCTAssertLessThan(try version("1.0"), try version("1.0.1"))
        XCTAssertEqual(try version("v1.2.0"), try version("1.2"))
        XCTAssertNil(AppVersion("abc"))
        XCTAssertNil(AppVersion(""))
    }

    func testReturnsUpdateAvailableWhenManifestVersionIsNewer() async throws {
        let manifest = AppUpdateManifest(version: "9.9.9", downloadURL: "https://example.com/RelayDog-9.9.9.zip")
        let transport = StubManifestTransport(response: .init(
            statusCode: 200,
            headers: [:],
            body: try JSONEncoder().encode(manifest)
        ))
        let checker = AppUpdateChecker(transport: transport, manifestURL: URL(string: "https://example.com/update.json")!)

        let result = try await checker.check(currentVersion: "1.0.0")

        XCTAssertEqual(result, .updateAvailable(manifest))
    }

    func testReturnsUpToDateWhenManifestVersionIsNotNewer() async throws {
        let manifest = AppUpdateManifest(version: "1.0.0", downloadURL: "https://example.com/RelayDog-1.0.0.zip")
        let transport = StubManifestTransport(response: .init(
            statusCode: 200,
            headers: [:],
            body: try JSONEncoder().encode(manifest)
        ))
        let checker = AppUpdateChecker(transport: transport, manifestURL: URL(string: "https://example.com/update.json")!)

        let result = try await checker.check(currentVersion: "1.0.0")

        XCTAssertEqual(result, .upToDate)
    }

    func testThrowsOnBadStatusAndMalformedManifest() async throws {
        let notFound = AppUpdateChecker(
            transport: StubManifestTransport(response: .init(statusCode: 404, headers: [:], body: Data())),
            manifestURL: URL(string: "https://example.com/update.json")!
        )
        do {
            _ = try await notFound.check(currentVersion: "1.0.0")
            XCTFail("Expected badStatus error")
        } catch {
            XCTAssertEqual(error as? AppUpdateCheckerError, .badStatus(404))
        }

        let malformed = AppUpdateChecker(
            transport: StubManifestTransport(response: .init(statusCode: 200, headers: [:], body: Data("not json".utf8))),
            manifestURL: URL(string: "https://example.com/update.json")!
        )
        do {
            _ = try await malformed.check(currentVersion: "1.0.0")
            XCTFail("Expected malformedManifest error")
        } catch {
            XCTAssertEqual(error as? AppUpdateCheckerError, .malformedManifest)
        }
    }

    private func version(_ text: String) throws -> AppVersion {
        try XCTUnwrap(AppVersion(text))
    }
}

private struct StubManifestTransport: HTTPTransport {
    let response: HTTPTransportResponse

    func data(for request: URLRequest) async throws -> HTTPTransportResponse {
        response
    }
}
