import Foundation

public enum HTTPMessageCodecError: Error, Equatable {
    case missingHeaderTerminator
    case missingRequestLine
    case malformedRequestLine(String)
    case malformedHeader(String)
    case invalidContentLength(String)
    case incompleteBody(expected: Int, actual: Int)
}

public struct HTTPRequestBuffer {
    private var data = Data()

    public init() {}

    public var currentData: Data {
        data
    }

    public mutating func append(_ chunk: Data) throws -> Data? {
        data.append(chunk)
        return try HTTPMessageCodec.completeRequestData(in: data)
    }
}

public enum HTTPMessageCodec {
    public static func parseRequest(_ data: Data) throws -> ProxyHTTPRequest {
        let terminator = Data("\r\n\r\n".utf8)
        guard let headerEnd = data.range(of: terminator) else {
            throw HTTPMessageCodecError.missingHeaderTerminator
        }

        let headerData = data[..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw HTTPMessageCodecError.malformedRequestLine("")
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else {
            throw HTTPMessageCodecError.missingRequestLine
        }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count == 3, requestParts[2].hasPrefix("HTTP/") else {
            throw HTTPMessageCodecError.malformedRequestLine(requestLine)
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else {
                throw HTTPMessageCodecError.malformedHeader(line)
            }

            let name = String(line[..<colon])
            let valueStart = line.index(after: colon)
            let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let bodyStart = headerEnd.upperBound
        let availableBody = data[bodyStart...]
        let contentLength = try parseContentLength(headers)

        guard availableBody.count >= contentLength else {
            throw HTTPMessageCodecError.incompleteBody(expected: contentLength, actual: availableBody.count)
        }

        let body = Data(availableBody.prefix(contentLength))
        return ProxyHTTPRequest(method: requestParts[0], path: requestParts[1], headers: headers, body: body)
    }

    public static func encodeResponse(_ response: ProxyHTTPResponse) -> Data {
        var headerLines = ["HTTP/1.1 \(response.statusCode) \(reasonPhrase(for: response.statusCode))"]
        for (name, value) in response.headers {
            if name.lowercased() != "content-length" {
                headerLines.append("\(name): \(value)")
            }
        }
        headerLines.append("Content-Length: \(response.body.count)")

        var data = Data((headerLines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
        data.append(response.body)
        return data
    }

    public static func completeRequestData(in data: Data) throws -> Data? {
        let terminator = Data("\r\n\r\n".utf8)
        guard let headerEnd = data.range(of: terminator) else {
            return nil
        }

        let headerData = data[..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw HTTPMessageCodecError.malformedRequestLine("")
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else {
            throw HTTPMessageCodecError.missingRequestLine
        }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count == 3, requestParts[2].hasPrefix("HTTP/") else {
            throw HTTPMessageCodecError.malformedRequestLine(requestLine)
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else {
                throw HTTPMessageCodecError.malformedHeader(line)
            }

            let name = String(line[..<colon])
            let valueStart = line.index(after: colon)
            let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let bodyStart = headerEnd.upperBound
        let availableBody = data[bodyStart...]
        let contentLength = try parseContentLength(headers)

        guard availableBody.count >= contentLength else {
            return nil
        }

        return Data(data.prefix(bodyStart + contentLength))
    }

    private static func parseContentLength(_ headers: [String: String]) throws -> Int {
        guard let value = headers.first(where: { $0.key.lowercased() == "content-length" })?.value else {
            return 0
        }

        guard let length = Int(value), length >= 0 else {
            throw HTTPMessageCodecError.invalidContentLength(value)
        }
        return length
    }

    private static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: "OK"
        case 201: "Created"
        case 400: "Bad Request"
        case 404: "Not Found"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        default: "Status"
        }
    }
}
