import SwiftUI

struct AdvancedToggleRow: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                HStack(alignment: .center, spacing: Spacing.s2) {
                    Text("Advanced 模式")
                        .font(.tally.bodyEm)
                        .tracking(Font.tallyTracking.body)
                        .foregroundStyle(Color.tally.fg1)
                    
                    Text("之後再開放")
                        .font(.tally.micro)
                        .tracking(Font.tallyTracking.caps)
                        .foregroundStyle(Color.tally.fg3)
                        .padding(.horizontal, Spacing.s1)
                        .padding(.vertical, 2)
                        .background(Color.tally.bgHover)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.r4))
                }
                
                Text("會看到 bundle id、process name、Mbps 等技術細節。")
                    .font(.tally.callout)
                    .tracking(Font.tallyTracking.callout)
                    .foregroundStyle(Color.tally.fg3)
            }
            
            Spacer(minLength: Spacing.s6)
            
            Toggle("", isOn: .constant(false))
                .toggleStyle(.switch)
                .disabled(true)
        }
        .opacity(0.5)
        .padding(.vertical, Spacing.s2)
    }
}

#Preview {
    AdvancedToggleRow()
        .padding()
        .background(Color.tally.bgApp)
}
