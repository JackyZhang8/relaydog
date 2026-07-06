import Foundation

public struct AppPaths: Equatable, Sendable {
    public let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    public var dataDirectory: URL {
        homeDirectory.appendingPathComponent(".relaydog", isDirectory: true)
    }

    public var configFile: URL {
        dataDirectory.appendingPathComponent("config.json")
    }

    public var logsDirectory: URL {
        dataDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    public var stateFile: URL {
        dataDirectory.appendingPathComponent("state.json")
    }

    public func createDirectories(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }
}
