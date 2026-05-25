import SwiftUI

struct OverviewScreen: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var store = appState.usageStore
        let totalBytes = store.monthToDateBytes.bytesIn + store.monthToDateBytes.bytesOut

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HeroCard(
                    state: store.state,
                    monthToDateBytes: store.monthToDateBytes,
                    monthlyCapBytes: store.monthlyCapBytes,
                    unavailableReason: store.collectionUnavailableReason
                )

                StatusLine(connection: store.currentNetwork)

                TodayCard(
                    today: store.todayBytes,
                    lastSampleTimestamp: store.lastSampleTimestamp
                )

                EstimateSentence(
                    monthToDateBytes: totalBytes,
                    monthlyCapBytes: store.monthlyCapBytes,
                    previousCycleTotalBytes: store.previousCycleTotalBytes,
                    currentCycle: store.currentCycle
                )

                WeekMonthSummary(
                    today: store.todayBytes,
                    week: store.weekBytes,
                    month: store.monthToDateBytes
                )

                DailyTrendChart(
                    trend: store.dailyTrend,
                    window: $store.trendWindow
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
