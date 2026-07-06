import Foundation

public enum UpstreamURLBuilder {
    public static func url(baseURL: String, requestPath: String) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }

        let split = splitPathAndQuery(requestPath)
        let basePath = stripTrailingSlash(components.percentEncodedPath)
        let pathToAppend = stripLocalVersionPrefixIfNeeded(basePath: basePath, requestPath: split.path)
        components.percentEncodedPath = joinPath(basePath, pathToAppend)
        components.percentEncodedQuery = split.query

        guard let url = components.url else {
            throw ProxyEngineError.invalidBaseURL(baseURL)
        }
        return url
    }

    public static func splitPathAndQuery(_ path: String) -> (path: String, query: String?) {
        guard let question = path.firstIndex(of: "?") else {
            return (path, nil)
        }
        return (String(path[..<question]), String(path[path.index(after: question)...]))
    }

    public static func stripLocalVersionPrefixIfNeeded(basePath: String, requestPath: String) -> String {
        if basePath.hasSuffix("/v1"), requestPath == "/v1" {
            return ""
        }

        if basePath.hasSuffix("/v1"), requestPath.hasPrefix("/v1/") {
            return String(requestPath.dropFirst("/v1".count))
        }

        return requestPath
    }

    public static func joinPath(_ basePath: String, _ requestPath: String) -> String {
        let trimmedBase = stripTrailingSlash(basePath)
        let trimmedRequest = requestPath.hasPrefix("/") ? String(requestPath.dropFirst()) : requestPath

        if trimmedBase.isEmpty {
            return "/" + trimmedRequest
        }

        if trimmedRequest.isEmpty {
            return trimmedBase
        }

        return trimmedBase + "/" + trimmedRequest
    }

    public static func stripTrailingSlash(_ value: String) -> String {
        guard value.count > 1, value.hasSuffix("/") else {
            return value
        }
        return String(value.dropLast())
    }
}
