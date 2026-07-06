import Foundation

public enum HTTPMessageCodecError: Error, Equatable {
    case missingHeaderTerminator
    case missingRequestLine
    case malformedRequestLine(String)
    case malformedHeader(String)
    case invalidContentLength(String)
    case incompleteBody(expected: Int, actual: Int)
    case malformedChunkedBody
    case requestTooLarge(limitBytes: Int)
}

public struct HTTPRequestBuffer {
    public static let defaultMaxBytes = 100 * 1024 * 1024

    private var data = Data()
    private let maxBytes: Int

    public init(maxBytes: Int = HTTPRequestBuffer.defaultMaxBytes) {
        self.maxBytes = maxBytes
    }

    public var currentData: Data {
        data
    }

    public mutating func append(_ chunk: Data) throws -> Data? {
        data.append(chunk)
        guard data.count <= maxBytes else {
            throw HTTPMessageCodecError.requestTooLarge(limitBytes: maxBytes)
        }
        return try HTTPMessageCodec.completeRequestData(in: data)
    }
}

public enum HTTPMessageCodec {
    struct ParsedRequestHead {
        var method: String
        var target: String
        var headers: [String: String]
        var bodyStart: Int
    }

    private static let hopByHopResponseHeaders: Set<String> = [
        "connection",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailer",
        "transfer-encoding",
        "upgrade",
        "content-encoding",
        "content-length"
    ]

    public static func parseRequest(_ data: Data) throws -> ProxyHTTPRequest {
        let head = try parseHead(data)

        let body: Data
        if isChunked(head.headers) {
            guard let decoded = try decodeChunkedBody(data, from: head.bodyStart) else {
                throw HTTPMessageCodecError.incompleteBody(expected: -1, actual: data.count - head.bodyStart)
            }
            body = decoded.body
        } else {
            let availableBody = data[head.bodyStart...]
            let contentLength = try parseContentLength(head.headers)
            guard availableBody.count >= contentLength else {
                throw HTTPMessageCodecError.incompleteBody(expected: contentLength, actual: availableBody.count)
            }
            body = Data(availableBody.prefix(contentLength))
        }

        return ProxyHTTPRequest(method: head.method, path: head.target, headers: head.headers, body: body)
    }

    public static func encodeResponse(_ response: ProxyHTTPResponse) -> Data {
        var data = encodeHead(
            statusCode: response.statusCode,
            headers: response.headers,
            extraHeaderLines: ["Content-Length: \(response.body.count)"]
        )
        data.append(response.body)
        return data
    }

    public static func encodeResponseHead(statusCode: Int, headers: [String: String]) -> Data {
        encodeHead(statusCode: statusCode, headers: headers, extraHeaderLines: [])
    }

    public static func encodeChunkedResponseHead(statusCode: Int, headers: [String: String]) -> Data {
        encodeHead(statusCode: statusCode, headers: headers, extraHeaderLines: ["Transfer-Encoding: chunked"])
    }

    public static func encodeChunk(_ chunk: Data) -> Data {
        guard !chunk.isEmpty else {
            return Data()
        }
        var data = Data((String(chunk.count, radix: 16) + "\r\n").utf8)
        data.append(chunk)
        data.append(Data("\r\n".utf8))
        return data
    }

    public static let chunkedBodyTerminator = Data("0\r\n\r\n".utf8)

    public static func completeRequestData(in data: Data) throws -> Data? {
        guard let head = try parseHeadIfComplete(data) else {
            return nil
        }

        if isChunked(head.headers) {
            guard let decoded = try decodeChunkedBody(data, from: head.bodyStart) else {
                return nil
            }
            return Data(data.prefix(decoded.endOffset))
        }

        let availableBody = data[head.bodyStart...]
        let contentLength = try parseContentLength(head.headers)

        guard availableBody.count >= contentLength else {
            return nil
        }

        return Data(data.prefix(head.bodyStart + contentLength))
    }

    static func parseHead(_ data: Data) throws -> ParsedRequestHead {
        guard let head = try parseHeadIfComplete(data) else {
            throw HTTPMessageCodecError.missingHeaderTerminator
        }
        return head
    }

    private static func parseHeadIfComplete(_ data: Data) throws -> ParsedRequestHead? {
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
            if let existingKey = headers.keys.first(where: { $0.lowercased() == name.lowercased() }) {
                headers[existingKey] = headers[existingKey]! + ", " + value
            } else {
                headers[name] = value
            }
        }

        return ParsedRequestHead(
            method: requestParts[0],
            target: requestParts[1],
            headers: headers,
            bodyStart: headerEnd.upperBound
        )
    }

    private static func isChunked(_ headers: [String: String]) -> Bool {
        guard let value = headers.first(where: { $0.key.lowercased() == "transfer-encoding" })?.value else {
            return false
        }
        return value.lowercased().contains("chunked")
    }

    static func decodeChunkedBody(_ data: Data, from offset: Int) throws -> (body: Data, endOffset: Int)? {
        var body = Data()
        var cursor = offset
        let crlf = Data("\r\n".utf8)

        while true {
            guard let lineEnd = data.range(of: crlf, in: cursor..<data.count) else {
                return nil
            }

            guard let sizeLine = String(data: data[cursor..<lineEnd.lowerBound], encoding: .utf8) else {
                throw HTTPMessageCodecError.malformedChunkedBody
            }

            let sizeText = sizeLine.split(separator: ";", maxSplits: 1)[0].trimmingCharacters(in: .whitespaces)
            guard let chunkSize = Int(sizeText, radix: 16), chunkSize >= 0 else {
                throw HTTPMessageCodecError.malformedChunkedBody
            }

            cursor = lineEnd.upperBound

            if chunkSize == 0 {
                // Skip optional trailer lines until the terminating empty line.
                while true {
                    guard let trailerEnd = data.range(of: crlf, in: cursor..<data.count) else {
                        return nil
                    }
                    let isEmptyLine = trailerEnd.lowerBound == cursor
                    cursor = trailerEnd.upperBound
                    if isEmptyLine {
                        return (body, cursor)
                    }
                }
            }

            guard data.count >= cursor + chunkSize + crlf.count else {
                return nil
            }

            body.append(data[cursor..<(cursor + chunkSize)])
            cursor += chunkSize

            guard data[cursor..<(cursor + crlf.count)].elementsEqual(crlf) else {
                throw HTTPMessageCodecError.malformedChunkedBody
            }
            cursor += crlf.count
        }
    }

    private static func encodeHead(statusCode: Int, headers: [String: String], extraHeaderLines: [String]) -> Data {
        var headerLines = ["HTTP/1.1 \(statusCode) \(reasonPhrase(for: statusCode))"]
        for (name, value) in headers where !hopByHopResponseHeaders.contains(name.lowercased()) {
            headerLines.append("\(name): \(value)")
        }
        headerLines.append(contentsOf: extraHeaderLines)
        headerLines.append("Connection: close")
        return Data((headerLines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }

    private static func parseContentLength(_ headers: [String: String]) throws -> Int {
        guard let value = headers.first(where: { $0.key.lowercased() == "content-length" })?.value else {
            return 0
        }

        let candidates = Set(value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        guard candidates.count == 1,
              let candidate = candidates.first,
              let length = Int(candidate),
              length >= 0 else {
            throw HTTPMessageCodecError.invalidContentLength(value)
        }
        return length
    }

    private static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 301: "Moved Permanently"
        case 302: "Found"
        case 304: "Not Modified"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 408: "Request Timeout"
        case 409: "Conflict"
        case 413: "Payload Too Large"
        case 422: "Unprocessable Entity"
        case 429: "Too Many Requests"
        case 500: "Internal Server Error"
        case 501: "Not Implemented"
        case 502: "Bad Gateway"
        case 503: "Service Unavailable"
        case 504: "Gateway Timeout"
        default: "Status"
        }
    }
}
