# [TICKET-029] Daily trend chart (Swift Charts stacked bars + window picker)

## Status
`done`

## Dependencies
- Requires: #025 ✅, #027 ✅

## Description
There is no way to see usage over time today — only point-in-time totals. This ticket adds the centerpiece of the visualization work: a daily bar chart of network usage, each bar stacked into received (↓) and sent (↑) segments, over a window the user can switch between the current billing cycle and the last 30 days.

It uses **Swift Charts**, which is built into SwiftUI and available on the project's macOS 14 deployment target — no new dependency and no `@available` guards. The chart is purely presentational, reading `dailyTrend` and binding the picker to `trendWindow` from #027 (whose data already zero-fills gaps and substitutes a live "today" bar).

## Acceptance Criteria
- [x] `DailyTrendChart` renders one `BarMark` per `DailyUsage`, **stacked** by series (收 / 發) with received = `Color.tally.brand400`, sent = `Color.tally.brand200`
- [x] Y values use `ByteFormat.gigabytesValue(...)` (GB, `Double`); Y axis labelled in GB; X axis shows day-of-month marks
- [x] A segmented `Picker` ("本期" / "近 30 天") is bound to `store.trendWindow`; switching it updates the bars reactively (data swap handled by #027)
- [x] When `dailyTrend` is empty, a muted "資料正在收集中" placeholder shows in the same card frame (mirrors `HeroCard.swift:73-80`)
- [x] Chart sits in the standard card chrome (`Color.tally.bgCard`, `Radius.r12`, `Color.tally.border`, `Spacing.s5`) and reads cleanly in light + dark
- [x] `#Preview` covers a populated cycle window, a 30-day window, and the empty state with mock `[DailyUsage]`

## Design Reference
- **Net-new component** — no existing mockup. Follow the established card + token language: `Color.tally.*`, `Font.tally.*`, `Radius.r12`, `Spacing.s5`; legend colors must match TodayCard (#028)
- **Color/type previews**: `docs/system-design/preview/colors.html`, `typography.html`

## Visual Reference
A wide card titled with a small segmented control ("本期 | 近 30 天") in the top-right. Below it, a row of slim vertical bars — one per day — in honey-amber, each bar's lower segment slightly darker (sent) under a lighter top segment, or vice-versa per the legend. The x-axis shows a few date ticks; the y-axis shows GB. Today's bar reflects the live figure. With no data yet, the bars area is replaced by a centered "資料正在收集中" line, same card frame.

## Implementation Notes
- **Files to create**: `Tally/Sources/MainWindow/Overview/DailyTrendChart.swift`
- `import Charts`; emit two `BarMark`s per day (or one with `.foregroundStyle(by: .value("類型", "收"/"發"))`) so they stack; `position: .automatic` stacking is the default for same x-value marks
- Use `@Bindable var store` (or a `Binding<TrendWindow>`) for the picker; the parent passes `store` in #030
- Keep axis labels terse and Chinese; **voice**: no English technical terms (收/發, GB axis label) — Checkpoint 5 audits this
- Default chart height ~180–220pt; let width fill the content column

## Testing
- Xcode canvas: all three `#Preview` states render; toggle dark mode
- `xcodebuild -project Tally.xcodeproj -scheme Tally build` succeeds (confirms `import Charts` resolves on the macOS 14 target)
- Manual after #030 wiring: flip the picker → bars re-range between cycle and 30 days; today's bar matches the TodayCard figure
