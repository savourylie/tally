# [TICKET-006] nettop collector + FlowCollector protocol

## Status
`pending`

## Dependencies
- Requires: #005 ✅

## Description
Build the development-mode data collector that reads per-process byte counters from `nettop -P -x` and writes them to `flow_samples`. The PRD §10 explicitly states "開發初期可用 `nettop -P -x` 跑通 UI/資料 layer，最後再接 NE" — the entire UI and data layer is built and verified on top of `nettop` first, then TICKET-023 replaces this collector with a `NEFilterDataProvider`-backed implementation.

To make the future swap a drop-in change rather than a rewrite, this ticket also introduces a `FlowCollector` protocol. The nettop implementation conforms to it; the NE implementation in TICKET-023 will conform to the same protocol with no changes to downstream consumers (aggregator, store, UI).

`nettop -P` aggregates per-process; `-x` outputs no headers / machine-parseable; sampling cadence ~10s and a flush to the database every ~60s keeps writes batched.

## Acceptance Criteria
- [ ] `FlowCollector` protocol defines `start()`, `stop()`, and exposes `state: CollectorState` (`.idle | .running | .failed(Error)`) — observable so the UI can render `.collecting` placeholders
- [ ] `NettopCollector: FlowCollector` spawns `nettop -P -x -l 0` as a child `Process`, parses streaming stdout into per-process byte deltas, and writes them to `flow_samples` (with `bundle_id` resolved when possible, falling back to `executable_name`)
- [ ] Sample cadence ~10s; rows are batched and flushed to SQLite every ~60s (configurable internal constants — document the values)
- [ ] Collector survives `caffeinate` / sleep / wake: relaunches the underlying `Process` if it dies, with exponential backoff and a max of 5 retries before transitioning to `.failed`
- [ ] `AppState` (from TICKET-004) now stores a non-optional `collector: FlowCollector` and starts it on boot; stops on app termination
- [ ] Running the app for 1 minute produces non-zero rows in `flow_samples` corresponding to known active processes (e.g., `Safari`, `Spotify`)

## Implementation Notes
- **Files to create**: `Collectors/FlowCollector.swift` (protocol + `CollectorState`), `Collectors/NettopCollector.swift`, `Collectors/NettopParser.swift` (parsing logic, separate so it's unit-testable without launching `nettop`)
- **`nettop` invocation**: `nettop -P -x -k time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize -l 0` — only emit byte counters; `-l 0` runs continuously. `-J bytes_in,bytes_out` may be a cleaner alternative — verify on macOS 14
- **Parsing**: `nettop -x` output is CSV-like with per-process rows; treat the first column as process name + pid. Resolve `bundle_id` via `NSRunningApplication(processIdentifier:)?.bundleIdentifier` — fall back to executable name when bundle id is unavailable (daemons)
- **Network attribution**: until TICKET-019 wires the current network into the sample, write `network_id = NULL` or to a default `unknown` row in `networks`. Seed an `unknown` network row in TICKET-003's migration if not already present, or insert lazily here
- **Bytes deltas**: `nettop` reports cumulative counters per sample; the collector tracks per-pid baselines and writes deltas. Reset baselines on `nettop` process restart
- **Batching**: keep an in-memory buffer of rows; on the 60s flush tick or on shutdown, GRDB `inBatch { ... }` to insert
- **Logging**: use `Log.collector` from TICKET-004; log start, parse errors (rate-limited), restarts, and flush counts
- **Threading**: collector runs on a dedicated `DispatchQueue` or `Task` — never on the main actor. DB writes go through GRDB's pool

## Testing
- ⌘R → wait 60 seconds → `SELECT COUNT(*) FROM flow_samples;` returns ≥ 1
- `SELECT bundle_id, SUM(bytes_in + bytes_out) FROM flow_samples GROUP BY bundle_id ORDER BY 2 DESC LIMIT 5;` → reasonable list of recently active apps
- Kill the spawned `nettop` process via `pkill -f nettop` → collector logs restart, new samples appear within 30s
- Sleep + wake the Mac → samples continue without duplicates
- Disable Wi-Fi → samples for the active period drop to ~0; re-enable → samples resume
