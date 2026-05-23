# [TICKET-020] Notification engine

## Status
`done`

## Dependencies
- Requires: #017 ✅, #019 ✅

## Description
Schedule and fire local notifications at 80%, 95%, and 100% of the monthly cap. Each threshold can be individually disabled via Settings (TICKET-018); the 100% notification additionally signals "you've hit the cap" copy.

Critical per-cycle dedupe: each threshold fires **at most once per billing cycle**. If a user crosses 80% on day 10, gets the notification, then their usage temporarily drops below 80% (rare but possible via aggregator retention), and then climbs back above 80%, no second 80% notification fires until the next cycle begins.

The threshold engine reads `usageStore.monthToDateBytes` + `preferences.monthlyLimitGB` and decides whether to fire. Because `UsageStore` is `@Observable` and updates on every aggregator flush, the engine subscribes once and fires reactively.

Copy uses PRD §7 plain language: "這個月的流量已經用了 80% 了" (for 80% / 95%); 100% uses a slightly more urgent line.

## Acceptance Criteria
- [x] On app launch, `NotificationCoordinator` requests `UNUserNotificationCenter` authorization for `.alert` + `.sound`; remembers result across runs
- [x] `ThresholdEngine` subscribes to `UsageStore` updates; recomputes percentage on every change
- [x] When percentage crosses 80 / 95 / 100 *and* the corresponding `preferences.alertAt*` is true *and* the threshold has not yet fired in the current cycle: fires a local notification
- [x] Notification content:
  - 80% → "這個月的流量已經用了 80% 了"
  - 95% → "這個月的流量已經用了 95% 了" (or "快用完囉")
  - 100% → "這個月的流量已經用完了"
- [x] Per-cycle dedupe: track fired thresholds in UserDefaults keyed by cycle start date (`"pref.notif.fired.<cycleStartISO>.<threshold>" = true`); cleared automatically when cycle rolls over
- [x] When cap is unset (`monthlyLimitGB == nil`), no notifications fire (defensive: even if a stale state somehow asks for one)
- [x] Manually setting MTD past 80% (via debug toggle) fires exactly one 80% notification within 2 seconds
- [x] If all three thresholds are crossed simultaneously (e.g., debug jump from 0 → 100%), all three enabled notifications fire in order (80 first, then 95, then 100) — not deduped against each other
- [x] Disabling a threshold in Settings does not retroactively undo a fired notification; it only prevents future fires for that cycle
- [x] Menu bar icon (optional polish): when over 100%, tints to `Color.tally.accent` — defer if scope creep

## Implementation Notes
- **Files to create**: `Notifications/NotificationCoordinator.swift`, `Notifications/ThresholdEngine.swift`, `Notifications/FiredThresholdsLedger.swift`
- **Authorization**: `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])` — call once at boot via `AppState`. If denied, log and skip future scheduling (don't pester the user)
- **`ThresholdEngine` lifecycle**: owned by `AppState`; on init, subscribes to `usageStore` updates. Cancellable on app teardown
- **Dedupe ledger key format**: `pref.notif.fired.<yyyy-MM-dd>.<80|95|100>` — the yyyy-MM-dd is the current cycle's `start.iso8601`. On cycle rollover (`BillingCycle.current.start` changes), prior keys become irrelevant — clean them up lazily (delete keys older than 2 cycles on each notification check)
- **Race condition**: if the engine recomputes during an aggregator flush mid-transaction, GRDB might return a stale snapshot — fine; the next flush will re-evaluate
- **Notification builder**:
  ```swift
  let content = UNMutableNotificationContent()
  content.title = "Tally"
  content.body = bodyForThreshold(percent)
  content.sound = .default
  UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "tally.threshold.\(percent)", content: content, trigger: nil))
  ```
- **`UNUserNotificationCenter` delegate**: register a delegate to show the notification banner even when the app is in the foreground (`willPresent` returns `[.banner, .sound]`)
- **Menu bar icon tinting (optional)**: if scoping allows, expose a `usageStore.menuBarIconTint: Color` derived state; update the `MenuBarExtra` icon via `Image(systemName:).foregroundStyle(tint)` — but be aware `MenuBarExtra(systemImage:)` accepts only a system name string. Tinting may require switching to `Image()` rendering. Defer to v0.2 if it requires bigger refactor

## Testing
- First launch → authorization dialog appears → grant
- Settings → all three thresholds checked
- Force `usageStore.monthToDateBytes` to 81% of cap via a debug button → 80% notification fires within 2s
- Quit and relaunch → 80% does NOT re-fire (dedupe ledger holds)
- Bump to 96% → 95% fires
- Bump to 100% → 100% fires
- Trigger cycle rollover (set system date to next cycle start, OR change cycle day to today) → ledger clears; 80% can fire again
- Disable 95% in Settings then bump 80%→95% → no notification fires
- Set cap to nil → no notifications fire regardless of usage
- Authorization-denied case: launch with denied permission → app continues to work; logs "[notif] denied"; no crashes
- Inspect `defaults read com.calvinku.Tally.preferences | grep notif.fired` → entries present for current cycle thresholds
