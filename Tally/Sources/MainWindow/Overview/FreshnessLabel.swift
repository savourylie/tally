import SwiftUI

/// The "● 即時 / 更新於 X 前" line beneath the Today total — it tells the user
/// whether the number is live. Computes the age of the freshest sample from
/// `lastSampleTimestamp` (Unix seconds) and refreshes on a 30s `TimelineView`
/// cadence, so no manual timer is needed. Renders nothing when the timestamp is
/// `nil` (no samples yet). Reused by the popover in TICKET-031.
struct FreshnessLabel: View {
    let lastSampleTimestamp: Int64?

    var body: some View {
        if let lastSampleTimestamp {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                label(now: context.date, timestamp: lastSampleTimestamp)
            }
        }
    }

    @ViewBuilder
    private func label(now: Date, timestamp: Int64) -> some View {
        let age = now.timeIntervalSince1970 - Double(timestamp)
        if age < 10 {
            Text("● 即時")
                .font(.tally.caption)
                .tracking(Font.tallyTracking.caption)
                .foregroundStyle(Color.tally.success)
        } else {
            Text("更新於 \(relativeAge(age))")
                .font(.tally.caption)
                .tracking(Font.tallyTracking.caption)
                .foregroundStyle(Color.tally.fg3)
        }
    }

    private func relativeAge(_ age: TimeInterval) -> String {
        if age < 60 {
            return "\(Int(age)) 秒前"
        } else {
            return "\(Int(age / 60)) 分前"
        }
    }
}

#Preview("Live") {
    FreshnessLabel(lastSampleTimestamp: Int64(Date.now.timeIntervalSince1970))
        .padding()
        .background(Color.tally.bgApp)
}

#Preview("Stale") {
    FreshnessLabel(lastSampleTimestamp: Int64(Date.now.timeIntervalSince1970) - 90)
        .padding()
        .background(Color.tally.bgApp)
}

#Preview("Hidden (nil)") {
    FreshnessLabel(lastSampleTimestamp: nil)
        .padding()
        .background(Color.tally.bgApp)
}
