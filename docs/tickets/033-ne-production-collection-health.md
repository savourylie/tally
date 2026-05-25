# [TICKET-033] Production Network Extension collection health

## Status
`done`

## Dependencies
- Requires: #023 ✅
- Discovered during: #032 manual checkpoint

## Description
Checkpoint #032 exposed a production data-collection failure: the UI could show old monthly aggregate data as ready even when the production Network Extension path was not producing live `flow_samples` rows. During the 2026-05-25 manual test, the database's latest live row was from 2026-05-23 15:39 HKT, so the TodayCard, freshness label, and today's trend bar had no current source data to render.

This ticket makes production collection health explicit. Tally should verify the macOS content-filter configuration on launch, start the NE collector only when the expected Tally filter is enabled, and show a clear non-live state when collection is unavailable. The verification target stays the signed `/Applications/Tally.app` flow; do not add an automatic DEBUG `nettop` fallback here.

## Acceptance Criteria
- [x] On launch, Tally loads `NEFilterManager` and confirms the enabled provider bundle id is `com.calvinku.tally.filter` before treating production collection as live
- [x] If the filter is disabled but Tally is running from `/Applications/Tally.app`, the app attempts to re-enable the existing production content filter idempotently
- [x] If Tally is running from DerivedData or another unsupported location and the filter is not already enabled, activation is rejected with the existing move-to-Applications recovery path
- [x] `NEFlowCollector` starts polling only after the content filter is confirmed enabled; otherwise its state becomes `.failed(...)`
- [x] The app never presents stale aggregate data as a live/ready collection state when there are no current `flow_samples` rows for today
- [x] Failure and recovery copy shown to users is Chinese-only and avoids technical identifiers
- [ ] Existing onboarding approval behavior continues to work for a fresh install and for retry after denial

## Implementation Notes
- Extend `SystemExtensionActivator` with a launch-time status check around `NEFilterManager.shared().loadFromPreferences`.
- Keep enablement idempotent: reusing the expected provider configuration should be safe when the filter is already enabled.
- Coordinate `AppState` startup so production `NEFlowCollector.start()` is gated by confirmed content-filter health.
- Prefer an explicit `.failed(...)` collector state over silently leaving the app in `.collecting` forever.
- Do not change the `DEBUG && USE_NETTOP` compile-time fallback behavior.

## Testing
1. `xcodebuild test -project Tally.xcodeproj -scheme Tally -only-testing:TallyTests/SystemExtensionActivatorTests -only-testing:TallyTests/NEFlowCollectorTests`
2. `xcodebuild -project Tally.xcodeproj -scheme Tally build`
3. From `/Applications/Tally.app`, launch with the Tally network extension enabled → collector starts without showing recovery copy
4. Disable the Tally network extension in System Settings → relaunch from `/Applications/Tally.app` → app attempts re-enable or shows recoverable non-live state
5. Launch from Xcode DerivedData with no enabled production filter → app shows the move-to-Applications recovery path instead of stale live data
6. Voice audit any new user-facing strings for Chinese-only copy
