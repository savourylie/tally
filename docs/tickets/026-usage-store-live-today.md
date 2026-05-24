# [TICKET-026] UsageStore: live "today" total + freshness timestamp

## Status
`pending`

## Dependencies
- Requires: #009 ✅

## Description
The app currently surfaces only a month-to-date number, and the user can't tell whether what's on screen is live or minutes old. This ticket adds a near-live "today" figure and a freshness signal to the shared `UsageStore`.

"Today" must not wait on the 5-minute aggregation roll-up — it reads directly from the `flow_samples` table (full Unix-timestamp rows, retained 7 days, drained by the collector every ~5s). The freshness signal is `MAX(flow_samples.timestamp)` — the most recent sample we've seen — which the UI renders as "● 即時 / 更新於 X 前". This is the data-layer half; the views land in #028.

The work mirrors the existing cycle-aware `ValueObservation` pattern in `UsageStore` (`startObservation()`, lines ~84-145) by adding a **second, independent observation** started in `start()` and cancelled in `deinit`. Crucially, `flow_samples`-derived values must never be summed with `daily_aggregates`-derived values — the latter is *derived from* the former, so adding them double-counts (see #027 for the today-bar substitution that depends on this).

## Acceptance Criteria
- [ ] `UsageStore` gains `private(set) var todayBytes: BytePair = .zero` and `private(set) var lastSampleTimestamp: Int64? = nil`, both `@Observable`
- [ ] A second `ValueObservation` queries `flow_samples` for `SUM(bytes_in)`, `SUM(bytes_out)`, `MAX(timestamp)` where `timestamp >= startOfToday`, with the bound = `Int64(Calendar.current.startOfDay(for: .now).timeIntervalSince1970)`
- [ ] The observation is started in `start()` and its cancellable torn down in `deinit` alongside the existing `cancellable`
- [ ] `lastSampleTimestamp` is `nil` when the table has no rows (fresh install) — not `0`
- [ ] SQL is factored into a `static`/`nonisolated` query function callable from tests via `dbPool.read { … }` without constructing the full `@MainActor` store

## Implementation Notes
- **Files to modify**: `Tally/Sources/Stores/UsageStore.swift`; **create** `TallyTests/UsageStoreQueryTests.swift`
- Reuse the `.start(in:scheduling:.immediate,onError:onChange:)` shape already used at `UsageStore.swift:135-144`; route `onChange` to a small handler that assigns `todayBytes` / `lastSampleTimestamp` on the main actor
- `flow_samples.timestamp` is Unix-epoch seconds (`FlowSample.swift`); the `idx_flow_samples_timestamp` index makes the range scan cheap
- Timezone: use `Calendar.current` to match the Aggregator's `date(timestamp,'unixepoch','localtime')` convention — do **not** introduce UTC
- **Test pattern**: copy the temp on-disk `DatabasePool` + `Migrations.makeMigrator().migrate()` setUp/tearDown from `TallyTests/NEFlowCollectorTests.swift:11-23`; insert `flow_samples` rows straddling local midnight and assert today's sum excludes yesterday and `MAX(timestamp)` returns the freshest row

## Testing
- `xcodebuild test -project Tally.xcodeproj -scheme Tally -only-testing:TallyTests/UsageStoreQueryTests`
- Manual: run the app with active traffic; confirm `todayBytes` climbs within seconds (not on a 5-min cadence) via a temporary debug log of `todayBytes`/`lastSampleTimestamp`
