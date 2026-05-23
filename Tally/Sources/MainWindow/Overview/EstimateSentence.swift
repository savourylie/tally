import SwiftUI

struct EstimateSentence: View {
    let monthToDateBytes: Int64
    let monthlyCapBytes: Int64?
    let previousCycleTotalBytes: Int64
    var now: Date = .now

    private var displayBytes: Int64 {
        guard monthlyCapBytes != nil else {
            return previousCycleTotalBytes
        }

        let progress = EstimateCalculator.currentCalendarMonthProgress(now: now)
        return EstimateCalculator.projectedTotalBytes(
            mtdBytes: monthToDateBytes,
            daysElapsed: progress.daysElapsed,
            daysInCycle: progress.daysInCycle
        )
    }

    private var prefix: String {
        monthlyCapBytes == nil ? "上個月用了 " : "以目前的速度，月底大概會用到 "
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
                .font(.tally.body)
                .foregroundStyle(Color.tally.fg2)

            Text(Self.gigabytesString(for: displayBytes))
                .font(.tally.body.bold())
                .foregroundStyle(Color.tally.fg1)
        }
        .tracking(Font.tallyTracking.body)
    }

    private static func gigabytesString(for bytes: Int64) -> String {
        let gb = Double(bytes) / EstimateCalculator.bytesPerGigabyte
        return String(format: "%.1f GB", gb)
    }
}

#Preview("Estimate") {
    EstimateSentence(
        monthToDateBytes: 12 * 1024 * 1024 * 1024,
        monthlyCapBytes: 20 * 1024 * 1024 * 1024,
        previousCycleTotalBytes: 18 * 1024 * 1024 * 1024
    )
    .padding()
    .background(Color.tally.bgApp)
}

#Preview("No Cap") {
    EstimateSentence(
        monthToDateBytes: 12 * 1024 * 1024 * 1024,
        monthlyCapBytes: nil,
        previousCycleTotalBytes: 18 * 1024 * 1024 * 1024
    )
    .padding()
    .background(Color.tally.bgApp)
}
