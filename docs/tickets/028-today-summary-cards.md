# [TICKET-028] Today card (↓/↑ split) + freshness label + week/month tiles

## Status
`blocked`

## Dependencies
- Requires: #025 ✅, #026, #027

## Description
The hero number answers "how much this month" but never "how much today", and download vs. upload are always merged. This ticket builds the three non-chart presentation pieces of the new Overview section:

1. **TodayCard** — today's usage split into received (↓) and sent (↑), each formatted with `ByteFormat.adaptive`.
2. **FreshnessLabel** — the "● 即時 / 更新於 X 前" indicator that finally tells the user whether the number is live; reused by the popover in #031.
3. **WeekMonthSummary** — three compact tiles (今天 / 本週 / 本月) giving period totals at a glance.

All three are presentation-only, driven by the `@Observable` state added in #026/#027, and follow the established card language (borders + radius, no shadows). The hero number and Top-10 list stay combined — the in/out split is intentionally scoped to Today + the chart only.

## Acceptance Criteria
- [ ] `TodayCard` renders a "今天" header and two rows — received (↓, `Color.tally.brand400`) and sent (↑, `Color.tally.fg2`) — each via `ByteFormat.adaptive(...)`, and embeds `FreshnessLabel`
- [ ] `FreshnessLabel` computes age from `lastSampleTimestamp`: `< ~10s` → `Color.tally.success` dot + "● 即時"; otherwise `Color.tally.fg3` + "更新於 X 分前 / X 秒前"; hidden when the timestamp is `nil`
- [ ] `FreshnessLabel` wraps its relative time in `TimelineView(.periodic(from:.now, by: 30))` so it refreshes without a manual timer
- [ ] `WeekMonthSummary` shows 今天 / 本週 / 本月 totals (今天 + 本週 from new state, 本月 from existing `monthToDateBytes`) via `ByteFormat.gigabytes`
- [ ] Cards use `Color.tally.bgCard`, `RoundedRectangle(cornerRadius: Radius.r12)`, 1pt `Color.tally.border` stroke, `Spacing.s5` padding — matching `HeroCard.swift:35-42`; all three render correctly in light + dark
- [ ] Each view ships a `#Preview` with mock `BytePair` / timestamp data (live, stale, and nil-freshness cases)

## Design Reference
- **Tokens / type / color**: `docs/system-design/preview/typography.html`, `colors.html`; `Font.tally.*`, `Color.tally.*`, `Radius.r12`, `Spacing.s5`
- **Card frame**: existing `HeroCard.swift` (reuse the surface chrome verbatim)

## Visual Reference
Below the hero card, a "今天" card shows two stacked rows: a down-arrow with "收到 2.4 GB" tinted honey-amber, and an up-arrow with "送出 0.3 GB" in muted grey. A small line beneath reads "更新於 數秒前" with a tiny green dot when live. Further down, three small side-by-side tiles labelled 今天 / 本週 / 本月 each show a GB figure — calm, evenly spaced, same warm-grey borders as the rest of the Overview.

## Implementation Notes
- **Files to create**: `Tally/Sources/MainWindow/Overview/TodayCard.swift`, `FreshnessLabel.swift`, `WeekMonthSummary.swift`
- Use SF Symbols `arrow.down` / `arrow.up`; keep received/sent colors consistent with the chart legend in #029 (received = `brand400`, sent = `brand200`/`fg2`)
- **Voice**: user-facing labels are friendly Traditional Chinese (e.g., 收到 / 送出, not 下載/上傳/Download/Upload). No technical identifiers in any `Text(...)` — the Checkpoint 5 voice audit will grep for the forbidden term list
- Wire into the screen in #030 — this ticket only builds the components + previews

## Testing
- Xcode canvas: each `#Preview` renders; toggle appearance for dark-mode parity
- Drive `FreshnessLabel` with a timestamp `now`, `now-90s`, and `nil` → "● 即時", "更新於 1 分前", hidden
- `xcodebuild -project Tally.xcodeproj -scheme Tally build` succeeds
