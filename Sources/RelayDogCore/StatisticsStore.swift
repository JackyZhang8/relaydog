import Foundation

public struct RequestStatistic: Equatable, Sendable {
    public var proto: ProxyProtocol
    public var upstreamID: String
    public var succeeded: Bool
    public var durationMilliseconds: Int

    public init(proto: ProxyProtocol, upstreamID: String, succeeded: Bool, durationMilliseconds: Int) {
        self.proto = proto
        self.upstreamID = upstreamID
        self.succeeded = succeeded
        self.durationMilliseconds = durationMilliseconds
    }
}

public struct StatisticsSnapshot: Equatable, Sendable {
    public var totalRequests: Int
    public var failedRequests: Int
    public var successRate: Double
    public var averageDurationMilliseconds: Int

    public init(
        totalRequests: Int,
        failedRequests: Int,
        successRate: Double,
        averageDurationMilliseconds: Int
    ) {
        self.totalRequests = totalRequests
        self.failedRequests = failedRequests
        self.successRate = successRate
        self.averageDurationMilliseconds = averageDurationMilliseconds
    }
}

public final class StatisticsStore: @unchecked Sendable {
    private let lock = NSLock()
    private var buckets: [StatisticsKey: StatisticsBucket] = [:]

    public init() {}

    public func record(_ statistic: RequestStatistic) {
        lock.lock()
        defer { lock.unlock() }

        let key = StatisticsKey(proto: statistic.proto, upstreamID: statistic.upstreamID)
        var bucket = buckets[key, default: StatisticsBucket()]
        bucket.totalRequests += 1
        if !statistic.succeeded {
            bucket.failedRequests += 1
        }
        bucket.totalDurationMilliseconds += max(0, statistic.durationMilliseconds)
        buckets[key] = bucket
    }

    public func snapshot(protocol proto: ProxyProtocol, upstreamID: String) -> StatisticsSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let bucket = buckets[StatisticsKey(proto: proto, upstreamID: upstreamID)] ?? StatisticsBucket()
        guard bucket.totalRequests > 0 else {
            return StatisticsSnapshot(totalRequests: 0, failedRequests: 0, successRate: 0, averageDurationMilliseconds: 0)
        }

        let successful = bucket.totalRequests - bucket.failedRequests
        return StatisticsSnapshot(
            totalRequests: bucket.totalRequests,
            failedRequests: bucket.failedRequests,
            successRate: Double(successful) / Double(bucket.totalRequests),
            averageDurationMilliseconds: bucket.totalDurationMilliseconds / bucket.totalRequests
        )
    }
}

private struct StatisticsKey: Hashable {
    var proto: ProxyProtocol
    var upstreamID: String
}

private struct StatisticsBucket {
    var totalRequests: Int = 0
    var failedRequests: Int = 0
    var totalDurationMilliseconds: Int = 0
}
