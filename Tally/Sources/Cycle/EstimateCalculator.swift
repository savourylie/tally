import Foundation

enum EstimateCalculator {
    static let bytesPerGigabyte: Double = 1_073_741_824

    static func projectedTotalBytes(
        mtdBytes: Int64,
        daysElapsed: Int,
        daysInCycle: Int
    ) -> Int64 {
        guard daysElapsed > 0, daysInCycle > 0 else {
            return mtdBytes
        }

        let projected = Double(mtdBytes) / Double(daysElapsed) * Double(daysInCycle)
        guard projected.isFinite else {
            return mtdBytes
        }

        if projected >= Double(Int64.max) {
            return Int64.max
        }
        if projected <= Double(Int64.min) {
            return Int64.min
        }
        return Int64(projected.rounded())
    }

    /// Compute cycle progress from a `BillingCycle`.
    static func cycleProgress(
        cycle: BillingCycle,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (daysElapsed: Int, daysInCycle: Int) {
        let elapsed = cycle.daysElapsed(on: now, calendar: calendar)
        let total = cycle.daysInCycle
        return (daysElapsed: elapsed, daysInCycle: total)
    }
}
