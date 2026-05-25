import SwiftUI
import Charts

/// A tiny, axis-less amber sparkline of recent daily usage totals, shown in the
/// menu-bar popover above the top-apps list (TICKET-031). Presentation-only: it
/// reads the same `[DailyUsage]` series the Overview's DailyTrendChart uses
/// (`store.dailyTrend`) and plots each day's `total`. Soft brand400 area fill
/// under a crisp brand400 line; no axes, legend, or labels — a quiet glanceable
/// trend that fits the 320pt popover.
struct Sparkline: View {
    let trend: [DailyUsage]
    private let height: CGFloat = 28

    var body: some View {
        Chart(trend) { day in
            AreaMark(
                x: .value("日期", day.date, unit: .day),
                y: .value("用量", ByteFormat.gigabytesValue(day.total))
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.tally.brand400.opacity(0.28),
                             Color.tally.brand400.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )

            LineMark(
                x: .value("日期", day.date, unit: .day),
                y: .value("用量", ByteFormat.gigabytesValue(day.total))
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.tally.brand400)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: height)
    }
}

// MARK: - Previews

private func sparklineMockTrend() -> [DailyUsage] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    return (0..<14).map { offset in
        let date = cal.date(byAdding: .day, value: -(13 - offset), to: today) ?? today
        return DailyUsage(
            date: date,
            bytesIn: Int64(300_000_000 + (offset % 7) * 180_000_000),
            bytesOut: Int64(40_000_000 + (offset % 5) * 30_000_000)
        )
    }
}

#Preview("Sparkline") {
    Sparkline(trend: sparklineMockTrend())
        .frame(width: 292)
        .padding()
        .background(Color.tally.bgPopover)
}
