# [TICKET-007] Aggregation worker (with helper roll-up + retention)

## Status
`blocked`

## Dependencies
- Requires: #006

## Description
Roll raw `flow_samples` rows up into `daily_aggregates` by `(date, bundle_id | category, network_id)`. The aggregator runs on a schedule (or triggered by collector flushes) and must be idempotent — running it twice produces the same `daily_aggregates` state, not double-counted totals.

Two complications in PRD §12:
1. **Helper process roll-up**: Chrome's renderer processes show up as `Google Chrome Helper` / `Google Chrome Helper (Renderer)`. They should be attributed to the parent app (`com.google.Chrome`). Resolution path: `executable_name` / `bundle_id` → `LSCopyApplicationURLsForBundleIdentifier` → walk to parent bundle.
2. **Retention**: `flow_samples` is retained 7 days only; `daily_aggregates` is the long-term store. The aggregator owns the cleanup pass that deletes rows older than 7 days from `flow_samples`.

Without this aggregator the menu bar popover (TICKET-010) and Overview screen (TICKET-013) would have to scan all of `flow_samples` for every render — quickly unworkable as the database grows.

## Acceptance Criteria
- [ ] `Aggregator` runs on a periodic timer (every 5 minutes), idempotently producing `daily_aggregates` rows from `flow_samples`
- [ ] Idempotency: running the aggregator N times on the same input set produces the same `daily_aggregates` table state (no duplicates, no doubled totals)
- [ ] Helper processes roll up to their parent bundle: rows from `Google Chrome Helper` are credited to `com.google.Chrome` in `daily_aggregates` (and Safari Web Content → `com.apple.Safari`, Slack Helper → `com.tinyspeck.slackmacgap`, etc.)
- [ ] Retention pass: rows in `flow_samples` older than 7 days are deleted on each aggregator run; the deletion happens AFTER aggregation so no data is lost
- [ ] SQL spot-check passes: `SELECT date, SUM(total_in + total_out) FROM daily_aggregates GROUP BY date` totals approximately match `SELECT date(timestamp, 'unixepoch'), SUM(bytes_in + bytes_out) FROM flow_samples GROUP BY 1` for overlapping date ranges (allowing for retention deletion)
- [ ] First aggregation after boot completes within 10 seconds of collector startup so the UI doesn't sit in the `.collecting` state needlessly

## Implementation Notes
- **Files to create**: `Aggregation/Aggregator.swift`, `Aggregation/HelperProcessResolver.swift`
- **Idempotency strategy**: use the unique constraint `(date, bundle_id, category, network_id)` on `daily_aggregates` and `INSERT … ON CONFLICT … DO UPDATE SET total_in = excluded.total_in, total_out = excluded.total_out` — each run fully recomputes the aggregate for the affected dates, then upserts
- **Affected dates window**: aggregate dates touched in the last 24 hours (covers boot from yesterday's data). Don't re-aggregate all of history every cycle
- **Helper resolver**:
  - Maintain a cache `[String: String]` keyed by helper bundle id → parent bundle id
  - On unknown helper: use `LSCopyApplicationURLsForBundleIdentifier` to find the helper's `Bundle.main.bundlePath`; walk up until you hit the outer `.app` bundle and read its `CFBundleIdentifier`
  - Known patterns to special-case (cheaper than LS lookup): `*.Chrome Helper*`, `com.google.Chrome.helper*`, `com.apple.WebKit.*`, `com.tinyspeck.slackmacgap.helper*`
- **Category attribution**: if `bundle_id` is unknown but `executable_name` matches a row in `process_categories`, write `daily_aggregates.category = <category_name>` and leave `bundle_id` NULL. This unlocks TICKET-015 grouping
- **Scheduling**: use a `Task { while !Task.isCancelled { … } }` driven by an `AsyncTimerSequence`, owned by `AppState`. Stop on app termination
- **Logging**: `Log.agg` with row counts in/out, run duration, helper resolution misses (for future mapping additions per PRD §8 last line)

## Testing
- Run the app for 10 minutes browsing Safari + Slack + Chrome (open Chrome and load multiple tabs) → `daily_aggregates` for today has rows for `com.apple.Safari`, Slack's bundle, `com.google.Chrome`. **No row exists for `Google Chrome Helper`** — its bytes should appear under `com.google.Chrome`
- Run the aggregator twice in close succession (force via debug menu or a Bash kill + relaunch) → `daily_aggregates` row counts and totals don't change
- Set system clock forward 8 days → relaunch → rows in `flow_samples` from before the original date are deleted; `daily_aggregates` is intact
- Aggregator log shows ≥1 unknown-helper miss for an obscure helper → confirm helper resolver caches it; second run on the same helper logs no miss
