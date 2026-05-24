# [TICKET-031] Popover freshness line + sparkline

## Status
`pending`

## Dependencies
- Requires: #027 ✅, #028 ✅

## Description
The menu-bar popover is the most-glanced surface, so it gets a deliberately light touch from the visualization work: a freshness line so a quick glance reveals whether the number is current, and an optional tiny sparkline that hints at the recent trend without opening the main window. The full charts and split figures stay in the main window (per the agreed scope) to keep the 320pt popover uncluttered.

Both additions reuse what's already built — `FreshnessLabel` from #028 and the `dailyTrend` series from #027 — so this is mostly composition within the existing `PopoverView` layout.

## Acceptance Criteria
- [ ] A `FreshnessLabel(lastSampleTimestamp: store.lastSampleTimestamp)` line appears in the popover (under `NetworkLine` or in the footer), styled to fit the 320pt width
- [ ] A `Sparkline` view renders an axis-less (~28pt tall) `AreaMark`/`LineMark` of per-day `dailyTrend` totals in `Color.tally.brand400`, placed above the top-apps header
- [ ] The sparkline is gated to `state == .ready` (hidden during `.collecting`)
- [ ] The popover keeps its fixed 320pt frame; nothing else in the popover layout shifts or regresses
- [ ] The existing popover `#Preview`s still compile — add a `mockLastSampleTimestamp` (and mock `dailyTrend`) to the preview-mock block

## Design Reference
- **Layout**: existing `PopoverView.swift` (keep the 320pt frame and current ordering)
- **Tokens**: `Color.tally.brand400`, `Font.tally.caption`, `Color.tally.fg3`

## Visual Reference
Clicking the menu-bar icon shows the usual popover — hero GB, progress bar, network line — now with a small "更新於 1 分前" line (tiny green dot when live) tucked under the network row. Just above the "這個月用最多的" list, a slim amber sparkline traces the last several days' usage, no axes or labels — a quiet glanceable trend.

## Implementation Notes
- **Files to modify/create**: `Tally/Sources/MenuBar/PopoverView.swift`; **create** `Tally/Sources/MenuBar/Subviews/Sparkline.swift`
- `Sparkline`: `import Charts`; `.chartXAxis(.hidden)`, `.chartYAxis(.hidden)`, fixed height, single series of `DailyUsage.total`
- The popover already reads the shared `store` (`PopoverView.swift:18`), so the new `@Observable` properties flow in automatically
- **Voice**: Chinese-only user-facing strings; no technical identifiers — audited at Checkpoint 5

## Testing
- Xcode canvas: popover `#Preview`s compile and render (ready + collecting)
- `xcodebuild -project Tally.xcodeproj -scheme Tally build`, run → open popover → freshness line present; sparkline shows when ready, hidden while collecting; frame stays 320pt
- Confirm the popover freshness line and the Overview freshness label agree at the same moment
