import SwiftUI
import ServiceManagement

struct AutostartRow: View {
    @Bindable var preferences: Preferences
    @State private var showError = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("開機自動啟動 Tally")
                        .font(.tally.bodyEm)
                        .tracking(Font.tallyTracking.body)
                        .foregroundStyle(Color.tally.fg1)
                    
                    Text("登入時自動打開，不會跳到前景。")
                        .font(.tally.callout)
                        .tracking(Font.tallyTracking.callout)
                        .foregroundStyle(Color.tally.fg3)
                }
                
                Spacer(minLength: Spacing.s6)
                
                Toggle("", isOn: Binding(
                    get: { preferences.autostart },
                    set: { newValue in
                        preferences.autostart = newValue
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                                Log.ui.info("AutostartRow: Registered SMAppService.mainApp")
                            } else {
                                try SMAppService.mainApp.unregister()
                                Log.ui.info("AutostartRow: Unregistered SMAppService.mainApp")
                            }
                            showError = false
                        } catch {
                            Log.ui.error("AutostartRow: Failed to register/unregister SMAppService: \(error.localizedDescription)")
                            showError = true
                        }
                    }
                ))
                .toggleStyle(.switch)
            }
            
            if showError {
                Text("無法設定，請手動到系統設定打開")
                    .font(.tally.caption)
                    .tracking(Font.tallyTracking.caption)
                    .foregroundStyle(Color.tally.danger)
                    .padding(.top, Spacing.s1)
            }
        }
        .padding(.vertical, Spacing.s2)
        .onAppear {
            let status = SMAppService.mainApp.status
            let isCurrentlyRegistered = (status == .enabled)
            if isCurrentlyRegistered != preferences.autostart {
                preferences.autostart = isCurrentlyRegistered
            }
        }
    }
}

#Preview {
    AutostartRow(preferences: Preferences())
        .padding()
        .background(Color.tally.bgApp)
}
