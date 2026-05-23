import SwiftUI

struct CycleDayRow: View {
    @Bindable var preferences: Preferences

    private var shouldShowHint: Bool {
        if preferences.cycleStartDay == 31 {
            let calendar = Calendar.current
            let now = Date()
            if let range = calendar.range(of: .day, in: .month, for: now) {
                return range.count < 31
            }
            return true
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("每月從幾號開始算")
                        .font(.tally.bodyEm)
                        .tracking(Font.tallyTracking.body)
                        .foregroundStyle(Color.tally.fg1)
                    
                    Text("和你的網路帳單對齊。預設是每月 1 號。")
                        .font(.tally.callout)
                        .tracking(Font.tallyTracking.callout)
                        .foregroundStyle(Color.tally.fg3)
                }
                
                Spacer(minLength: Spacing.s6)
                
                Picker("", selection: $preferences.cycleStartDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day) 號").tag(day)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            
            if shouldShowHint {
                Text("若該月沒有 31 號，會用月底最後一天")
                    .font(.tally.caption)
                    .tracking(Font.tallyTracking.caption)
                    .foregroundStyle(Color.tally.warning)
                    .padding(.top, Spacing.s1)
            }
        }
        .padding(.vertical, Spacing.s2)
    }
}

#Preview {
    CycleDayRow(preferences: Preferences())
        .padding()
        .background(Color.tally.bgApp)
}
