import SwiftUI

struct VPNNoteFooter: View {
    var body: some View {
        VStack(spacing: Spacing.s1) {
            Text("如果開了 VPN，Tally 沒辦法分開算每個 app 的流量")
                .font(.tally.caption)
                .tracking(Font.tallyTracking.caption)
                .foregroundStyle(Color.tally.fg3)
            
            Text("Tally v0.1 · MVP 一般模式 · 所有資料留在你的 Mac 上")
                .font(.tally.caption)
                .tracking(Font.tallyTracking.caption)
                .foregroundStyle(Color.tally.fg4)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, Spacing.s4)
    }
}

#Preview {
    VPNNoteFooter()
        .padding()
        .background(Color.tally.bgApp)
}
