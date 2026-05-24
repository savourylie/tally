import SwiftUI
import Charts

/// Daily network usage as stacked bars — received (收) under sent (發) — across a
/// window the user toggles between the current billing cycle and the last 30
/// days. Presentation-only: it reads a `[DailyUsage]` series and binds the
/// picker to a `UsageStore.TrendWindow`; the Overview hands it `store.dailyTrend`
/// and `$store.trendWindow` in TICKET-030. Follows the bordered card language of
/// `HeroCard` / `TodayCard`.
struct DailyTrendChart: View {
    let trend: [DailyUsage]
    @Binding var window: UsageStore.TrendWindow

    private let chartHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            header

            if trend.isEmpty {
                placeholder
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s5)
        .background(Color.tally.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.r12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.r12, style: .continuous)
                .stroke(Color.tally.border, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("每日用量")
                .font(.tally.callout)
                .tracking(Font.tallyTracking.callout)
                .foregroundStyle(Color.tally.fg3)

            Spacer()

            Picker("用量範圍", selection: $window) {
                ForEach(UsageStore.TrendWindow.allCases, id: \.self) { option in
                    Text(label(for: option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var chart: some View {
        Chart(trend) { day in
            BarMark(
                x: .value("日期", day.date, unit: .day),
                y: .value("GB", ByteFormat.gigabytesValue(day.bytesIn))
            )
            .foregroundStyle(by: .value("類型", "收"))

            BarMark(
                x: .value("日期", day.date, unit: .day),
                y: .value("GB", ByteFormat.gigabytesValue(day.bytesOut))
            )
            .foregroundStyle(by: .value("類型", "發"))
        }
        .chartForegroundStyleScale([
            "收": Color.tally.brand400,
            "發": Color.tally.brand200
        ])
        .chartYAxisLabel("GB")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: chartHeight)
    }

    private var placeholder: some View {
        Text("資料正在收集中")
            .font(.tally.title3)
            .fontWeight(.regular)
            .tracking(Font.tallyTracking.title3)
            .foregroundStyle(Color.tally.fg2)
            .frame(maxWidth: .infinity, minHeight: chartHeight, alignment: .center)
    }

    private func label(for window: UsageStore.TrendWindow) -> String {
        switch window {
        case .currentCycle: "本期"
        case .last30Days: "近 30 天"
        }
    }
}

// MARK: - Previews

private func mockTrend(days: Int) -> [DailyUsage] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    return (0 ..< days).map { offset in
        let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) ?? today
        // Deterministic pseudo-variation so the bars differ in height.
        let received = Int64(300_000_000 + (offset % 7) * 180_000_000 + (offset % 3) * 90_000_000)
        let sent = Int64(40_000_000 + (offset % 5) * 30_000_000)
        return DailyUsage(date: date, bytesIn: received, bytesOut: sent)
    }
}

#Preview("本期") {
    DailyTrendChart(trend: mockTrend(days: 30), window: .constant(.currentCycle))
        .padding()
        .frame(width: 696)
        .background(Color.tally.bgApp)
}

#Preview("近 30 天") {
    DailyTrendChart(trend: mockTrend(days: 30), window: .constant(.last30Days))
        .padding()
        .frame(width: 696)
        .background(Color.tally.bgApp)
}

#Preview("收集中") {
    DailyTrendChart(trend: [], window: .constant(.currentCycle))
        .padding()
        .frame(width: 696)
        .background(Color.tally.bgApp)
}
