import Foundation

public struct ConfigStore {
    public let paths: AppPaths
    private let fileManager: FileManager

    public init(paths: AppPaths = AppPaths(), fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    public func load() throws -> RelayDogConfig {
        let data = try Data(contentsOf: paths.configFile)
        return try JSONDecoder.relayDog.decode(RelayDogConfig.self, from: data)
    }

    @discardableResult
    public func loadOrCreateDefault() throws -> RelayDogConfig {
        try paths.createDirectories(fileManager: fileManager)

        if fileManager.fileExists(atPath: paths.configFile.path) {
            return try load()
        }

        let config = RelayDogConfig.defaultConfig()
        try save(config)
        return config
    }

    public func save(_ config: RelayDogConfig) throws {
        try paths.createDirectories(fileManager: fileManager)
        let data = try JSONEncoder.relayDog.encode(config)
        try data.write(to: paths.configFile, options: .atomic)
    }
}

public extension RelayDogConfig {
    static func defaultConfig() -> RelayDogConfig {
        RelayDogConfig(
            listener: .init(host: "127.0.0.1", port: 18787, enabled: true),
            upstreams: [],
            routing: [
                .openAI: .init(mode: .single, selectedUpstreamID: nil),
                .claude: .init(mode: .single, selectedUpstreamID: nil)
            ],
            globalModelMappings: [:],
            requestLogging: .init(
                enabled: false,
                maxFileBytes: 50 * 1024 * 1024,
                retentionDays: 7,
                recordResponseBody: true
            )
        )
    }
}
