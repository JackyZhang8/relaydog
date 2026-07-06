import Foundation
import RelayDogCore

@main
struct RelayDogDaemon {
    static func main() async throws {
        let store = ConfigStore()
        let config = try store.loadOrCreateDefault()

        let runtime = RelayDogRuntimeController(
            config: config,
            paths: store.paths,
            upstreamClient: URLSessionUpstreamClient()
        )

        guard config.listener.enabled else {
            print("RelayDog listener is disabled in config.")
            return
        }

        try await runtime.start()
        print("RelayDog listening on \(config.listener.host):\(config.listener.port)")

        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
