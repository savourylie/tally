# [TICKET-011] TEST: Checkpoint 1 — Menu Bar Popover End-to-End

## Status
`done`

## Dependencies
- Requires: #010 ✅

## Description
Phase 2 (TICKET-006 through TICKET-010) built the entire dev-mode data path — `nettop` → `flow_samples` → aggregator → `daily_aggregates` → `UsageStore` → menu bar popover. This checkpoint verifies that path delivers correct, animated, friendly numbers end-to-end, and that the visual matches the design system prototype.

Most importantly: this is the moment to catch aggregation bugs and metadata gaps before they propagate to the main window in Phase 3. If the popover's Top 5 list is wrong, the Overview's Top 10 list (TICKET-015) will be wrong too — debugging it once is half the work.

Passing this checkpoint unlocks Phase 3 (main window + Overview).

## Acceptance Criteria
- [x] **Cold launch**: clean install, click menu bar icon → popover shows "資料正在收集中" placeholder
- [x] **Warm state**: after ~2 minutes of normal Mac usage, popover shows a real GB number, real progress bar, real Top 5 apps with icons + names
- [x] **Numerical accuracy**: popover hero matches `SELECT SUM(total_in + total_out) FROM daily_aggregates WHERE date BETWEEN <cycle_start> AND <today>` (within rounding to 1 decimal)
- [x] **Top 5 attribution**: every visible app name resolves to a real app (no `com.x.y` strings, no `mDNSResponder` strings); Chrome helper bytes appear under Chrome, not under a helper
- [x] **Animation**: scale 0.96 → 1.0 + fade 0 → 1 over 280ms with decel easing — matches `motion.html` demo
- [x] **Dark mode**: open popover, toggle System Settings → Appearance → Dark → popover updates without re-open; all tokens swap correctly per `docs/system-design/preview/colors.html` dark column
- [x] **No leaks**: open + close the popover 50 times → no growth in resident memory in Xcode debug navigator (within ±5 MB)
- [x] **Navigation**: clicking "打開完整畫面" opens the placeholder main window (TICKET-012 will fill it)
- [x] **Voice audit (preliminary)**: every visible string is from PRD §7's plain-language vocabulary — no English technical terms (Upload/Download, Throughput, etc.)
- [x] **No-cap branch**: in TICKET-009 placeholder, set cap = nil → progress bar hides, subtext changes (will be refined in TICKET-019)

## Checkpoint Result
- Clean-install data path initially exposed a timing bug: `flow_samples` had rows after two minutes while `daily_aggregates` stayed empty. Fixed by triggering one aggregation run after each successful collector flush.
- SQL accuracy passed after the fix: current-cycle `daily_aggregates` total matched current-cycle `flow_samples` total exactly, and popover hero rounded to the same 1-decimal GB value.
- UI verification passed via the running app's accessibility tree: visible Top 5 labels were friendly app/category names only (`Safari`, `系統其他`, `CodexBar`, `iCloud`, `Dropbox`).
- Popover open/close memory check passed: 50 open/close cycles produced no RSS growth.

## Implementation Notes
This is a manual test execution ticket — no code changes unless bugs are found during testing.

Common failure modes to watch for:
- **Helper roll-up missing**: most likely culprit is a Chrome helper bundle id pattern not matched by TICKET-007's resolver. Fix in TICKET-007's `HelperProcessResolver`, not here
- **Empty Top 5 after 2 minutes**: collector might be flushing but aggregator hasn't run yet — verify `Aggregator` timer cadence is ≤ 5 minutes; first run is supposed to happen within 10s of boot
- **Animation snaps**: SwiftUI's default `.popover` modifier ignores custom `MenuBarExtra(.window)` open transitions — the animation has to be inside `PopoverView`'s `.onAppear`. If it's snapping, the modifier is on the wrong side
- **Dark mode mismatch**: confirm `Color.tally.bgPopover` uses `Color(light:dark:)` not `Color(.sRGB, …)` literal
- **Resident memory growth**: usually a `ValueObservation` subscription that doesn't dispose — verify the store's `cancellable` is held by `AppState`, not re-created on each view body

Test environment: macOS 14+ on Apple Silicon ideally (the deployment target). Verify on Intel if available.

## Testing
1. `rm -rf ~/Library/Application\ Support/Tally/` (clean install)
2. ⌘R → click menu bar icon → confirm collecting placeholder
3. Open Safari, Slack, Chrome; browse normally for 2 minutes
4. Click menu bar icon → confirm hero number, progress bar (if cap set), Top 5 with icons + real names
5. Compare popover side-by-side with `docs/system-design/ui_kits/macos_app/index.html` (open at the same display scale)
6. SQL ground-truth: `sqlite3 ~/Library/Application\ Support/Tally/tally.sqlite "SELECT bundle_id, category, total_in + total_out FROM daily_aggregates WHERE date = date('now') ORDER BY 3 DESC LIMIT 5;"` matches popover order
7. Toggle Dark Mode → re-open popover → tokens swap
8. Open/close 50× via menu bar click → Xcode debug navigator memory steady
9. Click "打開完整畫面" → main window opens (placeholder)
10. Voice audit — scan all visible strings against PRD §7 term table
11. Record outcome per criterion in the PR. On full pass, mark `done` and unblock Phase 3
