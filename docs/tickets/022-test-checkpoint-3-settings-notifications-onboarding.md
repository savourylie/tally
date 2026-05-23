# [TICKET-022] TEST: Checkpoint 3 — Settings, Notifications, Onboarding

## Status
`pending`

## Dependencies
- Requires: #020 ✅, #021 ✅

## Description
Phase 4 (TICKET-017 through TICKET-021) layered in everything around the user's preferences: persistence, the Settings UI, the billing cycle engine, threshold notifications, and the first-launch onboarding flow. This checkpoint exercises the user's "first day with Tally" experience end-to-end:

- Fresh install → onboarding gates everything → completing onboarding writes prefs
- Settings is the user's control surface — every field must persist and propagate
- The cycle engine produces correct windows for the next several months
- Notifications fire at 80 / 95 / 100% — exactly once per cycle, in the right order

Passing this checkpoint unlocks Phase 5 (Network Extension + Final QA).

## Acceptance Criteria
- [ ] **Onboarding gating**: clean install → onboarding presents and blocks main / popover until completion
- [ ] **Onboarding completion**: completing all 3 steps writes `cycleStartDay`, `monthlyLimitGB` (or sets nil if user picked 沒有上限), and `onboardingComplete = true`; relaunch does NOT show onboarding
- [ ] **Onboarding reset**: Settings → 重新跑一次 onboarding → confirm → relaunch → onboarding shows again
- [ ] **Settings round-trip**: every field round-trips through UserDefaults (quit + relaunch preserves all values)
- [ ] **Cycle engine accuracy**: for at least 3 different `cycleStartDay` values (1, 5, 31) — manually verify `BillingCycle.current` returns expected start/end on today's date by adding a debug log, comparing to a hand-calculated expectation
- [ ] **Cycle propagation**: changing `cycleStartDay` in Settings → main window hero number rebases within 1 second
- [ ] **No-limit branch**: setting cap = nil in Settings → Overview estimate line swaps to "上個月用了 …" from TICKET-014
- [ ] **Notification: 80% fires**: with cap=10 GB and forced MTD = 8.5 GB → exactly one 80% notification fires
- [ ] **Dedupe**: relaunch with same state → 80% does NOT re-fire
- [ ] **Sequence**: force MTD from 0 → 100% in one jump → all three notifications fire in order (80, then 95, then 100), each only once
- [ ] **Disabled threshold**: uncheck 95% in Settings → 95% does not fire on the next crossing; 80 and 100 still fire when their thresholds are crossed
- [ ] **Cycle rollover**: simulate next cycle (set system date forward) → dedupe ledger clears; thresholds can fire again
- [ ] **Autostart**: toggle on → reboot Mac → Tally launches at login (manual reboot test; document if SMAppService is flaky)
- [ ] **Advanced toggle**: visible, disabled, hint visible; toggling does nothing
- [ ] **Voice audit**: scan all Settings + Onboarding strings against PRD §7 term table

## Implementation Notes
This is a manual test execution ticket — no code changes unless bugs are found during testing.

Common failure modes to watch for:
- **Cycle day 31 in February**: easy to get off-by-one; verify the clamp explicitly
- **DST transition**: only relevant in March / November; if not testable, write the unit test and trust it
- **Notification not firing**: most likely cause is denied authorization. Confirm at System Settings → Notifications → Tally → Allow Notifications is on. Re-grant if needed
- **Notification dedupe broken**: the ledger key includes the cycle start date — make sure changing cycle day refreshes the key
- **Onboarding window dismisses before pref is written**: a race between `dismissWindow` and `preferences.onboardingComplete = true`. Write prefs FIRST, dismiss second
- **Autostart on macOS 14+**: `SMAppService` may need an entitlement and a bundled launch agent plist; verify TICKET-001's project includes them or document a known limitation

Test environment: A clean Mac (or a clean Application Support + prefs directory) for the onboarding test; a Mac with active browsing for the notification tests.

## Testing
1. `rm -rf ~/Library/Application\ Support/Tally/ && defaults delete com.calvinku.Tally.preferences`
2. ⌘R → onboarding presents; menu bar icon visible but inert (or shows onboarding window)
3. Complete all 3 steps with cycle=5, cap=10 → main window appears in collecting state
4. Relaunch → straight to main, no onboarding
5. Settings → verify cycle=5, cap=10 displayed
6. Change cycle=15 → save → quit + relaunch → still 15
7. Toggle "沒有上限" → quit + relaunch → still unset
8. Add a debug button: "Force MTD to X%" → press 80% button → notification fires within 2s
9. Press 80% again → no second notification
10. Press 100% → 100% notification fires (95% may or may not depending on press sequence; force 0% → 100% to test full sequence)
11. Uncheck 95% → force 0% → 95% → only 80% notification fires
12. `defaults read com.calvinku.Tally.preferences` → confirm `pref.notif.fired.<cycle>.80 = 1`
13. Settings → 重新跑一次 onboarding → confirm → relaunch → onboarding presents
14. Voice audit: `rg -i '(您|cycle|cap|onboarding|notification)' Tally/Sources/Onboarding Tally/Sources/MainWindow/Settings` → no user-facing matches
15. Record per-criterion result in PR; on full pass mark `done` and unblock Phase 5
