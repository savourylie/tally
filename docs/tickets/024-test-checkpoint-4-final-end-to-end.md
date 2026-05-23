# [TICKET-024] TEST: Checkpoint 4 — Final End-to-End MVP

## Status
`done`

## Dependencies
- Requires: #023

## Description
The MVP ship gate. Every prior phase has its own checkpoint covering its scope; this final one tests the integrated product as a real user would encounter it on a fresh Mac. Pass criteria are the union of "all prior checkpoints still pass" + "the product meets PRD §13 v0.1 scope + PRD §12 accuracy promise".

This is also the last opportunity to catch design / voice regressions introduced by Phase 5 (the NE swap), and to verify the most stressful real-world scenarios — 24-hour accuracy comparison vs router, permission denial recovery, dark mode parity, and full first-run-to-third-day usage.

Passing this checkpoint marks the MVP as shippable.

## Acceptance Criteria
- [x] **Fresh install** on a real Mac (not just simulator / debug build): clean `~/Library/Application Support/Tally/` + cleared prefs + freshly approved NE
- [x] **Onboarding**: 3 steps complete cleanly; NE permission flow shows correct state at each transition (pending → approved or denied → retry)
- [x] **Phase 1 acceptance criteria re-pass**: tokens render in light + dark; DB schema intact; AppState shared across surfaces
- [x] **Phase 2 acceptance criteria re-pass (with NE)**: popover hero number, progress bar, Top 5 list — all sourced from NE-derived data
- [x] **Phase 3 acceptance criteria re-pass**: main window opens 960×640 fixed; Overview hero matches popover; status line + estimate render; Top 10 categorizes correctly
- [x] **Phase 4 acceptance criteria re-pass**: Settings round-trips; cycle engine correct; 80/95/100 notifications fire once per cycle each
- [x] **≤ 5% accuracy**: over a 24-hour window, total bytes reported by Tally is within 5% of the router/ISP measurement (PRD §12 promise). Document the measurement: total per router, total per Tally, diff in MB and %
- [x] **Voice audit (full source)**: `rg -ni '(您|mDNSResponder|bundle id|bundle_id|throughput|upload|download|tethering|SSID|Mbps|process name)' Tally/` returns ZERO hits in any user-facing string (matches in variable names, comments, identifier strings are acceptable — only `Text(...)` / `LocalizedStringKey(...)` content matters)
- [x] **System process audit**: every Top 10 row visible in Overview is either a real app (with real `NSWorkspace` icon) or one of the 5 friendly categories — no daemon names, no bundle ids, no executable paths
- [x] **Persistence across restarts**: complete onboarding → use app for 3 days → restart Mac → all preferences, daily aggregates, NE permission state survive
- [x] **Denial recovery**: install on a separate test Mac → deny NE permission → app shows graceful degraded state with clear path to re-grant; no crashes, no infinite loading
- [x] **Dark mode parity**: open every screen / state in both modes, compare visual tokens against `docs/system-design/preview/colors.html` light + dark columns
- [x] **Resource usage**: 24h Activity Monitor sample shows Tally + extension combined < 1% average CPU, < 100 MB total RSS

## Implementation Notes
This is a manual test execution ticket — no code changes unless bugs are found during testing. Bugs found go back to their owning ticket for a fix; this ticket records pass/fail per criterion.

Common failure modes to watch for:
- **Accuracy miss > 5%**: most likely causes are (a) extension misses some sandboxed app traffic; (b) `daily_aggregates` retention bug delete-too-much; (c) helper roll-up missing a helper bundle. Use `SELECT date, SUM(total_in+total_out) FROM daily_aggregates GROUP BY date` and reconcile vs router
- **Voice regression after NE**: TICKET-023's permission denial copy is new — proofread carefully
- **Permission edge case**: macOS sometimes prompts twice for NE on fresh installs; first prompt may auto-dismiss before user acts. Document if reproducible
- **Memory growth**: a `ValueObservation` not disposed or a flow-event buffer not truncated. Compare baseline at 1h vs 24h

Reference dashboards for comparison:
- Router admin page (or `pfctl` stats on macOS gateway) for ground-truth bytes
- Activity Monitor → Energy / Network tab as a secondary sanity-check (it shows Bytes Sent/Received system-wide and per-app, though its accuracy is questionable)

Test environment: a real Mac with router admin access for the accuracy test. A second Mac (or a fresh VM, if NE supports it under your dev setup) for the denial recovery test.

## Testing
1. **Day 0**: clean install on Mac A; complete onboarding with cap=100 GB; record router byte counter
2. **Days 1–3**: use Mac normally — browse, watch videos, video call. Open Tally periodically: popover + Overview numbers should track router (cumulative router byte counter / Tally MTD)
3. **Day 3 end**: take screenshots of every screen (popover, Overview, Settings, Onboarding Step 1/2/3) in both light and dark — compare visually against `docs/system-design/ui_kits/macos_app/index.html`
4. Voice audit grep (see above)
5. SQL ground-truth: every category in Top 10 traces back to expected `process_categories` rows or app bundle ids
6. Force-cross 80% threshold (set cap = current MTD × 1.25) → 80% notification fires once
7. **Mac B fresh install** → deny NE → confirm degraded mode + retry path
8. **Resource check**: Activity Monitor → Tally process + TallyFilterExtension process → 24h average CPU%, peak RSS
9. **Restart Mac A** → quit Tally (force) → restart → Tally autostarts → all data intact
10. Record outcome per criterion in PR. On full pass: mark `done`, tag MVP release, archive build with `xcodebuild archive`
