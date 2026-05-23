import SwiftUI

struct TopAppsSection: View {
    let entries: [AppUsageEntry]
    let totalCycleBytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            // Section Header
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                Text("這個月用最多的")
                    .font(.tally.title3)
                    .tracking(Font.tallyTracking.title3)
                    .foregroundStyle(Color.tally.fg1)
                
                Text("— 點任一項看細節")
                    .font(.tally.caption)
                    .tracking(Font.tallyTracking.caption)
                    .foregroundStyle(Color.tally.fg3)
                
                Spacer()
                
                Text("依用量排序")
                    .font(.tally.caption)
                    .tracking(Font.tallyTracking.caption)
                    .foregroundStyle(Color.tally.fg3)
            }
            .padding(.bottom, Spacing.s1)

            // Rows List
            VStack(spacing: Spacing.s2) {
                ForEach(entries) { entry in
                    AppRow(entry: entry, totalCycleBytes: totalCycleBytes)
                }
            }
        }
    }
}
