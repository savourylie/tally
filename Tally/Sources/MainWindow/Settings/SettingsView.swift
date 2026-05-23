import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let preferences = appState.preferences

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("設定")
                    .font(.tally.title1)
                    .tracking(Font.tallyTracking.title1)
                    .foregroundStyle(Color.tally.fg1)
                    .padding(.bottom, Spacing.s4)
                
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    CycleDayRow(preferences: preferences)
                    
                    Divider()
                        .background(Color.tally.divider)
                    
                    CapRow(preferences: preferences)
                    
                    Divider()
                        .background(Color.tally.divider)
                    
                    AlertRow(preferences: preferences)
                    
                    Divider()
                        .background(Color.tally.divider)
                    
                    AutostartRow(preferences: preferences)
                    
                    Divider()
                        .background(Color.tally.divider)
                    
                    AdvancedToggleRow()
                    
                    Divider()
                        .background(Color.tally.divider)
                    
                    RerunOnboardingRow(preferences: preferences)
                    
                    VPNNoteFooter()
                }
            }
            .padding(Spacing.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    SettingsView()
        .frame(width: MainWindowLayout.contentWidth, height: MainWindowLayout.windowHeight)
        .environment(AppState())
}
