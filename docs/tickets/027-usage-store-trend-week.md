# [TICKET-027] UsageStore: week/month totals + daily trend series

## Status
`blocked`

## Dependencies
- Requires: #026

## Description
This ticket adds the historical data the visualization needs: a "this week" total and a per-day trend series for the bar chart. Both come from `daily_aggregates`, which already stores `total_in`/`total_out` per day, per app/category/network, **indefinitely** — so no schema change is required.

It extends the second `ValueObservation` introduced in #026 (same observation block, additional fetches) so all viz state updates atomically. The trend query groups by `date` over a selectable window; missing days are zero-filled in Swift so the chart shows continuous bars. A `trendWindow` property lets the chart's picker switch between the current billing cycle and the last 30 days, restarting the observation on change (reusing the `withObservationTracking` loop pattern at `UsageStore.swift:149-169`).

The one correctness hazard: `daily_aggregates` for *today* lags up to 5 minutes, while #026's `todayBytes` is live. To keep the chart consistent with the TodayCard and avoid a visibly stale "today" bar, the trend's today entry is **substituted** with `todayBytes` (replace, never add — adding would double-count since aggregates derive from samples).

## Acceptance Criteria
- [ ] New model `DailyUsage: Identifiable, Equatable, Sendable` (`date: Date`, `bytesIn/bytesOut: Int64`, computed `total`) in `Tally/Sources/Stores/DailyUsage.swift`
- [ ] `UsageStore` gains `private(set) var weekBytes: BytePair`, `private(set) var dailyTrend: [DailyUsage]`, and `var trendWindow: TrendWindow` (enum `.currentCycle` / `.last30Days`, default `.currentCycle`)
- [ ] Trend query: `SELECT date, SUM(total_in), SUM(total_out) FROM daily_aggregates WHERE date >= ? AND date <= ? GROUP BY date ORDER BY date ASC`, reusing the existing `dateWindow(from:)` + `dateFormatter`; days with no row are zero-filled
- [ ] Week query sums `daily_aggregates` over `now-6d … today`; "month" reuses the existing `monthToDateBytes` (no new query)
- [ ] The `dailyTrend` entry for today is replaced by `todayBytes` (substitution, not addition) so it matches the TodayCard
- [ ] Changing `trendWindow` restarts/refreshes the observation and republishes `dailyTrend`; covered by `UsageStoreQueryTests`

## Implementation Notes
- **Files to modify/create**: `Tally/Sources/Stores/UsageStore.swift`, `Tally/Sources/Stores/DailyUsage.swift`; extend `TallyTests/UsageStoreQueryTests.swift`
- `.last30Days` bounds = `dateFormatter.string(from: now-29d)` … `now`; convert SQL `date` strings back to `Date` via the same private `dateFormatter` for `DailyUsage.date` (local midnight)
- Keep the trend/week fetches inside the **same** observation block as #026's today fetch so a single `onChange` republishes a coherent snapshot; do the today-bar substitution in that handler
- **Never** base any multi-day figure on `flow_samples` (pruned to 7 days) — only `daily_aggregates` for week/month/trend
- Factor each query into a `static`/`nonisolated` function for direct test access

## Testing
- `xcodebuild test -project Tally.xcodeproj -scheme Tally -only-testing:TallyTests/UsageStoreQueryTests`
- Assert: trend groups + sums per date and zero-fills a gap day; week bounds match `now-6d … today`; today's trend entry equals `todayBytes`, not the aggregate row; switching `trendWindow` changes the returned date range
