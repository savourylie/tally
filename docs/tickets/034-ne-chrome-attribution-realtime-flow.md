# [TICKET-034] Chrome attribution + realtime NE flow rows

## Status
`done`

## Dependencies
- Requires: #033 ✅

## Description
After collection health is explicit, verify and fix the realtime production NE flow path that feeds visualization. The #032 manual test found two user-visible failures: Chrome/YouTube traffic did not create current chart data, and Chrome was absent from the top-app list even though it was the active high-traffic app.

This ticket keeps the production Network Extension path as the source of truth. The extension should produce `flow_samples` within seconds while traffic is active, and aggregation should credit Chrome helper traffic to `com.google.Chrome` instead of `系統其他`.

## Acceptance Criteria
- [x] Watching YouTube in Chrome from `/Applications/Tally.app` creates new `flow_samples` rows within seconds
- [x] The TodayCard ↓/↑ figures climb while Chrome traffic is active, and the freshness label reads `● 即時`
- [x] Today's trend bar matches the TodayCard total because both use live `flow_samples`
- [x] `TallyFilterDataProvider` preserves statistics-report metering for allowed flows and records only positive byte deltas
- [x] Chrome helper/process traffic resolves to `com.google.Chrome` before aggregation
- [x] After aggregation, `daily_aggregates` includes a non-zero `com.google.Chrome` row for the test date
- [x] Chrome appears in the top-app list whenever its aggregate total is high enough to be in the visible list
- [x] System or daemon traffic that cannot be mapped still falls back to existing categories without leaking technical identifiers in UI strings

## Implementation Notes
- Audit `TallyFilterDataProvider.handleNewFlow(_:)` and `handle(_:)` against macOS `NEFilterReport` behavior; keep `.statisticsReportFrequency = .low` unless testing proves a different supported frequency is needed.
- Use macOS audit-token attribution in the extension: prefer `sourceAppAuditToken`, then `sourceProcessAuditToken`.
- Keep helper roll-up in the host aggregation layer through `HelperProcessResolver`, including Chrome helper prefixes mapping to `com.google.Chrome`.
- `NEFlowCollector` should continue draining the App Group event log and call `Aggregator.runOnce()` after inserts so top apps catch up quickly.

## Testing
1. `xcodebuild test -project Tally.xcodeproj -scheme Tally -only-testing:TallyTests/NEFlowCollectorTests -only-testing:TallyTests/UsageStoreQueryTests`
2. Add or update unit coverage for Chrome helper roll-up to `com.google.Chrome`
3. `xcodebuild -project Tally.xcodeproj -scheme Tally build`
4. Manual test from `/Applications/Tally.app`: stream YouTube in Chrome for 15-30 seconds, then confirm:
   ```bash
   sqlite3 ~/Library/Application\ Support/Tally/tally.sqlite \
     "SELECT datetime(MAX(timestamp),'unixepoch','localtime'), COUNT(*), SUM(bytes_in+bytes_out) FROM flow_samples WHERE timestamp >= strftime('%s','now','localtime','start of day','utc');"
   ```
5. Confirm aggregation credits Chrome:
   ```bash
   sqlite3 ~/Library/Application\ Support/Tally/tally.sqlite \
     "SELECT date, bundle_id, SUM(total_in+total_out) FROM daily_aggregates WHERE bundle_id = 'com.google.Chrome' GROUP BY date, bundle_id ORDER BY date DESC;"
   ```
6. Open Overview → TodayCard climbs, freshness is live, today's chart bar agrees, and Chrome appears in top apps when its usage ranks high enough
