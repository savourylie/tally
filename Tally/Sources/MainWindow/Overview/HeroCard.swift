import SwiftUI

struct HeroCard: View {
    let state: UsageStore.State
    let monthToDateBytes: UsageStore.BytePair
    let monthlyCapBytes: Int64?
    /// TICKET-033: when set, the collecting state shows this honest, non-live
    /// recovery message instead of the generic "資料正在收集中".
    var unavailableReason: String? = nil
    var now: Date = .now

    private var totalBytes: Int64 {
        monthToDateBytes.bytesIn + monthToDateBytes.bytesOut
    }

    private var totalGB: Double {
        Double(totalBytes) / 1_073_741_824
    }

    private var capGB: Double? {
        guard let monthlyCapBytes, monthlyCapBytes > 0 else { return nil }
        return Double(monthlyCapBytes) / 1_073_741_824
    }

    private var progressValue: Double {
        guard let monthlyCapBytes, monthlyCapBytes > 0 else { return 0 }
        return Double(totalBytes) / Double(monthlyCapBytes)
    }

    var body: some View {
        Group {
            if state == .collecting {
                collectingBody
            } else {
                readyBody
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .padding(Spacing.s5)
        .background(Color.tally.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.r12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.r12, style: .continuous)
                .stroke(Color.tally.border, lineWidth: 1)
        }
    }

    private var readyBody: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("這個月用了")
                .font(.tally.callout)
                .tracking(Font.tallyTracking.callout)
                .foregroundStyle(Color.tally.fg3)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
                Text(String(format: "%.1f", totalGB))
                    .font(.tally.mega)
                    .tracking(Font.tallyTracking.mega)
                    .foregroundStyle(Color.tally.fg1)

                Text("GB")
                    .font(.tally.title2)
                    .tracking(Font.tallyTracking.title2)
                    .foregroundStyle(Color.tally.fg2)
            }

            subtext

            if capGB != nil {
                ProgressBar(value: progressValue)
                    .padding(.top, Spacing.s2)
            }
        }
    }

    private var collectingBody: some View {
        Text(unavailableReason ?? "資料正在收集中")
            .font(.tally.title3)
            .fontWeight(.regular)
            .tracking(Font.tallyTracking.title3)
            .foregroundStyle(Color.tally.fg2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var subtext: some View {
        if let capGB {
            let remainingGB = max(capGB - totalGB, 0)
            (
                Text("還可以用 ").font(.tally.callout)
                + Text(String(format: "%.1f GB", remainingGB)).font(.tally.callout.weight(.semibold))
                + Text("（到 \(resetDateString) 重置）").font(.tally.callout)
            )
            .tracking(Font.tallyTracking.callout)
            .foregroundStyle(Color.tally.fg2)
        } else {
            Text("（還沒設定上限）")
                .font(.tally.callout)
                .tracking(Font.tallyTracking.callout)
                .foregroundStyle(Color.tally.fg2)
        }
    }

    private var resetDateString: String {
        let calendar = Calendar.current
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now
        let resetDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let parts = calendar.dateComponents([.month, .day], from: resetDate)
        return "\(parts.month ?? 1) 月 \(parts.day ?? 1) 日"
    }
}

#Preview("Collecting") {
    HeroCard(
        state: .collecting,
        monthToDateBytes: .zero,
        monthlyCapBytes: 20 * 1024 * 1024 * 1024
    )
    .padding()
    .frame(width: 696)
    .background(Color.tally.bgApp)
}

#Preview("Ready") {
    HeroCard(
        state: .ready,
        monthToDateBytes: UsageStore.BytePair(bytesIn: 6 * 1024 * 1024 * 1024, bytesOut: 6_442_450_944),
        monthlyCapBytes: 20 * 1024 * 1024 * 1024
    )
    .padding()
    .frame(width: 696)
    .background(Color.tally.bgApp)
}

#Preview("Near Cap") {
    HeroCard(
        state: .ready,
        monthToDateBytes: UsageStore.BytePair(bytesIn: 15 * 1024 * 1024 * 1024, bytesOut: 4_831_838_208),
        monthlyCapBytes: 20 * 1024 * 1024 * 1024
    )
    .padding()
    .frame(width: 696)
    .background(Color.tally.bgApp)
}

#Preview("No Cap") {
    HeroCard(
        state: .ready,
        monthToDateBytes: UsageStore.BytePair(bytesIn: 6 * 1024 * 1024 * 1024, bytesOut: 6_442_450_944),
        monthlyCapBytes: nil
    )
    .padding()
    .frame(width: 696)
    .background(Color.tally.bgApp)
}
