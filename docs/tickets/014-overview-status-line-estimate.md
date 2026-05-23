# [TICKET-014] Overview status line + estimate sentence

## Status
`done`

## Dependencies
- Requires: #013 ✅

## Description
Two textual sentences live below the hero card and above the Top 10 apps list:

1. **Network status line** (PRD §6.3): "你現在連在 **<friendly network name>**" — Wi-Fi icon + sentence. The friendly name is the SSID for Wi-Fi, "乙太網路" for Ethernet, or "iPhone 的熱點" if hotspot is detected (PRD §7). Hotspot auto-detection is v0.2 (PRD §13) — MVP just shows the network's static name. PRD §7 explicitly demonstrates the hotspot copy as the v0.2 target.

2. **Estimate sentence** (PRD §6.3): "以目前的速度，月底大概會用到 **X GB**". Algorithm: linear extrapolation `MTD_bytes ÷ days_elapsed × days_in_cycle`, rendered to 1 decimal in GB. PRD §13 explicitly flags algorithm refinement as v0.2 — MVP can be naive.

3. **No-limit fallback branch** (PRD §6.3): "若使用者沒設上限：改顯示『上個月用了 Y GB』當作比較基準" — when `monthlyLimitGB` is nil, the estimate sentence is replaced with this last-cycle comparison. Last-cycle math is also placeholder until TICKET-019; for MVP use "calendar previous month total" as a working approximation.

## Acceptance Criteria
- [x] `StatusLine` view shows Wi-Fi/Ethernet SF Symbol + "你現在連在 **<network name>**" — friendly name resolved per below
- [x] Wi-Fi name from `CWWiFiClient.shared().interface()?.ssid()` when active; "乙太網路" when on Ethernet; "未連線" when offline. Hotspot detection deferred to v0.2 (PRD §13)
- [x] `EstimateSentence` view shows "以目前的速度，月底大概會用到 **X.X GB**" when `monthlyLimitGB` is set (or even if unset, it can still render — see the next criterion)
- [x] **No-limit fallback**: when `monthlyLimitGB == nil`, swap the estimate sentence for "上個月用了 **Y.Y GB**"
- [x] Sentence typography: `Font.tally.body` for the narrative text, `Font.tally.body.bold()` for the GB number; vertical rhythm follows `Spacing.s4` between hero card, status line, and estimate
- [x] Linear extrapolation matches: `mtd × (daysInCycle / daysElapsed)` rounded to 1 decimal — covered by a unit test on `EstimateCalculator`
- [x] Days-elapsed handles the first day of a cycle (avoid divide-by-zero — return MTD when `daysElapsed == 0`)
- [x] Voice strings exactly match PRD §7 examples — "你現在連在" (not "您"), "以目前的速度" (not "in current speed"), "月底大概會用到" (not "estimated end-of-month")

## Design Reference
- **Layout**: `docs/system-design/ui_kits/macos_app/OverviewScreen.jsx` (status + estimate sections)
- **Tokens**: `Font.tally.body`, `--fg-1`, `--fg-2`, `Spacing.s4`
- **Voice / copy**: PRD §7 文案範例

## Visual Reference
Below the hero card, two short rows of text appear, spaced from the card by 16pt. The first row has a small Wi-Fi icon on the left and the sentence "你現在連在 **家裡的 Wi-Fi**" — the network name is bolded, the rest is regular weight in a dark warm grey. Below it, a single sentence: "以目前的速度，月底大概會用到 **18 GB**." The 18 GB is bolded. The two rows feel like comments next to the big number, not separate widgets.

If the user hasn't set a cap, the estimate row swaps to "上個月用了 **22.1 GB**" — still bolded GB, same vertical rhythm.

If offline, the status line reads "你現在離線" (no bold name) — graceful fallback, not an error state.

## Implementation Notes
- **Files to create**: `MainWindow/Overview/StatusLine.swift`, `MainWindow/Overview/EstimateSentence.swift`, `Cycle/EstimateCalculator.swift` (pure function for testability)
- **CoreWLAN dependency**: `import CoreWLAN` for `CWWiFiClient` — add to the target if not already
- **Network type detection**: poll `SCNetworkReachability` or `NWPathMonitor` to distinguish Wi-Fi vs Ethernet. `NWPathMonitor` is the modern Swift API:
  ```swift
  let monitor = NWPathMonitor()
  monitor.pathUpdateHandler = { path in
      if path.usesInterfaceType(.wifi) { ... ssid lookup ... }
      else if path.usesInterfaceType(.wiredEthernet) { friendlyName = "乙太網路" }
      else { friendlyName = "未連線" }
  }
  ```
- **No hotspot detection in MVP**: PRD §13 puts auto-hotspot in v0.2 — do not attempt detection. Document why in code: "Hotspot detection deferred — see PRD §13 v0.2 roadmap"
- **`UsageStore` accessor**: add `currentNetworkDisplay: String` and `previousCycleTotalBytes: Int` to `UsageStore` (TICKET-009 placeholder slots), driven by the network monitor and a SQL query against `daily_aggregates` for the previous calendar month — TICKET-019 will refine to cycle-aware logic
- **EstimateCalculator**: pure function `func projectedTotal(mtdBytes: Int, daysElapsed: Int, daysInCycle: Int) -> Int` — write a small XCTest covering: day 1 returns MTD, day N projects linearly, division by zero handled
- **Privacy**: do NOT include the SSID in any log line (logs can be shared); when logging network state, just say "wifi connected" not the SSID

## Testing
- Open main window → status line shows current Wi-Fi SSID (or Ethernet, or offline)
- Disconnect from Wi-Fi → line updates to "未連線" within ~2 seconds
- With cap = 20 GB and MTD = 12 GB at day 15 of a 30-day cycle → estimate sentence reads "以目前的速度，月底大概會用到 **24 GB**" (12 × 30/15 = 24)
- Set cap = nil via debug → estimate sentence becomes "上個月用了 **Y.Y GB**" with real Y from `daily_aggregates`
- Day 1 of cycle, MTD = 0 → no division crash; sentence reads "以目前的速度，月底大概會用到 **0 GB**"
- Voice audit: scan all visible strings for PRD §7 plain-language conformance
- Run `EstimateCalculator` XCTest → all cases pass
