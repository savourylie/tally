import Foundation

struct FlowEvent: Equatable, Sendable {
    var timestamp: Int64
    var bundleId: String?
    var executableName: String
    var bytesIn: Int64
    var bytesOut: Int64

    init(
        timestamp: Int64 = Int64(Date().timeIntervalSince1970),
        bundleId: String?,
        executableName: String,
        bytesIn: Int64,
        bytesOut: Int64
    ) {
        self.timestamp = timestamp
        self.bundleId = bundleId?.isEmpty == true ? nil : bundleId
        self.executableName = executableName.isEmpty ? "unknown" : executableName
        self.bytesIn = max(0, bytesIn)
        self.bytesOut = max(0, bytesOut)
    }
}

enum FlowEventCodec {
    private static let magic: UInt32 = 0x5446_4C31 // TFL1
    private static let nilStringLength = UInt32.max
    private static let headerByteCount = 36

    static func encode(_ event: FlowEvent) throws -> Data {
        var data = Data()
        data.reserveCapacity(headerByteCount + 128)
        data.appendLittleEndian(magic)
        data.appendLittleEndian(event.timestamp)
        data.appendLittleEndian(event.bytesIn)
        data.appendLittleEndian(event.bytesOut)

        let bundleBytes = try encodedString(event.bundleId)
        let executableBytes = try encodedString(event.executableName)
        data.appendLittleEndian(UInt32(bundleBytes?.count ?? Int(nilStringLength)))
        data.appendLittleEndian(UInt32(executableBytes?.count ?? Int(nilStringLength)))

        if let bundleBytes {
            data.append(bundleBytes)
        }
        if let executableBytes {
            data.append(executableBytes)
        }
        return data
    }

    static func decode(_ data: Data) -> (events: [FlowEvent], remainder: Data) {
        var cursor = 0
        var events: [FlowEvent] = []

        while cursor + headerByteCount <= data.count {
            guard readUInt32(data, at: cursor) == magic else {
                cursor += 1
                continue
            }

            guard
                let timestamp = readInt64(data, at: cursor + 4),
                let bytesIn = readInt64(data, at: cursor + 12),
                let bytesOut = readInt64(data, at: cursor + 20),
                let bundleLength = readUInt32(data, at: cursor + 28),
                let executableLength = readUInt32(data, at: cursor + 32)
            else {
                break
            }

            let bundleByteCount = bundleLength == nilStringLength ? 0 : Int(bundleLength)
            let executableByteCount = executableLength == nilStringLength ? 0 : Int(executableLength)
            let payloadByteCount = bundleByteCount + executableByteCount
            guard cursor + headerByteCount + payloadByteCount <= data.count else {
                break
            }

            var payloadCursor = cursor + headerByteCount
            let bundleId: String?
            if bundleLength == nilStringLength {
                bundleId = nil
            } else {
                let range = payloadCursor..<(payloadCursor + bundleByteCount)
                bundleId = String(data: data.subdata(in: range), encoding: .utf8)
                payloadCursor += bundleByteCount
            }

            let executableName: String
            if executableLength == nilStringLength {
                executableName = "unknown"
            } else {
                let range = payloadCursor..<(payloadCursor + executableByteCount)
                executableName = String(data: data.subdata(in: range), encoding: .utf8) ?? "unknown"
                payloadCursor += executableByteCount
            }

            events.append(FlowEvent(
                timestamp: timestamp,
                bundleId: bundleId,
                executableName: executableName,
                bytesIn: bytesIn,
                bytesOut: bytesOut
            ))
            cursor = payloadCursor
        }

        return (events, data.subdata(in: cursor..<data.count))
    }

    private static func encodedString(_ value: String?) throws -> Data? {
        guard let value else { return nil }
        let data = Data(value.utf8)
        guard data.count < Int(nilStringLength) else {
            throw FlowEventCodecError.stringTooLong
        }
        return data
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        var value: UInt32 = 0
        for index in 0..<4 {
            value |= UInt32(data[offset + index]) << UInt32(index * 8)
        }
        return value
    }

    private static func readInt64(_ data: Data, at offset: Int) -> Int64? {
        guard offset >= 0, offset + 8 <= data.count else { return nil }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(data[offset + index]) << UInt64(index * 8)
        }
        return Int64(bitPattern: value)
    }
}

enum FlowEventCodecError: LocalizedError {
    case stringTooLong

    var errorDescription: String? {
        switch self {
        case .stringTooLong:
            return "Flow event string is too long"
        }
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(contentsOf: buffer)
        }
    }
}
