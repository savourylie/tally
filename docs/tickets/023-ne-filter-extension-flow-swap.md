# [TICKET-023] NEFilterDataProvider + IPC + flow swap

## Status
`blocked`

## Dependencies
- Requires: #022

## Description
Wire in the real production data path: an `NEFilterDataProvider` System Extension that observes per-flow bytes attributed to bundle id, sends them to the host app via shared App Group, and replaces `NettopCollector` (TICKET-006) as the primary `FlowCollector`. Per PRD §10 this swap is intentionally last so the rest of the app is fully built and verified before the heaviest piece of macOS infrastructure goes in.

Three concerns land in this ticket:
1. **New target**: a System Extension target (`TallyFilterExtension`) with `com.apple.developer.networking.networkextension` entitlement scoped to `content-filter-provider`.
2. **IPC**: the extension can't directly write to the host's GRDB database — instead, it writes flow events to a shared App Group container (e.g., a serialized log of `FlowEvent` records), and the host app's `NEFlowCollector` reads from there and writes to `flow_samples`. This matches the `FlowCollector` protocol introduced in TICKET-006.
3. **Onboarding Step 2 refinement**: this is when the user actually needs to grant the permission. Step 2 now monitors `OSSystemExtensionRequest` status and surfaces denial / retry properly. The "已經批准了" button becomes "繼續" once the extension is enabled, with explicit denial guidance if `OSSystemExtensionRequestRejected`.

After this ticket, `NettopCollector` remains compiled (DEBUG-only) as a fallback for developer convenience but is NOT used in release builds.

## Acceptance Criteria
- [ ] A new Xcode target `TallyFilterExtension` exists, containing an `NEFilterDataProvider` subclass and its `Info.plist`
- [ ] App group `group.com.calvinku.Tally` is configured on both host and extension targets; both can read/write to the container
- [ ] Host entitlement file lists `com.apple.developer.networking.networkextension` with `["content-filter-provider"]`
- [ ] Host code activates the extension via `OSSystemExtensionRequest` on first launch after onboarding step 2; status events update onboarding UI
- [ ] `NEFlowCollector: FlowCollector` reads flow records from the shared container (a serialized append-only file or a small SQLite the extension writes to), inserts them into `flow_samples`, and drives `UsageStore` exactly like `NettopCollector` did
- [ ] In release builds, `NEFlowCollector` is the active collector; in DEBUG builds with a flag (e.g., `-DUSE_NETTOP`), `NettopCollector` is still selectable
- [ ] After granting NE permission, real per-app attribution is visible: open Safari, browse Twitter for 30 seconds → `daily_aggregates` shows `com.apple.Safari` with non-zero `total_in` / `total_out`
- [ ] If user denies permission: app falls back gracefully (degraded mode showing only system-level totals or a friendly "目前看不到網路使用情況，請到系統設定批准 Tally" message); does not crash
- [ ] Helper-process roll-up from TICKET-007 still works with NE-sourced data (Chrome helper bytes credited to Chrome)
- [ ] No regression in popover, Overview, Settings, notifications, onboarding — all Phase 1–4 acceptance criteria still pass with NE as the data source

## Implementation Notes
- **Files / structure**:
  - New target: `TallyFilterExtension/TallyFilterExtension.swift` (the `NEFilterDataProvider` subclass), `TallyFilterExtension/Info.plist`, `TallyFilterExtension/FlowEventWriter.swift`
  - Host changes: `NetworkExtension/SystemExtensionActivator.swift` (uses `OSSystemExtensionRequest`), `Collectors/NEFlowCollector.swift`, updated `Onboarding/Steps/PermissionStep.swift`
  - Shared (both targets): `Shared/FlowEvent.swift`, `Shared/AppGroup.swift`
- **`NEFilterDataProvider` minimal pattern**:
  ```swift
  override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
      record(flow: flow)
      return .allow()  // we never block — this is observation only
  }
  override func handleInboundData(...) / handleOutboundData(...) -> NEFilterDataVerdict {
      recordBytes(...)
      return .allow(...)
  }
  ```
- **Flow attribution**: `NEFilterFlow.sourceAppIdentifier` (bundle id) and `.sourceAppVersion`; this is the value passed through to `flow_samples.bundle_id`. For socket flows without bundle id (mostly kernel/daemon traffic), fall through to `.sourceAppAuditToken` and resolve via `audit_token_to_pid` → `NSRunningApplication`
- **IPC format**: prefer a binary append-only file in the App Group container (`flow-events.log`) over an SQLite shared DB — System Extensions have stricter write permissions and a shared file is simpler. Records are e.g. 32-byte fixed-size: `[timestamp:8][bundleHash:8][bytesIn:8][bytesOut:8]`. Host reads, truncates after consumption
- **Activation flow**:
  1. Host calls `OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: "com.calvinku.Tally.filter", queue: .main)` with `delegate = SystemExtensionActivator()`
  2. Delegate handles `requiresUserApproval`, `didFinishWithResult: .completed`, `didFinishWithError`, `request:replacement existing:withForVersion:`
  3. State surfaced to onboarding via an observable
- **App group**: requires Apple Developer Program enrollment + provisioning profiles; configure manually in the project, do not auto-sign
- **DEBUG flag**: in `AppState.makeCollector()`, check `#if DEBUG && USE_NETTOP` and use `NettopCollector`; otherwise `NEFlowCollector`
- **Denial recovery**: if `OSSystemExtensionRequest` returns rejected / cancelled, surface in onboarding Step 2 with a "再試一次" button that re-issues the request
- **Build & signing**: TICKET-001 set up a basic Xcode project; this ticket requires updating signing settings for the extension target. Document the manual signing flow in a short README addition

## Testing
- Fresh-install on a real Mac (Apple Developer account configured) → onboarding Step 2 → tap "去設定" or directly tap "繼續" → System Settings → Privacy & Security shows the prompt → Allow → state updates in onboarding
- Step 2 advances → Step 3 → complete onboarding → main window
- Browse Safari, Chrome, Slack for 5 minutes → `SELECT bundle_id, SUM(total_in+total_out) FROM daily_aggregates WHERE date = date('now') GROUP BY 1 ORDER BY 2 DESC LIMIT 10;` shows real bundle ids with non-zero bytes
- Compare top apps order with router/ISP data over a 24-hour window — within ≤ 5% (PRD §12)
- Deny permission scenario: install on a second Mac, deny → app shows degraded message, no crashes; user can re-grant via Settings → System Settings link
- DEBUG nettop fallback: `xcodebuild build -scheme Tally CONFIGURATION_BUILD_DIR=… OTHER_SWIFT_FLAGS="-DUSE_NETTOP"` → app runs on nettop; flag off → app runs on NE
- Verify `NettopCollector` files compile but are not referenced in the release `AppState.makeCollector()` path
- Voice audit on the new permission-denied / retry strings against PRD §7
