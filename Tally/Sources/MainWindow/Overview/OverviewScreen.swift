import SwiftUI

struct OverviewScreen: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let store = appState.usageStore
        let totalBytes = store.monthToDateBytes.bytesIn + store.monthToDateBytes.bytesOut

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HeroCard(
                    state: store.state,
                    monthToDateBytes: store.monthToDateBytes,
                    monthlyCapBytes: store.monthlyCapBytes
                )

                StatusLine(connection: store.currentNetwork)

                EstimateSentence(
                    monthToDateBytes: totalBytes,
                    monthlyCapBytes: store.monthlyCapBytes,
                    previousCycleTotalBytes: store.previousCycleTotalBytes
                )

                TopAppsSection(
                    entries: store.topApps(limit: 10),
                    totalCycleBytes: totalBytes
                )
            }
            .padding(.horizontal, Spacing.s8)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    OverviewScreen()
        .frame(width: MainWindowLayout.contentWidth, height: MainWindowLayout.windowHeight)
        .environment(AppState())
}
