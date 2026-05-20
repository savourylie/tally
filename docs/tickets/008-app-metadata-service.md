# [TICKET-008] App metadata service (NSWorkspace)

## Status
`done`

## Dependencies
- Requires: #005 ✅

## Description
Build a service that, given a `bundle_id` (or fallback `executable_name`), returns the localized display name and an `NSImage` icon for use in the UI. The PRD design system shows real app icons + names in the popover (TICKET-010) and Overview (TICKET-015) — never raw bundle ids. Looking up app metadata is fast but not free; caching is essential.

For system process categories (PRD §8), the service returns the friendly category name + SF Symbol icon instead of trying to resolve a bundle. The categorizer in TICKET-015 decides whether a row should be presented as an app or as a category — this service serves both kinds of lookups.

## Acceptance Criteria
- [x] `AppMetadataService.metadata(forBundleID:)` returns `AppMetadata { displayName: String, icon: NSImage }` for any installed app
- [x] `AppMetadataService.metadata(forCategory:)` returns category metadata using the `process_categories` table seeded in TICKET-003 (display name + SF Symbol `NSImage`)
- [x] In-memory cache: repeated lookups for the same key return in < 1ms after the first call
- [x] Cache invalidation: `NSWorkspace.shared.notificationCenter` observers for `didLaunchApplicationNotification` / `didTerminateApplicationNotification` evict stale entries
- [x] Unknown bundle ids fall back to a placeholder: `displayName = bundle_id` (will be hidden from UI by the categorizer in TICKET-015), `icon = systemImage "questionmark.app.dashed"` — UI tickets must not crash on missing metadata
- [x] Icons are returned at 32pt size (HiDPI-aware via `NSImage`'s natural representations); higher-resolution requests in TICKET-015 work without re-fetching

## Implementation Notes
- **Files to create**: `Services/AppMetadataService.swift`, `Services/AppMetadata.swift` (the struct)
- **Lookup path** for bundle ids: `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` → `Bundle(url:)` → `localizedInfoDictionary["CFBundleDisplayName"]` / `infoDictionary["CFBundleName"]`. Icon via `NSWorkspace.shared.icon(forFile: appURL.path)`
- **System processes**: the categorizer (TICKET-015) calls `metadata(forCategory:)` with names from `process_categories.category_name`. The service does a one-time DB read on init to load the 5-row mapping; SF Symbol → `NSImage` via `NSImage(systemSymbolName:accessibilityDescription:)`
- **Caching**: `actor AppMetadataService { var cache: [Key: AppMetadata] = [:] }` (actor isolation handles concurrent reads from menu bar + main window). Key is an enum `.bundleID(String) | .category(String)`
- **Localized name preference**: prefer `CFBundleDisplayName` then `CFBundleName` then app URL's `lastPathComponent` minus `.app`
- **Inject via AppState**: TICKET-004's `AppState` gains an `appMetadata: AppMetadataService` slot; UI views consume from environment

## Testing
- Add a temporary debug button that calls `service.metadata(forBundleID: "com.apple.Safari")` and prints → returns "Safari" + an icon visible in a SwiftUI `Image(nsImage:)`
- Same for `"com.google.Chrome"` (must be installed) → "Google Chrome" + Chrome icon
- `service.metadata(forCategory: "iCloud")` → "iCloud" + `icloud.fill` SF Symbol
- `service.metadata(forBundleID: "com.fake.notinstalled")` → returns placeholder, no crash
- Quit Slack and relaunch → service cache evicts and re-fetches (visible via debug log on next lookup)
- Lookup performance: 1000 sequential lookups of cached keys complete in < 50ms total
