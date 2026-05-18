# [TICKET-005] TEST: Checkpoint 0 — Foundation

## Status
`blocked`

## Dependencies
- Requires: #004

## Description
This is the first gate. Phase 1 (TICKET-001 through TICKET-004) built the project scaffold, design tokens, persistence, and the app-level state machine. Before any data pipeline or UI work begins, we verify these foundations land cleanly together — a broken token system or migration bug discovered later wastes a sprint's worth of UI debugging.

This checkpoint executes a small end-to-end smoke test of everything Phase 1 produced: the project builds, the database opens and migrates, seed data is intact, design tokens render in a preview, the app boots through its logged sequence, and both scenes share one `AppState`.

Passing this checkpoint unlocks Phase 2 (data pipeline + menu bar popover).

## Acceptance Criteria
- [ ] **Build**: `Tally.xcodeproj` builds with zero warnings on a clean checkout (`xcodebuild -project Tally.xcodeproj -scheme Tally clean build` succeeds)
- [ ] **Migrations**: First-launch on a clean Application Support directory produces `tally.sqlite` with all 4 tables; relaunch does not re-run completed migrations
- [ ] **Seed data**: `SELECT category_name, COUNT(*) FROM process_categories GROUP BY category_name;` returns 5 categories, all expected names
- [ ] **Design tokens**: Open `TokensPreview.swift` in Xcode → swatch grid renders, hex values visually match `docs/system-design/preview/colors.html`. Toggle macOS dark mode → swatches update
- [ ] **Boot log**: Console.app filtered `subsystem:app.tally` shows ordered `[db] opened` → `[db] migrations done` → `[store] init` → `[collector] starting`
- [ ] **Shared AppState**: Menu bar placeholder and main window placeholder both read the same `AppState` instance (verified via temporary `ObjectIdentifier` debug text or equivalent)
- [ ] **No regressions**: AppIcon and menu bar icon from TICKET-001 still render after the changes in TICKET-002 / TICKET-003 / TICKET-004

## Implementation Notes
This is a manual test execution ticket — no code changes unless bugs are found during testing.

Common failure modes to watch for:
- Migrations running twice (the GRDB `migrator.registerMigration` block must be idempotent — duplicate `INSERT INTO process_categories` is the most likely source)
- Token preview hex mismatch — usually a dark-mode color initializer that picked the wrong NSAppearance
- Two `AppState` instances — happens if one scene constructs its own copy instead of reading from `@Environment`

If bugs are found, fix them in the relevant earlier ticket's files; do not absorb the fix into this ticket. Record bugs and fixes in the PR description that lands this ticket.

## Testing
1. Delete `~/Library/Application Support/Tally/` to simulate a clean install
2. `xcodebuild -project Tally.xcodeproj -scheme Tally clean build` — confirm zero warnings
3. ⌘R in Xcode → wait for boot
4. Open Console.app → filter `subsystem:app.tally` → confirm 4-step log
5. `sqlite3 ~/Library/Application\ Support/Tally/tally.sqlite "SELECT category_name, COUNT(*) FROM process_categories GROUP BY category_name;"` → 5 categories, expected counts
6. Open `TokensPreview.swift` canvas → spot-check 5–10 token swatches against the CSS source
7. Toggle macOS Appearance (System Settings → Appearance → Dark) → tokens swap
8. Quit and relaunch app → no duplicate seed inserts (count remains 5 categories)
9. Document outcome in the PR (pass/fail per criterion); on full pass, mark `done` and unblock Phase 2 tickets
