# [TICKET-003] GRDB setup + schema + seed

## Status
`blocked`

## Dependencies
- Requires: #001

## Description
Add the GRDB SQLite dependency, build a single `DatabaseManager` that opens / migrates the database, define all four tables from PRD §11 (`flow_samples`, `daily_aggregates`, `networks`, `process_categories`) in an initial migration, and seed `process_categories` with the five mappings from PRD §8.

Establishing the schema once, up front, prevents migration churn later: the collector (TICKET-006), aggregator (TICKET-007), store (TICKET-009), and categorizer (TICKET-015) all read or write these tables. The PRD lists the schema explicitly; this ticket implements it 1-to-1 plus the fields each downstream consumer needs.

## Acceptance Criteria
- [ ] GRDB.swift is added as a Swift Package dependency to the Tally app target
- [ ] `DatabaseManager` opens a `DatabasePool` at `~/Library/Application Support/Tally/tally.sqlite` (creating the directory if missing) and is reachable as a singleton or environment value
- [ ] An initial migration creates `flow_samples`, `daily_aggregates`, `networks`, `process_categories` with the columns documented in PRD §11
- [ ] `process_categories` is seeded with 5 rows: iCloud, Time Machine 備份, 軟體更新, Spotlight 搜尋, 系統其他 — each with the SF Symbol icon names from PRD §8 and a packed list of `process_identifier` patterns
- [ ] Schema is verifiable via `sqlite3 tally.sqlite ".schema"` and `SELECT category_name FROM process_categories;` returns the 5 seeded rows
- [ ] Migrations are idempotent — relaunching the app does not re-run completed migrations or duplicate seed rows

## Implementation Notes
- **Files to create**: `Database/DatabaseManager.swift`, `Database/Migrations/InitialMigration.swift` (or a single `Migrations.swift` with all migrations registered)
- **GRDB Package URL**: `https://github.com/groue/GRDB.swift`, pin to a recent stable major (6.x or later)
- **Indexes**: add `(timestamp)` on `flow_samples`, `(date, bundle_id)` on `daily_aggregates`, `(process_identifier)` on `process_categories` — downstream queries will need them
- **Field types** (per PRD §11, with concrete SQL types):
  - `flow_samples`: `id INTEGER PK`, `timestamp INTEGER` (epoch seconds), `bundle_id TEXT NULL`, `executable_name TEXT NULL`, `bytes_in INTEGER`, `bytes_out INTEGER`, `network_id INTEGER FK`
  - `daily_aggregates`: `id INTEGER PK`, `date TEXT` (ISO yyyy-MM-dd), `bundle_id TEXT NULL`, `category TEXT NULL`, `network_id INTEGER FK`, `total_in INTEGER`, `total_out INTEGER`, UNIQUE `(date, bundle_id, category, network_id)`
  - `networks`: `id INTEGER PK`, `ssid TEXT NULL`, `interface_type TEXT`, `is_hotspot INTEGER` (bool), `monthly_limit_gb REAL NULL`
  - `process_categories`: `id INTEGER PK`, `process_identifier TEXT UNIQUE`, `category_name TEXT`, `icon_name TEXT`, `display_name TEXT`
- **Seed pattern**: store each process pattern as its own row keyed by `process_identifier`; the categorizer (TICKET-015) does exact-match lookup. PRD §8 listing:
  - iCloud → `bird`, `cloudd`, `cloudphotod`, `CloudKit`, `apsd`; icon `icloud.fill`
  - Time Machine 備份 → `backupd`, `backupd-helper`; icon `externaldrive.fill.badge.timemachine`
  - 軟體更新 → `softwareupdated`, `osinstallersetupd`; icon `arrow.down.circle.fill`
  - Spotlight 搜尋 → `mds`, `mdworker_shared`, `mds_stores`; icon `magnifyingglass`
  - 系統其他 → `mDNSResponder`, `trustd`, `nsurlsessiond`; icon `gearshape.fill`
- **Retention**: PRD §11 says `flow_samples` is retained 7 days; the cleanup job lives in TICKET-007 (aggregator). This ticket only models the table; no retention logic here.

## Testing
- Build and launch app → `tally.sqlite` exists at `~/Library/Application Support/Tally/`
- `sqlite3 ~/Library/Application\ Support/Tally/tally.sqlite ".schema"` → 4 tables present with documented columns
- `sqlite3 ... "SELECT process_identifier, category_name FROM process_categories ORDER BY id;"` → 15 rows (5 iCloud + 2 Time Machine + 2 Software Update + 3 Spotlight + 3 System Other), each category represented
- Delete the sqlite file → relaunch → re-creates and re-seeds. Run again without deletion → no duplicate seed rows
