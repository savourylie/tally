import SwiftUI

struct RerunOnboardingRow: View {
    @Bindable var preferences: Preferences
    @State private var showingConfirmation = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("重新跑一次 Onboarding")
                    .font(.tally.bodyEm)
                    .tracking(Font.tallyTracking.body)
                    .foregroundStyle(Color.tally.fg1)
                
                Text("重新走一次歡迎流程，包含 Network Extension 權限設定。")
                    .font(.tally.callout)
                    .tracking(Font.tallyTracking.callout)
                    .foregroundStyle(Color.tally.fg3)
            }
            
            Spacer(minLength: Spacing.s6)
            
            Button("啟動") {
                showingConfirmation = true
            }
            .buttonStyle(.bordered)
            .confirmationDialog(
                "確定要重新跑一次 Onboarding 嗎？",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("確定重新啟動", role: .destructive) {
                    preferences.onboardingComplete = false
                    Log.ui.info("RerunOnboardingRow: reset onboardingComplete to false")
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("這將會重新顯示首次啟動的歡迎與設定畫面。")
            }
        }
        .padding(.vertical, Spacing.s2)
    }
}

#Preview {
    RerunOnboardingRow(preferences: Preferences())
        .padding()
        .background(Color.tally.bgApp)
}
