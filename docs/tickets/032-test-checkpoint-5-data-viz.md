# [TICKET-032] TEST: Checkpoint 5 — Data Visualization End-to-End

## Status
`blocked`

## Dependencies
- Requires: #030 ✅, #031 ✅, #033 ✅, #034

## Description
Phase 6 (TICKET-025 through TICKET-031) added the data-visualization layer: a shared byte formatter, live "today" + freshness + week/trend queries in `UsageStore`, the TodayCard / FreshnessLabel / WeekMonthSummary components, the Swift Charts daily trend chart, the Overview wiring, and the popover freshness line + sparkline. This checkpoint verifies the whole experience hangs together and that the four original user complaints are resolved.

It gates closing out the visualization work. The two correctness risks flagged during design get explicit test cases: (1) no double-counting between `flow_samples`-derived and `daily_aggregates`-derived figures, and (2) the trend's "today" bar agreeing with the live TodayCard. It also includes a voice audit, consistent with this project's standing rule that users never see technical identifiers or English networking jargon.

Passing this checkpoint means the data-visualization feature is shippable.

## Bug Findings
Manual verification on 2026-05-25 found that the live DB had no current-day `flow_samples`: the latest live row was 2026-05-23 15:39 HKT while testing active traffic on 2026-05-25. Chrome traffic, including YouTube playback, was not represented in the app list. This checkpoint is blocked until #033 and #034 restore production live collection and Chrome attribution.

## Acceptance Criteria
- [ ] **Today is live**: with active traffic, TodayCard's ↓/↑ figures climb within seconds (not on a 5-min cadence); the freshness label reads "● 即時" while traffic flows
- [ ] **Freshness when idle**: stop traffic for >1 min → label transitions to "更新於 X 分前"; on a fresh/empty DB the label is hidden (not "更新於 0 秒前")
- [ ] **Surfaces agree**: the popover freshness line and the Overview freshness label show the same age at the same moment; today's trend bar equals the TodayCard total
- [ ] **No double-counting**: sum of all trend bars over the current cycle reconciles with the hero month-to-date (within rounding); `flow_samples` today is never added to `daily_aggregates` today
- [ ] **Window switch**: trend picker 本期 ↔ 近 30 天 re-ranges the bars; gap days render as zero bars, not missing bars
- [ ] **Week/Month tiles**: 本週 = last-7-days `daily_aggregates` sum; 本月 = hero MTD; spot-checked against SQL
- [ ] **Charts render in both themes**: trend chart + sparkline display correctly in light and dark; empty state shows "資料正在收集中"
- [ ] **Voice audit**: no English networking/technical terms or identifiers in any displayed string across the new views

## Implementation Notes
This is a manual test execution ticket — no code changes unless bugs are found during testing.

Common failure modes to watch for:
- **Today bar disagrees with TodayCard**: the #027 substitution didn't run, or ran against the wrong date key (timezone) — verify `Calendar.current.startOfDay` epoch matches the aggregate's `'localtime'` date string
- **Double-counted total**: trend bars summing higher than MTD usually means `flow_samples` today was *added* to the aggregate row instead of *replacing* it
- **Freshness stuck**: `TimelineView(.periodic)` not driving recompute, or `lastSampleTimestamp` not republished — confirm both observations route through one `onChange`
- **Chart blank on macOS 14**: `import Charts` missing or a stray `@available` guard; the target is 14.0, Charts needs 13+, so no guard is needed

Test environment: a Mac with normal browsing activity for ≥30 min prior so `daily_aggregates` has several days of history and `flow_samples` has live rows.

## Testing
1. `xcodebuild test -project Tally.xcodeproj -scheme Tally -only-testing:TallyTests/UsageStoreQueryTests -only-testing:TallyTests/ByteFormatTests` → all green
2. `xcodebuild -project Tally.xcodeproj -scheme Tally build` → clean build, no warnings from the new files
3. Launch → Overview: confirm section order and that TodayCard tracks live traffic; watch freshness flip 即時 → 更新於 X 前 after idling
4. Flip the trend picker; verify re-ranging and zero-fill of gap days
5. SQL reconciliation:
   ```bash
   sqlite3 ~/Library/Application\ Support/Tally/tally.sqlite \
     "SELECT date, SUM(total_in+total_out) FROM daily_aggregates WHERE date >= <cycle_start> GROUP BY date ORDER BY date;"
   ```
   — sum across days ≈ hero MTD; per-day ≈ trend bars (today bar may exceed its aggregate row by the live delta — expected)
6. Open popover → freshness line + sparkline present and agree with Overview; sparkline hidden while `.collecting`
7. Voice audit:
   ```bash
   rg -i '\b(mDNSResponder|bundle id|bundle_id|throughput|upload|download|tethering|SSID|Mbps)\b' \
     Tally/Sources/MainWindow/Overview Tally/Sources/MenuBar
   ```
   — zero hits in any `Text(...)` / `LocalizedStringKey` content
8. Toggle dark mode across both surfaces → tokens swap cleanly
9. Record results per criterion in the PR. On full pass, mark `done` — Phase 6 complete
