import XCTest
@testable import RelayDogCore

final class AppPathsTests: XCTestCase {
    func testResolvesRelayDogFilesUnderHomeDirectory() {
        let home = URL(fileURLWithPath: "/tmp/relaydog-home", isDirectory: true)
        let paths = AppPaths(homeDirectory: home)

        XCTAssertEqual(paths.dataDirectory.path, "/tmp/relaydog-home/.relaydog")
        XCTAssertEqual(paths.configFile.path, "/tmp/relaydog-home/.relaydog/config.json")
        XCTAssertEqual(paths.logsDirectory.path, "/tmp/relaydog-home/.relaydog/logs")
        XCTAssertEqual(paths.stateFile.path, "/tmp/relaydog-home/.relaydog/state.json")
    }
}
