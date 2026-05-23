# [TICKET-015] Top 10 apps with system-category grouping

## Status
`pending`

## Dependencies
- Requires: #008 ✅, #014 ✅


## Description
The Top 10 apps section sits below the hero card and status line on the Overview screen. Each row is a card showing an app icon, app name, monthly usage in GB, and percentage of total. System processes (the 5 categories from PRD §8) collapse into their friendly names — `mDNSResponder` rows under "系統其他", `bird` under "iCloud", etc. — with the SF Symbol icons from `process_categories.icon_name`.

Critically, PRD §15 forbids `mDNSResponder` (and any other technical identifier) from ever appearing in the general-mode UI. This ticket includes a `ProcessCategorizer` that:
1. Reads `process_categories` table at boot
2. Given a `daily_aggregates` row, returns either an `.app(bundle_id)` view-model entry (resolved via `AppMetadataService` from TICKET-008) or a `.category(name)` entry (also resolved via `AppMetadataService`)
3. Bundles up unmapped daemons into "系統其他" and logs the unmapped names so TICKET-007's helper resolver or this seed table can be extended (PRD §8: "Mapping 不到的 process 統一進「系統其他」並記錄下來方便迭代時補上")

## Acceptance Criteria
- [ ] `TopAppsSection` view shows up to 10 rows below the status line, sourced from `usageStore.topApps(limit: 10)` filtered through `ProcessCategorizer`
- [ ] Each row is a card: 56pt tall, 1pt `--border` stroke, `Radius.r8`, `--bg-card` fill, no shadow
- [ ] Row layout: 32pt icon (left, with `Spacing.s4` leading padding), app/category name (`Font.tally.body`), spacer, GB value (`Font.tally.callout` mono digits, right-aligned), percentage in `--fg-3` (e.g., "(34%)")
- [ ] Hover state: 5% background darken using `Color.tally.bgCard` overlay; press state: 4% darker than hover
- [ ] System processes collapse into 5 category rows: iCloud, Time Machine 備份, 軟體更新, Spotlight 搜尋, 系統其他 — each shown with its SF Symbol icon
- [ ] Unmapped daemon rows funnel into 系統其他 (do NOT appear as their own rows under any technical name)
- [ ] Unmapped daemons are logged exactly once per session via `Log.agg` at debug level for future mapping updates
- [ ] Percentages sum sensibly: the top 10 (including categories) percentages relate to the cycle total — top 10 sum may be ≤ 100% if there's a long tail
- [ ] Voice + visual audit: no `mDNSResponder`, `bird`, `cloudd`, `bundle.id`, or similar technical strings visible anywhere

## Design Reference
- **Layout**: `docs/system-design/ui_kits/macos_app/OverviewScreen.jsx` (Top 10 section), `AppRow.jsx` if present
- **Tokens**: `Radius.r8`, `Spacing.s4`, `Color.tally.bgCard`, `Color.tally.border`, `Font.tally.body`, `Font.tally.callout`
- **Icons**: SF Symbols per `process_categories.icon_name` for system categories; `NSImage` from `NSWorkspace` for apps

## Visual Reference
Below the estimate sentence on the Overview pane, a section title "這個月用最多的" sits left-aligned. Below it, up to 10 stacked rows — each a clean white card with a thin border. The first row might show the Chrome icon, "Google Chrome", "4.2 GB", "(34%)". The second might show the iCloud SF Symbol, "iCloud", "2.1 GB", "(17%)". A third might show the Spotlight glass icon, "Spotlight 搜尋", "0.4 GB", "(3%)". Each row is 56pt tall, comfortably spaced from its neighbors by `Spacing.s2` (8pt). Hover darkens the card; click does nothing in MVP (per-app detail page is v0.2). No row anywhere shows `mDNSResponder`, `bird`, or a bundle id.

If fewer than 10 entries exist in the current cycle, only those that exist render — there's no padding with empty rows.

## Implementation Notes
- **Files to create**: `MainWindow/Overview/TopAppsSection.swift`, `MainWindow/Overview/AppRow.swift`, `Categorization/ProcessCategorizer.swift`, `Categorization/AppOrCategoryEntry.swift`
- **`ProcessCategorizer` boot**: reads `process_categories` once into an in-memory `[String: ProcessCategory]` keyed by `process_identifier` (executable name)
- **Categorization logic**: when iterating `daily_aggregates` rows:
  - If `bundle_id` is non-NULL and resolves via `AppMetadataService` → `.app(bundle_id)`
  - Else if `executable_name` matches a `process_identifier` in the table → `.category(category_name)`
  - Else → `.category("系統其他")` AND log the unmapped name at debug level
- **Aggregation in the view layer**: multiple raw rows may collapse into one `.category("iCloud")` entry — sum their bytes before constructing the view model
- **Top N selection**: after categorization, sort by total bytes DESC, take 10. This is a `UsageStore` responsibility, not the view's — extend `usageStore.topApps` to use the categorizer
- **Row hover/press**: use `.onHover { hovering in ... }` and `.gesture(LongPressGesture(minimumDuration: 0))` patterns. SwiftUI Buttons on macOS handle press state automatically — wrap the row in a Button with `.buttonStyle(.plain)`
- **Unmapped logging**: dedupe per-session via a `Set<String>` on the categorizer — first encounter logs, subsequent occurrences silent
- **Click target in MVP**: PRD §13 roadmap puts per-app detail at v0.2; rows are not actionable in MVP. Keep the row as a non-button to avoid suggesting interactivity, OR keep it as a button that does nothing — pick the visual that feels more honest (recommend: not a button, just a card)

## Testing
- Open Overview after ≥ 2 minutes of activity → Top apps section shows 5–10 rows
- Visual scan: no row shows a bundle id, a process executable name (`bird`, `mDNSResponder`), or English technical strings
- SQL ground truth: `sqlite3 ... "SELECT category, SUM(total_in+total_out) FROM daily_aggregates WHERE category IS NOT NULL GROUP BY category"` matches category row totals in the UI
- Force-route an unmapped daemon (e.g., a kernel-level process not in `process_categories`) → it appears under "系統其他", and `Log.agg` logs "unmapped: <name>" exactly once
- Toggle dark mode → cards swap surface + border tokens correctly
- Hover a row → 5% darken visible; press → further darkens; release → returns
- Cross-check with `docs/system-design/ui_kits/macos_app/index.html` Overview view side-by-side
