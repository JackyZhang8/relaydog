import Foundation

public enum RelayDogRuntimeFactory {
    public static func makeEngine(
        config: RelayDogConfig,
        paths: AppPaths = AppPaths(),
        upstreamClient: any UpstreamClient = URLSessionUpstreamClient(),
        routingState: RoutingState = RoutingState(),
        healthState: HealthState = HealthState(),
        statisticsStore: StatisticsStore = StatisticsStore()
    ) -> ProxyEngine {
        ProxyEngine(
            config: config,
            upstreamClient: upstreamClient,
            eventLogger: makeEventLogger(config: config, paths: paths),
            routingState: routingState,
            healthState: healthState,
            statisticsStore: statisticsStore
        )
    }

    public static func makeEventLogger(
        config: RelayDogConfig,
        paths: AppPaths = AppPaths()
    ) -> (any ProxyEventLogging)? {
        guard config.requestLogging.enabled else {
            return nil
        }

        let store = RequestLogStore(
            logsDirectory: paths.logsDirectory,
            maxFileBytes: config.requestLogging.maxFileBytes,
            retentionDays: config.requestLogging.retentionDays
        )
        return RequestLogEventLogger(
            store: store,
            recordResponseBody: config.requestLogging.recordResponseBody
        )
    }
}
