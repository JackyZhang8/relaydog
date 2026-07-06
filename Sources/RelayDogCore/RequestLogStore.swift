import Foundation

public protocol LogCompressor {
    func compress(_ source: URL, to destination: URL) throws
}

public struct GzipLogCompressor: LogCompressor {
    public init() {}

    public func compress(_ source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = ["-c", source.path]

        let output = Pipe()
        process.standardOutput = output
        try process.run()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw RequestLogStoreError.compressionFailed(source.path)
        }

        try data.write(to: destination, options: .atomic)
        try FileManager.default.removeItem(at: source)
    }
}

public struct RequestLogRecord: Codable, Equatable {
    public var id: String
    public var timestamp: Date
    public var proto: ProxyProtocol
    public var method: String
    public var path: String
    public var upstreamID: String
    public var upstreamURL: String
    public var requestHeaders: [String: String]
    public var requestBody: String
    public var originalModel: String?
    public var mappedModel: String?
    public var responseStatus: Int?
    public var responseHeaders: [String: String]
    public var responseBody: String?
    public var durationMilliseconds: Int
    public var error: String?

    public init(
        id: String,
        timestamp: Date,
        proto: ProxyProtocol,
        method: String,
        path: String,
        upstreamID: String,
        upstreamURL: String,
        requestHeaders: [String: String],
        requestBody: String,
        originalModel: String?,
        mappedModel: String?,
        responseStatus: Int?,
        responseHeaders: [String: String],
        responseBody: String?,
        durationMilliseconds: Int,
        error: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.proto = proto
        self.method = method
        self.path = path
        self.upstreamID = upstreamID
        self.upstreamURL = upstreamURL
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.originalModel = originalModel
        self.mappedModel = mappedModel
        self.responseStatus = responseStatus
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.durationMilliseconds = durationMilliseconds
        self.error = error
    }
}

public enum RequestLogStoreError: Error, Equatable {
    case compressionFailed(String)
}

public final class RequestLogStore: @unchecked Sendable {
    private let lock = NSLock()
    private let logsDirectory: URL
    private let maxFileBytes: Int
    private let retentionDays: Int
    private let compressor: LogCompressor
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private var rotationSequence = 0

    private var currentFile: URL {
        logsDirectory.appendingPathComponent("request-current.jsonl")
    }

    public init(
        logsDirectory: URL,
        maxFileBytes: Int,
        retentionDays: Int,
        compressor: LogCompressor = GzipLogCompressor(),
        fileManager: FileManager = .default
    ) {
        self.logsDirectory = logsDirectory
        self.maxFileBytes = maxFileBytes
        self.retentionDays = retentionDays
        self.compressor = compressor
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func append(_ record: RequestLogRecord) throws {
        lock.lock()
        defer { lock.unlock() }

        try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let lineData = try makeLineData(for: record)
        if try shouldRotateBeforeAppending(lineByteCount: lineData.count) {
            try rotateCurrentFile()
        }

        if fileManager.fileExists(atPath: currentFile.path) {
            let handle = try FileHandle(forWritingTo: currentFile)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: lineData)
        } else {
            try lineData.write(to: currentFile, options: .atomic)
        }

        try pruneExpiredLogs(now: Date())
    }

    private func makeLineData(for record: RequestLogRecord) throws -> Data {
        var data = try encoder.encode(record)
        data.append(0x0A)
        return data
    }

    private func shouldRotateBeforeAppending(lineByteCount: Int) throws -> Bool {
        guard fileManager.fileExists(atPath: currentFile.path) else {
            return false
        }

        let attributes = try fileManager.attributesOfItem(atPath: currentFile.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        return size > 0 && size + lineByteCount > maxFileBytes
    }

    private func rotateCurrentFile() throws {
        guard fileManager.fileExists(atPath: currentFile.path) else {
            return
        }

        rotationSequence += 1
        let rotated = logsDirectory.appendingPathComponent(rotatedFileName())
        try fileManager.moveItem(at: currentFile, to: rotated)
        try compressor.compress(rotated, to: rotated.appendingPathExtension("gz"))
    }

    private func rotatedFileName() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        let stamp = formatter.string(from: Date())
        let sequence = String(format: "%03d", rotationSequence)
        return "request-\(stamp)-\(sequence).jsonl"
    }

    private func pruneExpiredLogs(now: Date) throws {
        guard retentionDays >= 0 else {
            return
        }

        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 24 * 60 * 60)
        let files = try fileManager.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        for file in files where isLogArchive(file) {
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values.contentModificationDate, modified < cutoff else {
                continue
            }
            try fileManager.removeItem(at: file)
        }
    }

    private func isLogArchive(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix("request-") && (name.hasSuffix(".jsonl") || name.hasSuffix(".jsonl.gz"))
    }
}
