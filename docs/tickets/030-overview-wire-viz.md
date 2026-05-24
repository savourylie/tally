# [TICKET-030] Wire data-viz components into the Overview screen

## Status
`blocked`

## Dependencies
- Requires: #028, #029

## Description
With the components built (#028, #029) and the data published (#026, #027), this ticket assembles them into the Overview pane — the main-window surface chosen as the primary home for the visualization work. It is the integration step that turns the new pieces into a coherent screen.

The existing stack (HeroCard → StatusLine → EstimateSentence → TopAppsSection) is preserved; the new views slot in around it. Because `UsageStore` is `@Observable`, no manual binding plumbing is needed beyond exposing `trendWindow` to the chart's picker.

## Acceptance Criteria
- [ ] `OverviewScreen` inserts, in order: HeroCard (unchanged) → StatusLine (unchanged) → **TodayCard** → EstimateSentence (unchanged) → **WeekMonthSummary** → **DailyTrendChart** → TopAppsSection (unchanged)
- [ ] New views read from `appState.usageStore` (`store.todayBytes`, `store.lastSampleTimestamp`, `store.weekBytes`, `store.dailyTrend`); the chart picker binds to `store.trendWindow` via `@Bindable`
- [ ] The screen recomputes reactively as store state changes — no extra observers added to the view body
- [ ] Spacing between the new and existing sections matches the existing inter-card rhythm (same `Spacing` value used between current cards)
- [ ] HeroCard and TopAppsSection are visually unchanged (still combined totals)

## Design Reference
- **Layout**: existing `OverviewScreen.swift` VStack; `docs/system-design/ui_kits/macos_app/OverviewScreen.jsx` for section rhythm
- **Tokens**: existing `Spacing.*` between cards

## Visual Reference
Scrolling the Overview top-to-bottom: the familiar big "這個月用了" hero, then the network status line, then the new "今天" card with ↓/↑ and freshness, then the projection sentence, then the three 今天/本週/本月 tiles, then the daily trend bar chart, and finally the Top-10 apps list. Everything shares the same warm-grey card borders and spacing — the new sections feel native, not bolted on.

## Implementation Notes
- **Files to modify**: `Tally/Sources/MainWindow/Overview/OverviewScreen.swift`
- `store` is already `appState.usageStore` (see `OverviewScreen.swift:7`); use `@Bindable var store = appState.usageStore` in the body for the picker binding
- Keep the screen scrollable; the added chart increases content height
- No data or component logic here — pure composition. If a spacing constant is missing, reuse the existing inter-card value rather than introducing a new token

## Testing
- `xcodebuild -project Tally.xcodeproj -scheme Tally build`, run the app → open the main window → Overview
- Verify the section order above; confirm TodayCard's number tracks live traffic and equals the chart's today bar
- Toggle the trend picker (本期 ↔ 近 30 天) → chart re-ranges
- Toggle dark mode → all sections swap tokens cleanly
