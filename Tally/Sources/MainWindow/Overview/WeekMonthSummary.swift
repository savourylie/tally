import SwiftUI

/// Three compact tiles — 今天 / 本週 / 本月 — giving period totals at a glance,
/// each via `ByteFormat.gigabytes`. Presentation-only: 今天 and 本週 come from the
/// live state added in TICKET-026/027, 本月 from the existing `monthToDateBytes`.
/// Wired into the Overview in TICKET-030.
struct WeekMonthSummary: View {
    let today: UsageStore.BytePair
    let week: UsageStore.BytePair
    let month: UsageStore.BytePair

    var body: some View {
        HStack(spacing: Spacing.s4) {
            tile(title: "今天", bytes: today.bytesIn + today.bytesOut)
            tile(title: "本週", bytes: week.bytesIn + week.bytesOut)
            tile(title: "本月", bytes: month.bytesIn + month.bytesOut)
        }
    }

    private func tile(title: String, bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Text(title)
                .font(.tally.caption)
                .tracking(Font.tallyTracking.caption)
                .foregroundStyle(Color.tally.fg3)

            Text(ByteFormat.gigabytes(bytes))
                .font(.tally.title3)
                .monospacedDigit()
                .tracking(Font.tallyTracking.title3)
                .foregroundStyle(Color.tally.fg1)
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
}

#Preview {
    WeekMonthSummary(
        today: UsageStore.BytePair(bytesIn: 2_576_980_378, bytesOut: 322_122_547),
        week: UsageStore.BytePair(bytesIn: 16_000_000_000, bytesOut: 3_000_000_000),
        month: UsageStore.BytePair(bytesIn: 50_000_000_000, bytesOut: 9_000_000_000)
    )
    .padding()
    .frame(width: 696)
    .background(Color.tally.bgApp)
}
