import SwiftUI

/// Today's usage split into received (↓) and sent (↑), each via
/// `ByteFormat.adaptive`, with a `FreshnessLabel` beneath. Presentation-only —
/// driven by `UsageStore.todayBytes` / `lastSampleTimestamp` once wired into the
/// Overview (TICKET-030). Follows the bordered card language of `HeroCard`.
struct TodayCard: View {
    let today: UsageStore.BytePair
    let lastSampleTimestamp: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("今天")
                .font(.tally.callout)
                .tracking(Font.tallyTracking.callout)
                .foregroundStyle(Color.tally.fg3)

            usageRow(symbol: "arrow.down", label: "收到", bytes: today.bytesIn, tint: Color.tally.brand400)
            usageRow(symbol: "arrow.up", label: "送出", bytes: today.bytesOut, tint: Color.tally.fg2)

            FreshnessLabel(lastSampleTimestamp: lastSampleTimestamp)
                .padding(.top, Spacing.s1)
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

    private func usageRow(symbol: String, label: String, bytes: Int64, tint: Color) -> some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: symbol)
                .font(.tally.body)
                .foregroundStyle(tint)
            Text(label)
                .font(.tally.body)
                .tracking(Font.tallyTracking.body)
                .foregroundStyle(Color.tally.fg2)

            Spacer()

            Text(ByteFormat.adaptive(bytes))
                .font(.tally.title3)
                .monospacedDigit()
                .tracking(Font.tallyTracking.title3)
                .foregroundStyle(tint)
        }
    }
}

#Preview("Live") {
    TodayCard(
        today: UsageStore.BytePair(bytesIn: 2_576_980_378, bytesOut: 322_122_547),
        lastSampleTimestamp: Int64(Date.now.timeIntervalSince1970)
    )
    .padding()
    .frame(width: 320)
    .background(Color.tally.bgApp)
}

#Preview("Nil freshness") {
    TodayCard(
        today: UsageStore.BytePair(bytesIn: 5_000_000, bytesOut: 1_200_000),
        lastSampleTimestamp: nil
    )
    .padding()
    .frame(width: 320)
    .background(Color.tally.bgApp)
}
