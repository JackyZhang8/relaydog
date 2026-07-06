import Foundation

public final class RelayDogRuntimeController: @unchecked Sendable {
    public let config: RelayDogConfig
    public let paths: AppPaths
    public let routingState: RoutingState
    public let healthState: HealthState
    public let statisticsStore: StatisticsStore

    public private(set) var state: RelayDogServerState = .stopped

    private let upstreamClient: any UpstreamClient
    private let transport: ServerTransport
    private var server: RelayDogServer?

    public init(
        config: RelayDogConfig,
        paths: AppPaths = AppPaths(),
        upstreamClient: any UpstreamClient = URLSessionUpstreamClient(),
        transport: ServerTransport = NWListenerServerTransport(),
        routingState: RoutingState = RoutingState(),
        healthState: HealthState = HealthState(),
        statisticsStore: StatisticsStore = StatisticsStore()
    ) {
        self.config = config
        self.paths = paths
        self.upstreamClient = upstreamClient
        self.transport = transport
        self.routingState = routingState
        self.healthState = healthState
        self.statisticsStore = statisticsStore
    }

    public func start() async throws {
        guard config.listener.enabled else {
            state = .stopped
            return
        }

        let engine = RelayDogRuntimeFactory.makeEngine(
            config: config,
            paths: paths,
            upstreamClient: upstreamClient,
            routingState: routingState,
            healthState: healthState,
            statisticsStore: statisticsStore
        )
        let handler = ProxyRequestHandler(engine: engine)
        let server = RelayDogServer(
            host: config.listener.host,
            port: config.listener.port,
            handler: handler,
            transport: transport
        )

        try await server.start()
        self.server = server
        state = server.state
    }

    public func stop() async {
        await server?.stop()
        server = nil
        state = .stopped
    }
}
