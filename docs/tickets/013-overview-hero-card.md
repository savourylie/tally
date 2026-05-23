# [TICKET-013] Overview hero card

## Status
`done`

## Dependencies
- Requires: #009 ✅, #012 ✅

## Description
The Overview tab's identity is "the biggest number on screen tells you how much you used this month" (PRD §15: "數字優先"). This ticket builds the hero card: a rounded 12-radius surface with a 64pt mega number, the GB unit, and a "還可以用 X GB" subtext, plus the full-width progress bar.

The hero is the first thing the user's eye lands on. Typography, tracking, and alignment must be exact per `docs/system-design/preview/typography.html`. The progress bar shares its visual with the popover's (TICKET-010) — same height, same fill, same track.

## Acceptance Criteria
- [x] `HeroCard` view renders inside the Overview content area, full-width within the 760pt content column minus padding
- [x] Mega number: `Font.tally.mega` (64pt SF Pro Display, weight 600, letter-spacing −0.022em, tabular figures); 1-decimal precision (e.g., `12.4`)
- [x] Unit "GB" follows the number, baseline-aligned, in `Font.tally.title2` (17pt), `--fg-2` color
- [x] Subtext line: `Font.tally.callout` (12pt) — "還可以用 **X.X GB**（到 N 月 N 日重置）" when cap is set; placeholder "（還沒設定上限）" when nil (will be refined in TICKET-014)
- [x] Progress bar: 6pt height, full content-width, `Radius.r6` corner, `--brand-400` fill, track in `--bg-subtle` or equivalent; hidden when no cap
- [x] Card surface: `--bg-card` fill, `Radius.r12`, 1pt `--border` stroke, no shadow (per design system "borders + radius, no shadows" rule)
- [x] Card padding: `Spacing.s5` (20pt) all sides
- [x] Collecting state: when `usageStore.state == .collecting`, swap card body for a centered "資料正在收集中" message at `Font.tally.title3` weight 400 — same card frame, no mega number visible

## Design Reference
- **Layout**: `docs/system-design/ui_kits/macos_app/OverviewScreen.jsx` (hero section)
- **Typography**: `docs/system-design/preview/typography.html`, `colors_and_type.css` → `--fs-mega`
- **Tokens**: `--font-display`, `--brand-400`, `--bg-card`, `--border`, `Radius.r12`, `Spacing.s5`

## Visual Reference
At the top of the Overview pane, a wide rectangular card sits with a thin warm-grey border and a clean white interior. Inside: top row says "這個月用了" in small text; underneath, a huge "12.4" in dark warm grey, with a smaller "GB" trailing it. Below the number, a single line "還可以用 **7.6 GB**（到 6 月 1 日重置）" — the GB value is bolded. At the bottom of the card, a thin honey-amber progress bar sits flush, filling about 62% of the way. The whole card feels calm and uncluttered — the eye goes to "12.4" first.

If the cap is unset, the progress bar disappears and the subtext changes to a comparison line about last month's total (TICKET-014 implements that branch).

If the data is still collecting on first run, the entire card body is replaced by a centered "資料正在收集中" message, with the same card frame preserved.

## Implementation Notes
- **Files to create**: `MainWindow/Overview/HeroCard.swift`, `MainWindow/Overview/ProgressBar.swift` (shared with popover — refactor TICKET-010's `ProgressBar.swift` to live here if both surfaces use the same component)
- **GB formatting**: `String(format: "%.1f", bytes / 1_073_741_824)`. Always 1 decimal — `0.0` is fine for empty state if `.ready`
- **Cycle reset date string**: placeholder until TICKET-019; for now compute from current calendar month end. Format: "到 N 月 N 日重置" using `DateFormatter` with `MMMd` Chinese locale, or hand-format `formatter.string(from: cycleEnd)`
- **Mega font tracking**: SwiftUI's `.tracking()` takes points; 64pt × −0.022em ≈ −1.4pt. Verify visually against the design preview
- **Tabular digits**: `.font(.tally.mega.monospacedDigit())` — already encoded in TICKET-002's token if you followed those notes
- **Progress bar reuse**: extract a `ProgressBar(value: Double, showsTrack: Bool)` view; popover uses `.compact` height (6pt), Overview uses same 6pt — they're identical visually
- **`#Preview`**: include 4 cases — collecting, ready with cap and ample remaining, ready with cap near 100%, ready with no cap

## Testing
- Open main window → Overview tab → hero card visible with correct dimensions and tokens
- Manually set `usageStore.monthToDateBytes = (in: 6 GB-equivalent, out: 6.4 GB-equivalent)` via debug toggle → mega shows "12.4"
- Manually set cap to nil → progress bar disappears; subtext changes to placeholder
- Manually set state to `.collecting` → body swaps to "資料正在收集中" message
- Toggle Dark Mode → tokens swap
- Open `docs/system-design/ui_kits/macos_app/index.html` Overview page side-by-side → mega font, tracking, GB alignment, progress bar position all match
- Resize content area to test font scaling → letterforms remain tabular; mega doesn't wrap
