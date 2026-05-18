# [TICKET-009] UsageStore (@Observable)

## Status
`blocked`

## Dependencies
- Requires: #007, #008

## Description
The `UsageStore` is the single source of truth for "what does the user see right now". The menu bar popover and the main window both subscribe to one shared instance per PRD §10 ("menu bar 和 main window 共用同一個 store"). It exposes:

- Month-to-date total bytes in / out for the current billing cycle (TICKET-019 refines cycle math; until then this defaults to the calendar month)
- Top N apps by total bytes, with `AppMetadata` resolved
- Current network display string (placeholder until TICKET-019 wires actual network detection)
- A coarse `state: .collecting | .ready` for the first-run empty-state UX (PRD §9 last paragraph: "資料正在收集中，數據會在幾分鐘後開始顯示")

The store is `@Observable` so SwiftUI automatically re-renders when GRDB writes new aggregate rows. The store does not poll the database — it subscribes to `ValueObservation` on `daily_aggregates`.

## Acceptance Criteria
- [ ] `UsageStore` is `@Observable` and constructed once, stored on `AppState` (replacing the placeholder slot from TICKET-004)
- [ ] `usageStore.monthToDateBytes: (in: Int, out: Int)` recomputes when `daily_aggregates` changes
- [ ] `usageStore.topApps(limit: Int) -> [AppUsageEntry]` returns the top N entries, each containing `AppMetadata` (resolved via TICKET-008) and total bytes; system-category rows preserve their category metadata
- [ ] `usageStore.state` is `.collecting` when `daily_aggregates` has 0 rows for the current cycle, `.ready` once at least one row exists
- [ ] Updates from the aggregator (TICKET-007) propagate to the store within 500ms (GRDB `ValueObservation` default behavior is good enough)
- [ ] Both menu bar and main window read from the same instance — adding a temporary `id(ObjectIdentifier(store))` text in both surfaces produces identical values

## Implementation Notes
- **Files to create**: `Stores/UsageStore.swift`, `Stores/AppUsageEntry.swift`
- **`@Observable`**: requires Swift 5.9+ macro; the store is a `class`. SwiftUI views use `@Environment(UsageStore.self)` or pass via `.environment(_:)`
- **DB subscription**:
  ```swift
  ValueObservation
    .tracking { db in try DailyAggregate.fetchAll(db, sql: "...current cycle...") }
    .start(in: database.pool, scheduling: .immediate, onChange: { [weak self] rows in self?.recompute(rows) })
  ```
- **Current cycle window**: temporary placeholder `(startOfMonth(), today())`. TICKET-019 replaces this with `BillingCycle` calculations. Document the TODO clearly in code so reviewers know the swap point
- **Top N query**: aggregate over the cycle window grouped by `(bundle_id, category)`, order DESC by `total_in + total_out`. Resolve each row's metadata via `AppMetadataService` — prefer `bundle_id` lookup, fall back to category lookup
- **State transition**: `state` starts as `.collecting`; flips to `.ready` on the first non-empty observation result. Once `.ready`, never returns to `.collecting` (a temporary empty cycle should still show 0 GB, not "collecting")
- **Threading**: the store is main-actor-isolated since it drives UI; the GRDB observation schedules onto the main queue

## Testing
- Build + run (after Phase 1 + earlier Phase 2 tickets) → menu bar placeholder shows `state == .collecting`
- Wait 60 seconds (collector flush + aggregator run) → state flips to `.ready`; `monthToDateBytes` becomes non-zero
- Open main window placeholder → reads same store, same numbers
- Manually `DELETE FROM daily_aggregates;` then re-aggregate → store recomputes and updates UI within ~500ms
- Confirm `topApps(limit: 5)` returns entries with non-empty `displayName`, non-nil `icon`, and totals matching a SQL ground-truth query
