# [TICKET-021] Onboarding 3-step flow

## Status
`blocked`

## Dependencies
- Requires: #017 ✅, #018

## Description
Build the first-launch onboarding flow per PRD §9: a full-screen modal with three sequential steps that runs before the user sees the main window. The flow is gated by `preferences.onboardingComplete`; setting it to false (via TICKET-018's debug row, or by deleting prefs) re-presents on next launch.

### Step 1 — Welcome
A friendly intro: "Tally 會追蹤你 Mac 的流量使用." + one line of non-goals: "不擋網、不上傳任何資料到雲端". Single CTA: "下一步".

### Step 2 — Permission
The hardest step: macOS Network Extension approval is not intuitive (PRD §9: "macOS 對 SE 的批准流程不直覺"). This step:
- Explains what permission is needed: "Tally 需要『看見』你的網路使用情況，才能告訴你每個 app 用了多少"
- A "為什麼需要這個權限" expandable that elaborates without jargon
- A primary button "去設定" that opens System Settings → Privacy & Security
- A "已經批准了" button to advance (user must self-attest in MVP — TICKET-023 will refine with denial / retry handling)
- Mentions the VPN limitation gently: "如果你常開 VPN，Tally 可能看不到每個 app 的細節"

In MVP (before TICKET-023 lands the actual NE Extension), this step is "informational" — the nettop collector is already running. The button is essentially "got it"; full NE permission UX is layered in by TICKET-023.

### Step 3 — Setup
Two inputs:
- 每月從幾號開始算 (cycle day picker, default 1) → writes `preferences.cycleStartDay`
- 每月可以用多少 GB? (numeric input + 我沒有上限，只想追蹤 toggle) → writes `preferences.monthlyLimitGB`

Final CTA: "開始用". On tap:
- Write all prefs
- Set `preferences.onboardingComplete = true`
- Dismiss modal
- Show main window with `usageStore.state == .collecting` → "資料正在收集中，數據會在幾分鐘後開始顯示"

## Acceptance Criteria
- [ ] On launch with `preferences.onboardingComplete == false`, the onboarding modal presents full-screen and blocks access to the main window / popover until completed
- [ ] Each of the three steps renders per the design system (`docs/system-design/ui_kits/macos_app/Onboarding.jsx`)
- [ ] Step 1: title, non-goals line, "下一步" button advances
- [ ] Step 2: explanation, expandable "為什麼需要這個權限", "去設定" opens `x-apple.systempreferences:com.apple.preference.security` URL, "已經批准了" advances; VPN limitation note visible
- [ ] Step 3: cycle day picker + cap input + "我沒有上限" toggle bind to `Preferences`; "開始用" writes prefs, sets `onboardingComplete = true`, dismisses
- [ ] After completion, popover and main window become accessible; menu bar icon was already visible during onboarding but tap was non-functional (or showed "請先完成設定" — pick one and document)
- [ ] 重新跑一次 onboarding (TICKET-018) resets `onboardingComplete` → next launch presents onboarding again
- [ ] All copy from PRD §7 + §9 — no English technical terms, "你" not "您"
- [ ] Modal cannot be closed via ⌘W / Esc / clicking outside — only via the final button (prevents stranding the user mid-setup)

## Design Reference
- **Layout**: `docs/system-design/ui_kits/macos_app/Onboarding.jsx`
- **Tokens**: `Color.tally.bgApp`, `Color.tally.accent`, `Font.tally.title1`, `Font.tally.body`, `Radius.r10`, `Spacing.s6`

## Visual Reference
On first launch, before the user sees anything else, a full-window modal appears (likely a separate `Window` scene or a `.sheet` covering the main one). Step 1 shows a friendly "歡迎使用 Tally" title with a tally-mark glyph, a short paragraph, and a primary amber button "下一步" at the bottom-right.

Step 2 shows a title "幫我看見網路", a paragraph explaining the permission, an expandable "為什麼需要這個權限" arrow that on click reveals 2–3 lines of plain-language detail. A subtle line at the bottom mentions VPN: "如果你常開 VPN，Tally 可能看不到每個 app 的細節". Two buttons: a secondary "去設定" (opens System Settings) and a primary "已經批准了" (advances).

Step 3 shows "設定一下" with two clean inputs — a small popup for cycle day, and a numeric input for GB with a checkbox below "我沒有上限，只想追蹤". The primary button now reads "開始用".

After tapping "開始用", the modal cross-fades out and the main window appears with the hero card showing "資料正在收集中，幾分鐘後就能看到數據".

## Implementation Notes
- **Files to create**: `Onboarding/OnboardingFlow.swift`, `Onboarding/Steps/WelcomeStep.swift`, `Onboarding/Steps/PermissionStep.swift`, `Onboarding/Steps/SetupStep.swift`, `Onboarding/OnboardingScene.swift` (or modifier-based presentation)
- **Presentation**: prefer a dedicated `Window("Onboarding", id: "onboarding") { OnboardingFlow() }` over a sheet — sheets on macOS can be dragged behind; a full-window modal is more emphatic. Open the onboarding window in `TallyApp.init()` (or in the root `Group` Scene) when `onboardingComplete == false`; close it programmatically via `dismissWindow(id:)`
- **Blocking access**: gate the main `Window` and `MenuBarExtra` content on `preferences.onboardingComplete`. Menu bar can stay visible during onboarding but its action is no-op or shows the onboarding window
- **System Settings link**: `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)`. macOS 14+ may need a more specific URL — verify
- **Expandable "為什麼需要這個權限"**: `DisclosureGroup` works fine; keep collapsed by default
- **Cycle day input**: reuse `CycleDayRow` from TICKET-018 (extract to a shared component)
- **Cap input**: same approach — `CapRow` shared component
- **Voice**: all copy from PRD §7 and §9. Onboarding is the user's first impression — proofread against the term table twice
- **VPN note in Step 2**: PRD §12 — a one-liner is sufficient; do not let it dominate the step

## Testing
- `rm -rf ~/Library/Application\ Support/Tally/` + `defaults delete com.calvinku.Tally.preferences` → clean state
- ⌘R → onboarding modal appears full-screen
- Step 1 → click "下一步" → Step 2
- Step 2 → click "去設定" → System Settings opens to Privacy & Security
- Step 2 → expand "為什麼需要這個權限" → details show
- Step 2 → click "已經批准了" → Step 3
- Step 3 → set cycle = 5, cap = 30 → click "開始用" → modal dismisses; main window shows; ` defaults read com.calvinku.Tally.preferences` shows `pref.cycleStartDay = 5`, `pref.monthlyLimitGB = 30`, `pref.onboardingComplete = 1`
- Relaunch → onboarding does NOT show; goes straight to main / popover
- Settings → 重新跑一次 onboarding → confirm → relaunch → onboarding presents
- Try ⌘W / Esc during onboarding → modal does not close
- Voice audit on every onboarding string against PRD §7
