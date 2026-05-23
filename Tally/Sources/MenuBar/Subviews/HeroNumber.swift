import SwiftUI

struct HeroNumber: View {
    let monthToDateBytes: Int64
    let monthlyCapBytes: Int64?

    private var totalGB: Double {
        Double(monthToDateBytes) / 1_073_741_824
    }

    private var capGB: Double? {
        if let cap = monthlyCapBytes {
            return Double(cap) / 1_073_741_824
        }
        return nil
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // Main Month-To-Date Usage
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
                Text(String(format: "%.1f", totalGB))
                    .font(.tally.display)
                    .tracking(Font.tallyTracking.display)
                    .foregroundStyle(Color.tally.fg1)
                
                Text("GB")
                    .font(.tally.title2)
                    .tracking(Font.tallyTracking.title2)
                    .foregroundStyle(Color.tally.fg2)
            }
            
            Spacer()
            
            // Cap / Remaining Info
            VStack(alignment: .trailing, spacing: 2) {
                if let capGB {
                    let remaining = capGB - totalGB
                    if remaining >= 0 {
                        Text(String(format: "%.1f GB", remaining))
                            .font(.tally.bodyEm)
                            .tracking(Font.tallyTracking.body)
                            .foregroundStyle(Color.tally.fg1)
                        Text("還能用")
                            .font(.tally.caption)
                            .tracking(Font.tallyTracking.caption)
                            .foregroundStyle(Color.tally.fg3)
                    } else {
                        Text(String(format: "%.1f GB", abs(remaining)))
                            .font(.tally.bodyEm)
                            .tracking(Font.tallyTracking.body)
                            .foregroundStyle(Color.tally.danger)
                        Text("已超額")
                            .font(.tally.caption)
                            .tracking(Font.tallyTracking.caption)
                            .foregroundStyle(Color.tally.danger)
                    }
                } else {
                    Text("上限沒設定")
                        .font(.tally.bodyEm)
                        .tracking(Font.tallyTracking.body)
                        .foregroundStyle(Color.tally.fg3)
                    Text("流量無上限")
                        .font(.tally.caption)
                        .tracking(Font.tallyTracking.caption)
                        .foregroundStyle(Color.tally.fg3)
                }
            }
        }
    }
}

#Preview("Cap Set") {
    HeroNumber(monthToDateBytes: 12 * 1024 * 1024 * 1024, monthlyCapBytes: 20 * 1024 * 1024 * 1024)
        .padding()
        .frame(width: 320)
}

#Preview("No Cap") {
    HeroNumber(monthToDateBytes: 12 * 1024 * 1024 * 1024, monthlyCapBytes: nil)
        .padding()
        .frame(width: 320)
}

#Preview("Over Cap") {
    HeroNumber(monthToDateBytes: 22 * 1024 * 1024 * 1024, monthlyCapBytes: 20 * 1024 * 1024 * 1024)
        .padding()
        .frame(width: 320)
}
