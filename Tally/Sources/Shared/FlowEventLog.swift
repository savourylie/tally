import Darwin
import Foundation

enum FlowEventLog {
    static func fileURL(in containerURL: URL) -> URL {
        containerURL.appendingPathComponent(TallyAppGroup.flowEventsFilename)
    }

    static func append(_ event: FlowEvent, to containerURL: URL) throws {
        try append([event], to: containerURL)
    }

    static func append(_ events: [FlowEvent], to containerURL: URL) throws {
        guard !events.isEmpty else { return }
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )
        let url = fileURL(in: containerURL)
        try ensureFileExists(at: url)
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }

        try withExclusiveLock(fileDescriptor: handle.fileDescriptor) {
            try handle.seekToEnd()
            for event in events {
                try handle.write(contentsOf: FlowEventCodec.encode(event))
            }
            try handle.synchronize()
        }
    }

    static func drain(from containerURL: URL) throws -> [FlowEvent] {
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )
        let url = fileURL(in: containerURL)
        try ensureFileExists(at: url)
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }

        return try withExclusiveLock(fileDescriptor: handle.fileDescriptor) {
            try handle.seek(toOffset: 0)
            let data = try handle.readToEnd() ?? Data()
            let decoded = FlowEventCodec.decode(data)
            try handle.truncate(atOffset: 0)
            if !decoded.remainder.isEmpty {
                try handle.seek(toOffset: 0)
                try handle.write(contentsOf: decoded.remainder)
            }
            try handle.synchronize()
            return decoded.events
        }
    }

    private static func ensureFileExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }

    private static func withExclusiveLock<T>(
        fileDescriptor: Int32,
        _ body: () throws -> T
    ) throws -> T {
        while flock(fileDescriptor, LOCK_EX) != 0 {
            if errno == EINTR {
                continue
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { flock(fileDescriptor, LOCK_UN) }
        return try body()
    }
}
