# [TICKET-018] Settings screen UI

## Status
`blocked`

## Dependencies
- Requires: #017

## Description
Build the Settings pane that appears when the user selects 設定 in the main window sidebar. PRD §6.3 lists exactly what's in MVP Settings:

- 每月從幾號開始算 (cycle start day, default 1)
- 每月可以用多少 GB (monthly cap, with "沒有上限" option)
- 快用完時提醒我 (80% / 95% / 100% checkboxes)
- 開機自動啟動 (autostart toggle)
- Advanced 模式 toggle (placeholder — does nothing in MVP)

Plus two extras agreed in the plan:
- VPN limitation footnote (PRD §12 known limitation)
- 重新跑一次 onboarding (debug row that resets `onboardingComplete`)

Every row binds to the `Preferences` from TICKET-017. The Advanced toggle visually exists but is disabled or has a "v0.3" badge — PRD §7 explicitly reserves the toggle slot in MVP without unlocking anything.

## Acceptance Criteria
- [ ] Settings pane fills the 760pt content column with `Spacing.s6` (24pt) padding
- [ ] Sections rendered top-to-bottom:
  1. 計費週期 (cycle day picker — 1–31 stepper or popup menu)
  2. 流量上限 (numeric input for GB + "沒有上限" toggle that nils the value)
  3. 通知 (three checkboxes for 80% / 95% / 100%)
  4. 開機自動啟動 (single toggle wired to `SMAppService`)
  5. Advanced 模式 (toggle, locked / disabled with a small "之後再開放" hint)
  6. 進階選項 (footer with VPN note + 重新跑一次 onboarding row)
- [ ] Every row binds to `Preferences` — toggling a checkbox updates UserDefaults immediately
- [ ] Cycle day input: when user picks 31 and current month has fewer days, show inline hint "若該月沒有 31 號，會用月底最後一天" — TICKET-019 implements the actual logic
- [ ] Monthly cap: shows "沒有上限" pill when unset; tapping "設定上限" reveals the numeric input
- [ ] Autostart toggle: wires to `SMAppService.mainApp.register()` / `.unregister()`; on failure shows a small error label "無法設定，請手動到系統設定打開"
- [ ] Advanced toggle: rendered but `.disabled(true)` (or wrapped in a `Group` with `.allowsHitTesting(false)` + 50% opacity); hint text visible
- [ ] VPN footnote text matches PRD §12 spirit: "如果開了 VPN，Tally 沒辦法分開算每個 app 的流量" — small, `--fg-3`, end-of-pane
- [ ] 重新跑一次 onboarding row: a button "重新跑一次 onboarding" that sets `preferences.onboardingComplete = false`. After tapping, on next launch the onboarding modal shows (TICKET-021 wires the actual presentation)

## Design Reference
- **Layout**: `docs/system-design/ui_kits/macos_app/SettingsScreen.jsx`
- **Tokens**: `Color.tally.bgApp`, `Spacing.s4`/`s6`, `Font.tally.body`, `Font.tally.caption` (for footnote)

## Visual Reference
Selecting 設定 in the sidebar swaps the content area to a vertical list of settings groups. At the top, "計費週期" header in `--fg-2` followed by a row with label "每月從幾號開始算" and a small popup showing "1". Below it, "流量上限" with either a "沒有上限" pill or a row showing "20 GB" with an "編輯" affordance. Below it, "通知" with three rows — "用到 80% 提醒我", "用到 95% 提醒我", "用到 100% 提醒我" — each with a checkbox on the right. Below it, "開機自動啟動" with a single switch. Below it, "Advanced 模式" with a switch that's clearly disabled / faded, plus a small "（之後再開放）" subtitle. At the bottom, a small italic-ish line in muted color reminds about VPN, and a borderless button "重新跑一次 onboarding" sits unobtrusively.

The whole pane scrolls if it overflows (rare in MVP but possible at large text size).

## Implementation Notes
- **Files to create**: `MainWindow/Settings/SettingsView.swift`, `MainWindow/Settings/Subviews/CycleDayRow.swift`, `MainWindow/Settings/Subviews/CapRow.swift`, `MainWindow/Settings/Subviews/AlertRow.swift`, `MainWindow/Settings/Subviews/AutostartRow.swift`, `MainWindow/Settings/Subviews/AdvancedToggleRow.swift`, `MainWindow/Settings/Subviews/VPNNoteFooter.swift`, `MainWindow/Settings/Subviews/RerunOnboardingRow.swift`
- **Binding pattern**: `@Bindable var preferences: Preferences` on each row, parent passes it down. Reads track via `@Observable`, writes go through the setter
- **`SMAppService` for autostart**: requires bundling a small `LaunchAgent` plist. Document the required `Info.plist` keys. If too complex for MVP, gate behind a comment "// MVP: simplified autostart via SMAppService.mainApp; if API rejects, fall back to manual instructions"
- **No "Save" button**: changes apply immediately on toggle (macOS HIG convention) — do NOT add a save button
- **VPN footnote location**: under all settings, before the rerun row. Wording from PRD §7 voice ("如果開了 VPN…"). Keep under 30 characters per line break
- **Rerun-onboarding button safety**: confirm with a SwiftUI `confirmationDialog` before resetting — accidentally clicking should not strand the user

## Testing
- Open main window → click 設定 → all sections render
- Set cycle day = 15 → reflected immediately; quit + relaunch → still 15
- Set cap = 20 GB → returns to "20 GB" display; toggle "沒有上限" → cap becomes nil; numeric input hides
- Toggle 80% off → `preferences.alertAt80 == false`; popover / Overview UI is unaffected (notifications are TICKET-020)
- Toggle autostart → restart Mac (or simulate via `SMAppService.mainApp.status` check) → Tally launches at login
- Try toggling Advanced → does nothing (disabled state); hint visible
- Click 重新跑一次 onboarding → confirmation dialog appears; confirm → quit + relaunch → onboarding modal expected (TICKET-021)
- Voice audit: all visible strings against PRD §7 vocabulary
- Compare side-by-side with `docs/system-design/ui_kits/macos_app/index.html` Settings view
