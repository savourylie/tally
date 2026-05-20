import Foundation

struct ParsedSample: Equatable, Sendable {
    let pid: Int32
    let processName: String
    let bytesInDelta: Int64
    let bytesOutDelta: Int64
    let observedAt: Date
}

final class NettopParser {
    private struct Baseline {
        var bytesIn: Int64
        var bytesOut: Int64
    }

    private var baselines: [Int32: Baseline] = [:]
    private let timeFormatter: DateFormatter
    private let calendar: Calendar

    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSSSSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        self.timeFormatter = formatter
        self.calendar = Calendar(identifier: .gregorian)
    }

    func resetBaselines() {
        baselines.removeAll(keepingCapacity: true)
    }

    func ingest(line: Substring, wallClock: Date) -> ParsedSample? {
        let trimmed = line.drop(while: { $0.isWhitespace })
            .reversed().drop(while: { $0.isWhitespace }).reversed()
        let trimmedString = String(trimmed)
        if trimmedString.isEmpty { return nil }

        let tokens = trimmedString.split(whereSeparator: { $0.isWhitespace })

        // Header line: starts with "time" and mentions "bytes_in" somewhere.
        if tokens.first == "time" && tokens.contains(where: { $0.contains("bytes_in") }) {
            return nil
        }

        guard tokens.count == 4 else { return nil }

        let timeToken = tokens[0]
        let nameDotPid = tokens[1]
        let bytesInToken = tokens[2]
        let bytesOutToken = tokens[3]

        guard let lastDot = nameDotPid.lastIndex(of: ".") else { return nil }
        let processName = String(nameDotPid[..<lastDot])
        let pidString = nameDotPid[nameDotPid.index(after: lastDot)...]
        guard let pid = Int32(pidString), !processName.isEmpty else { return nil }

        guard let bytesIn = Int64(bytesInToken),
              let bytesOut = Int64(bytesOutToken) else { return nil }

        let observedAt = parseSnapshotTime(timeToken: String(timeToken), wallClock: wallClock)

        let current = Baseline(bytesIn: bytesIn, bytesOut: bytesOut)
        guard let previous = baselines[pid] else {
            baselines[pid] = current
            return nil
        }

        if current.bytesIn < previous.bytesIn || current.bytesOut < previous.bytesOut {
            // Counter reset (process restart with reused PID, or nettop quirk).
            baselines[pid] = current
            return nil
        }

        let deltaIn = current.bytesIn - previous.bytesIn
        let deltaOut = current.bytesOut - previous.bytesOut
        baselines[pid] = current

        if deltaIn == 0 && deltaOut == 0 { return nil }

        return ParsedSample(
            pid: pid,
            processName: processName,
            bytesInDelta: deltaIn,
            bytesOutDelta: deltaOut,
            observedAt: observedAt
        )
    }

    private func parseSnapshotTime(timeToken: String, wallClock: Date) -> Date {
        guard let parsed = timeFormatter.date(from: timeToken) else { return wallClock }
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: parsed)
        var components = calendar.dateComponents([.year, .month, .day], from: wallClock)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond
        guard let combined = calendar.date(from: components) else { return wallClock }
        // Handle midnight rollover: if parsed time is far in the future of wallClock,
        // it likely belongs to the previous day.
        if combined.timeIntervalSince(wallClock) > 60 {
            return calendar.date(byAdding: .day, value: -1, to: combined) ?? wallClock
        }
        return combined
    }
}
