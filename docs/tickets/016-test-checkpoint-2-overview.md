# [TICKET-016] TEST: Checkpoint 2 — Overview Screen

## Status
`blocked`

## Dependencies
- Requires: #015

## Description
Phase 3 (TICKET-012 through TICKET-015) built the main window, sidebar, and the full Overview pane. This checkpoint verifies the entire Overview experience: the window opens at the right size, sidebar navigation works, the hero number agrees with the popover, the status line and estimate render correctly, and the Top 10 list categorizes system processes into friendly names without leaking any technical identifiers.

It also includes the first **formal voice audit** against PRD §7's term table — the design system's hardest rule ("一般使用者永遠不會看到 `mDNSResponder` 這種字串") must hold across both surfaces.

Passing this checkpoint unlocks Phase 4 (Settings / Notifications / Onboarding).

## Acceptance Criteria
- [ ] **Window**: opens at exactly 960×640; cannot be resized; closes deallocate the scene (verified via Instruments allocation tracking or a `deinit` log)
- [ ] **Sidebar**: 200pt width, 總覽 + 設定 items render with selected state; clicking each routes the content area
- [ ] **Hero number agreement**: Overview mega number === popover hero number (within rounding to 1 decimal) at the same moment in time
- [ ] **Progress bar**: Overview hero progress bar fill % matches popover progress bar fill %
- [ ] **No-cap branch**: setting `monthlyLimitGB = nil` (via debug) replaces the estimate sentence with "上個月用了 **Y GB**" comparison; progress bar hides on both surfaces
- [ ] **Estimate accuracy**: with cap set, the estimate matches `mtd × daysInCycle / daysElapsed` (verified manually for one date)
- [ ] **Status line accuracy**: Wi-Fi SSID matches macOS menu bar Wi-Fi display; Ethernet shows "乙太網路"; airplane mode / disconnect shows "未連線"
- [ ] **Voice audit (full)**: grep all Swift source files for the forbidden term list — `mDNSResponder`, `bundle id`, `bundle_id` (in user-facing strings), `Throughput`, `Upload`, `Download`, `Tethering`, `SSID`, `Process` (user-facing), `Mbps` — none appear in any displayed `Text(...)` or `LocalizedStringKey(...)` content
- [ ] **Category grouping**: open Overview → every Top 10 row that comes from a system process appears under one of the 5 friendly category names; no daemon names visible
- [ ] **Unmapped logging**: confirm `Log.agg` debug log captures any unmapped daemons (compare with running `nettop -P -L 1` to find a daemon and verify it shows under 系統其他)
- [ ] **Dark mode parity**: every Overview component swaps tokens cleanly; compare against `docs/system-design/preview/colors.html` dark column for each surface

## Implementation Notes
This is a manual test execution ticket — no code changes unless bugs are found during testing.

Common failure modes to watch for:
- **Hero/popover divergence**: usually a different cycle window or a stale `UsageStore` subscription — verify both surfaces read the same store instance from `AppState`
- **System process leakage**: most likely a path in `ProcessCategorizer` that returns an `.app` entry when it should return `.category`. Fix the categorization fall-through order: bundle id → category match → "系統其他"
- **Window not deallocating**: a `Task` captured `AppState` strongly inside the view — verify all long-lived observers are owned by `AppState`, not view bodies
- **Estimate off by 1**: usually `daysInCycle` and `daysElapsed` indexing — write a small standalone test with `Calendar.current` to verify

Test environment: same as Checkpoint 1 — macOS 14+ Mac with normal browsing activity for at least 30 minutes prior.

## Testing
1. Cold launch (clean Application Support) → click menu bar → click "打開完整畫面" → main window opens
2. Verify hero mega number matches popover hero number exactly
3. Click 設定 → placeholder shows; click 總覽 → returns
4. Toggle dark mode → both panes update; Top 10 cards swap surface tokens
5. Force network change (toggle Wi-Fi) → status line updates within ~2s
6. Set cap = nil via debug toggle → estimate sentence becomes "上個月用了…"
7. Voice audit:
   ```bash
   rg -i '\b(mDNSResponder|bundle id|bundle_id|throughput|upload|download|tethering|SSID|Mbps)\b' Tally/Sources/
   ```
   — confirm zero hits in any `Text(...)` / `LocalizedStringKey` content (matches in code comments or var names are fine; matches in user-facing strings are not)
8. SQL spot-check: `SELECT bundle_id, category, SUM(total_in+total_out) FROM daily_aggregates WHERE date BETWEEN <cycle_start> AND <today> GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 15;` → reconcile with Overview Top 10 (account for category collapse)
9. Close main window → ⌘B in Xcode + memory snapshot in Instruments → main window allocations release
10. Reopen via popover → window rebuilds; selection persists from in-memory state
11. Record results per criterion in the PR. On full pass, mark `done` and unblock Phase 4
