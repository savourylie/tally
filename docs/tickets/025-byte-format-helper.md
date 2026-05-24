# [TICKET-025] Shared byte-formatting helper (ByteFormat)

## Status
`done`

## Dependencies
- Requires: None

## Description
Every new data-visualization view needs to turn an `Int64` byte count into a display string ("12.3 GB", "234.5 MB") or a chart axis value (GB as `Double`). Today this logic is duplicated inline across at least five views — `AppRow.swift`, `HeroCard.swift`, `EstimateSentence.swift`, `HeroNumber.swift`, `TopAppRow.swift` — each hardcoding the `1_073_741_824` / `1_048_576` divisors with subtly different precision rules. Before adding more views we consolidate this into one source of truth.

This is the foundation ticket for Phase 6: TodayCard, the trend chart, the summary tiles, and the sparkline all call into it. Keeping it first avoids re-deriving the GB/MB thresholds in each subsequent ticket and guarantees the new views match the existing ones exactly.

## Acceptance Criteria
- [x] New `enum ByteFormat` exposes `gigabytes(_ bytes: Int64, decimals: Int = 1) -> String` producing `"%.1f GB"` (matches `HeroCard`/`HeroNumber`)
- [x] `adaptive(_ bytes: Int64) -> String` returns `"%.2f GB"` when ≥ 0.01 GB else `"%.1f MB"` — byte-for-byte identical to the current `AppRow.swift` / `TopAppRow.swift` behaviour
- [x] `gigabytesValue(_ bytes: Int64) -> Double` returns `Double(bytes) / bytesPerGigabyte` for use as a Swift Charts Y value
- [x] The GB divisor reuses the existing `EstimateCalculator.bytesPerGigabyte` constant rather than a new literal
- [x] `ByteFormatTests` assert the 0.01 GB GB↔MB switchover, the 1- vs 2-decimal rules, and a zero-byte case

## Implementation Notes
- **Files to create**: `Tally/Sources/DesignTokens/ByteFormat.swift` (peer of `Color+Tally.swift`), `TallyTests/ByteFormatTests.swift`
- Pure value logic — no SwiftUI imports, no `@MainActor`; this keeps it trivially unit-testable
- **Out of scope** (optional later cleanup): migrating the five existing inline call sites to `ByteFormat`. Do not change those files in this ticket — keep the diff to the new helper + its test so it can't regress existing screens
- Match the exact `String(format:)` patterns currently in `AppRow.swift:22-31` so a future migration is a no-op visually

## Testing
- `xcodebuild test -project Tally.xcodeproj -scheme Tally -only-testing:TallyTests/ByteFormatTests`
- Verify: `adaptive(10_700_000)` → `"0.01 GB"` boundary behaves; `adaptive(5_000_000)` → MB; `gigabytes(13_300_000_000)` → `"12.4 GB"`
