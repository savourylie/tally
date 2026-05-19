# [TICKET-004] Logger + AppState boot sequence

## Status
`done`

## Dependencies
- Requires: #003 ✅

## Description
Wire up structured logging and a single root `AppState` that owns the application's long-lived dependencies (`DatabaseManager`, the upcoming `UsageStore`, the upcoming collector lifecycle). The menu bar scene and the main window scene must both read from the same `AppState` instance — without this, each scene will end up instantiating its own store and the two surfaces will drift apart.

Logging uses Apple's `os.Logger` so output is filterable in Console.app and survives release builds. Every subsystem (DB, collector, aggregator, store, UI, notifications, NE) gets a named category up front; later tickets just reference `Log.collector`, `Log.store`, etc.

## Acceptance Criteria
- [x] `Log.swift` exposes named `Logger` instances under subsystem `app.tally` with categories: `db`, `collector`, `agg`, `store`, `ui`, `notif`, `ne`
- [x] `AppState` is constructed once in `TallyApp.init()` and injected into both the `MenuBarExtra` and `Window` scenes (via `@Environment` or `@State` on the App struct)
- [x] `AppState` exposes `database: DatabaseManager` (from TICKET-003) and placeholder slots for `usageStore` and `collector` (set to optionals or stubbed types that TICKET-006/009 will fill in)
- [x] Launching the app logs a single ordered boot sequence visible in Console.app: `[db] opened`, `[db] migrations done`, `[store] init`, `[collector] starting`
- [x] No global singletons leak: every subsystem receives its `DatabaseManager` through `AppState`, not by importing a shared instance

## Implementation Notes
- **Files to create**: `App/TallyApp.swift` (replacing the scaffolded `App.swift` from TICKET-001), `App/AppState.swift`, `Logging/Log.swift`
- **AppState shape**: a plain `@Observable` class with `let database`, `let usageStore: UsageStore?` (filled by TICKET-009), `let collector: FlowCollector?` (filled by TICKET-006). Use optionals as a tracer for "not yet wired" — TICKET-005 (Checkpoint 0) will verify the placeholders exist
- **Injection**: pass via `.environment(appState)` on each `Scene`; both scenes use `@Environment(AppState.self)` to read
- **os.Logger pattern**: `enum Log { static let collector = Logger(subsystem: "app.tally", category: "collector"); ... }`
- **Boot order**: open DB → run migrations → log success → construct store stub → log → construct collector stub → log. Do NOT start the actual collector polling yet; that's TICKET-006
- This ticket does NOT touch UI rendering beyond replacing the placeholder text from TICKET-001 with a more meaningful placeholder like `Text("AppState ready — db: \(appState.database != nil)")`

## Testing
- Build + run → Console.app filtered by `subsystem:app.tally` shows the 4-step boot log in order
- Force-crash before migrations (e.g., point `DatabaseManager` at an unwritable path temporarily) → log surfaces a `[db]` error with file path; revert
- Open the placeholder window from the menu bar — verify both surfaces share the same `AppState` instance (add a temporary `id(ObjectIdentifier(appState))` text and confirm identical values)
