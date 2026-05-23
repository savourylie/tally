import SwiftUI

struct AlertRow: View {
    @Bindable var preferences: Preferences

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("快用完時提醒我")
                    .font(.tally.bodyEm)
                    .tracking(Font.tallyTracking.body)
                    .foregroundStyle(Color.tally.fg1)
                
                Text("用了一定比例之後 Tally 會跳通知。")
                    .font(.tally.callout)
                    .tracking(Font.tallyTracking.callout)
                    .foregroundStyle(Color.tally.fg3)
            }
            
            Spacer(minLength: Spacing.s6)
            
            HStack(spacing: Spacing.s4) {
                Toggle("80%", isOn: $preferences.alertAt80)
                    .toggleStyle(.checkbox)
                    .font(.tally.body)
                    .tracking(Font.tallyTracking.body)
                
                Toggle("95%", isOn: $preferences.alertAt95)
                    .toggleStyle(.checkbox)
                    .font(.tally.body)
                    .tracking(Font.tallyTracking.body)
                
                Toggle("100%", isOn: $preferences.alertAt100)
                    .toggleStyle(.checkbox)
                    .font(.tally.body)
                    .tracking(Font.tallyTracking.body)
            }
        }
        .padding(.vertical, Spacing.s2)
    }
}

#Preview {
    AlertRow(preferences: Preferences())
        .padding()
        .background(Color.tally.bgApp)
}
