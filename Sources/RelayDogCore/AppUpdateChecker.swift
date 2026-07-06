import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AppVersion: Equatable, Comparable, Sendable, CustomStringConvertible {
    public var components: [Int]

    public init?(_ text: String) {
        let normalized = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return nil
        }

        var components: [Int] = []
        for part in parts {
            guard let value = Int(part), value >= 0 else {
                return nil
            }
            components.append(value)
        }
        self.components = components
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

public struct AppUpdateManifest: Codable, Equatable, Sendable {
    public var version: String
    public var downloadURL: String
    public var releaseNotes: String?

    public init(version: String, downloadURL: String, releaseNotes: String? = nil) {
        self.version = version
        self.downloadURL = downloadURL
        self.releaseNotes = releaseNotes
    }
}

public enum AppUpdateCheckResult: Equatable, Sendable {
    case upToDate
    case updateAvailable(AppUpdateManifest)
}

public enum AppUpdateCheckerError: Error, Equatable {
    case badStatus(Int)
    case malformedManifest
}

public enum RelayDogAppInfo {
    public static let fallbackVersion = "0.1.0"
    public static let repositoryURL = "https://github.com/JackyZhang8/relaydog"
    public static let updateManifestURL = URL(string: "https://github.com/JackyZhang8/relaydog/releases/latest/download/update.json")!

    public static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? fallbackVersion
    }
}

public struct AppUpdateChecker: Sendable {
    private let transport: any HTTPTransport
    private let manifestURL: URL

    public init(
        transport: any HTTPTransport = URLSessionHTTPTransport(),
        manifestURL: URL = RelayDogAppInfo.updateManifestURL
    ) {
        self.transport = transport
        self.manifestURL = manifestURL
    }

    public func check(currentVersion: String = RelayDogAppInfo.currentVersion) async throws -> AppUpdateCheckResult {
        var request = URLRequest(url: manifestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw AppUpdateCheckerError.badStatus(response.statusCode)
        }

        guard let manifest = try? JSONDecoder().decode(AppUpdateManifest.self, from: response.body),
              let latest = AppVersion(manifest.version),
              URL(string: manifest.downloadURL) != nil else {
            throw AppUpdateCheckerError.malformedManifest
        }

        guard let current = AppVersion(currentVersion), current < latest else {
            return .upToDate
        }

        return .updateAvailable(manifest)
    }
}
