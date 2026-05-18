# [TICKET-017] Preferences persistence (UserDefaults wrapper)

## Status
`blocked`

## Dependencies
- Requires: #016

## Description
Build the typed UserDefaults wrapper that holds every user preference for MVP. This is a foundational layer for Phase 4: the Settings UI (TICKET-018) binds to it, the billing cycle engine (TICKET-019) reads `cycleStartDay` from it, the notification engine (TICKET-020) reads the threshold checkboxes, and the onboarding flow (TICKET-021) writes the cycle / cap / completion fields.

Splitting persistence from the Settings UI keeps each independently testable, prevents a merge-order trap (onboarding writes prefs before Settings is built), and gives downstream consumers a single observable type rather than scattered `@AppStorage` declarations.

## Acceptance Criteria
- [ ] `Preferences` is an `@Observable` class injected via `AppState`
- [ ] Exposes typed properties matching PRD §6.3 Settings + §9 Onboarding:
  - `cycleStartDay: Int` (1–31, default 1)
  - `monthlyLimitGB: Double?` (nil = "沒有上限")
  - `alertAt80: Bool` (default true)
  - `alertAt95: Bool` (default true)
  - `alertAt100: Bool` (default true)
  - `autostart: Bool` (default false)
  - `advancedMode: Bool` (default false) — placeholder, no behavior wired in MVP
  - `onboardingComplete: Bool` (default false)
- [ ] All properties round-trip through UserDefaults under the suite name `com.calvinku.Tally.preferences` (or the chosen bundle id + `.preferences`)
- [ ] All keys use a stable, namespaced format (`pref.cycleStartDay`, `pref.monthlyLimitGB`, …) and are listed in `PreferencesKeys.swift` for migration safety
- [ ] Changing any property emits a SwiftUI invalidation — bindings in TICKET-018 / TICKET-019 / TICKET-020 see updates without manual refresh
- [ ] Values survive app relaunch: set a value, quit, relaunch, value persists
- [ ] First-launch sentinel: when `onboardingComplete == false`, this is detectable by the App for routing (TICKET-021 will do the actual routing)

## Implementation Notes
- **Files to create**: `Preferences/Preferences.swift`, `Preferences/PreferencesKeys.swift`
- **Suite name**: `UserDefaults(suiteName: "com.calvinku.Tally.preferences")` — using a suite keeps Tally's prefs isolated from any future helper extensions sharing a process namespace
- **Manual `@Observable` over `@AppStorage`**: `@AppStorage` is per-View; we need a shared observable that drives both Settings UI and headless engines. Implement as:
  ```swift
  @Observable
  final class Preferences {
      private let store: UserDefaults
      var cycleStartDay: Int {
          get { store.integer(forKey: Keys.cycleStartDay) }
          set { store.set(newValue, forKey: Keys.cycleStartDay); /* invalidate via _$observationRegistrar */ }
      }
      // ...
  }
  ```
  Because we're using `@Observable` (not the old `@Published`), accessing a property tracks; the setter must call `_$observationRegistrar.didSet(self, keyPath: \.cycleStartDay)` explicitly. Verify the macro behavior on your Swift version
- **Default values**: register via `UserDefaults.standard.register(defaults: [...])` at app start so newly-introduced keys have sensible defaults without a migration
- **Optional handling for `monthlyLimitGB`**: store `Double` with `0` as sentinel "unset", or store as `NSNumber` and check nil — either works; document the choice. Recommend the sentinel approach: read 0 → return nil; write nil → store 0. Add a unit test
- **Key naming for migration**: do NOT use `"cycleStartDay"` directly — use `"pref.cycleStartDay"` so future namespaces (e.g., `"advanced.*"`) don't collide. Document in `PreferencesKeys.swift`
- **Injection**: extend `AppState` with `let preferences: Preferences`; pass via `.environment(...)` from `TallyApp`

## Testing
- Set `preferences.cycleStartDay = 15` → quit → relaunch → value is 15
- Set `preferences.monthlyLimitGB = nil` → quit → relaunch → still nil
- Set `preferences.monthlyLimitGB = 50.0` → relaunch → 50.0
- Toggle `preferences.alertAt80 = false` → SwiftUI view bound to it re-renders immediately
- Reset by removing the suite: `defaults delete com.calvinku.Tally.preferences` → relaunch → all defaults restored
- Inspect `~/Library/Preferences/com.calvinku.Tally.preferences.plist` → keys all prefixed `pref.`
- Unit test: set every property, read back, assert equality
