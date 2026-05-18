# [TICKET-010] Menu bar popover view + bindings

## Status
`blocked`

## Dependencies
- Requires: #002, #009

## Description
Build the menu bar popover — the primary surface users interact with. PRD §6.1 demands a 3-second-glance design: "本月用了 X GB，距離上限還有 Y%". The layout follows `docs/system-design/ui_kits/macos_app/Popover.jsx`: hero number on top, progress bar, network line, Top 5 apps list, footer with "打開完整畫面" + gear buttons.

The view binds to the shared `UsageStore` from TICKET-009 and updates live. First-run empty state (`state == .collecting`) renders a placeholder "資料正在收集中" message rather than 0.0 GB.

The popover opens with a scale-fade animation per `docs/system-design/preview/motion.html`: `--dur-popover` 280ms, `--ease-decel` cubic-bezier(0.32, 0.72, 0, 1). The menu bar icon itself stays neutral; when usage crosses the monthly cap (post-TICKET-019), the icon tints to the brand accent — but icon tinting can land in TICKET-020 alongside notifications.

## Acceptance Criteria
- [ ] `MenuBarExtra("Tally", systemImage: …) { PopoverView() }` replaces the placeholder content from TICKET-004; popover width 320pt per `Popover.jsx`
- [ ] Hero number: current month-to-date total in GB, rendered with `Font.tally.display` (34pt SF Pro Display, weight 600, tabular figures); unit "GB" smaller, separate
- [ ] Below the hero: `--fs-callout` text "還可以用 X GB" when a cap exists, or "上限沒設定" placeholder when nil (refined in TICKET-019)
- [ ] Progress bar: full-width 6pt height, `--brand-400` fill, `--bg-card`-darkened track, fill width tracks `monthToDateBytes / capBytes`; hidden entirely if no cap is set
- [ ] Network line: SF Symbol Wi-Fi/Ethernet icon + "你現在連在 **<name>**" string (network detection is placeholder until TICKET-019; for now show a static "你的網路" or the SSID via `CWWiFiClient.shared().interface()?.ssid()`)
- [ ] Top 5 apps list: 20pt app icons, app name (or category name) in `--fs-body`, bytes in GB in `--fs-callout` mono digits — sourced from `usageStore.topApps(limit: 5)`
- [ ] Footer: "打開完整畫面" button (opens `Window` scene with id `"main"`), gear icon button (opens main window scoped to Settings — for now just opens main window; routing to Settings sidebar item lands in TICKET-018)
- [ ] **Collecting state**: when `usageStore.state == .collecting`, the hero / progress / top-apps area is replaced by a centered placeholder card with text "資料正在收集中，幾分鐘後就能看到數據"
- [ ] Dark mode: every token swaps cleanly via the adaptive Color resolves from TICKET-002
- [ ] Popover open animation: scale 0.96 → 1.0, opacity 0 → 1, duration 280ms, decel easing; visible on first click and on re-open

## Design Reference
- **Layout**: `docs/system-design/ui_kits/macos_app/Popover.jsx`
- **Tokens**: TICKET-002's `Color.tally.*`, `Font.tally.display`, `Spacing.s4`, `Radius.r10`, `Motion.popoverDecel`
- **Shadow**: `--shadow-popover` two-layer (SwiftUI: `.shadow(color:radius:y:)` composed via overlays)
- **Motion**: `docs/system-design/preview/motion.html` (popover-open demo)

## Visual Reference
Clicking the menu bar tally-mark icon opens a 320pt-wide rounded card with translucent background (`--bg-popover` rgba 92% opacity, NSVisualEffectView material `.popover`). At the top, a large "12.4" appears in dark warm grey, with "GB" smaller to its right, and "還可以用 7.6 GB" subtext below. A thin honey-amber progress bar extends across the card. Below it, a small Wi-Fi icon and "你現在連在 **家裡的 Wi-Fi**". Then a list of 5 rows: app icon, app name, GB value right-aligned. At the bottom, a divider and two buttons. On open, the popover scales gently from 96% to 100% and fades in over 280ms — feels springy, not snappy.

When data is still collecting on first run, the body is replaced with a soft message: "資料正在收集中，幾分鐘後就能看到數據" centered, no numbers visible.

## Implementation Notes
- **Files to create**: `MenuBar/MenuBarRoot.swift` (the `MenuBarExtra` scene wrapper), `MenuBar/PopoverView.swift` (the body), `MenuBar/Subviews/HeroNumber.swift`, `MenuBar/Subviews/ProgressBar.swift`, `MenuBar/Subviews/NetworkLine.swift`, `MenuBar/Subviews/TopAppRow.swift`, `MenuBar/Subviews/CollectingPlaceholder.swift`
- **MenuBarExtra style**: `.menuBarExtraStyle(.window)` to get a popover rather than a menu — gives full SwiftUI layout freedom
- **Opening main window**: use `@Environment(\.openWindow) var openWindow` and call `openWindow(id: "main")`. The window scene is defined in TICKET-012; for this ticket, ensure the call doesn't crash if the window doesn't exist yet (use Window scene from TICKET-001 placeholder as the target — replaced later)
- **Translucency**: wrap content in `VisualEffectBackground()` (small `NSViewRepresentable` over `NSVisualEffectView`) — there's no native SwiftUI control yet
- **Animation**: SwiftUI doesn't animate `MenuBarExtra(.window)` presentation directly. Wrap the body in a `ScaleEffectModifier` driven by a state `isVisible` that flips on appearance: `.scaleEffect(isVisible ? 1.0 : 0.96).opacity(isVisible ? 1.0 : 0).onAppear { withAnimation(Motion.popoverDecel) { isVisible = true } }`
- **Number formatting**: GB to 1 decimal, e.g. `12.4` not `12.43`; use `Measurement<UnitInformationStorage>` if you want correct binary vs decimal conventions, or just hand-format `Double(bytes) / 1_073_741_824`
- **Voice strings**: pull from PRD §7 exactly. No `mDNSResponder` / bundle id strings allowed
- **No raw bundle ids**: assert at the view layer — for any TopAppRow whose display name still looks like `com.x.y`, crash in DEBUG builds. Phase 3 will revisit this with broader voice audit
- **`#Preview`**: include 3 previews — collecting state, ready state with 5 apps, ready state with no cap (limit hidden)

## Testing
- ⌘R → click menu bar icon → popover appears with scale-fade animation
- Top 5 apps match `SELECT bundle_id, total_in + total_out FROM daily_aggregates WHERE date = today() ORDER BY 2 DESC LIMIT 5` (with helper roll-up from TICKET-007)
- Real app names + icons via TICKET-008 (Safari, Chrome, Slack, etc.)
- Toggle macOS Dark Mode → popover updates instantly
- Force `usageStore.state = .collecting` (via debug toggle) → placeholder replaces hero/progress/list
- Force cap = nil via TICKET-009 (placeholder cycle code) → progress bar disappears; subtext changes
- Click "打開完整畫面" → main window scene opens (placeholder until TICKET-012)
- Click gear → main window opens (Settings routing in TICKET-018)
- Compare side-by-side with `docs/system-design/ui_kits/macos_app/index.html` rendering in a browser — layout, spacing, colors visually match
