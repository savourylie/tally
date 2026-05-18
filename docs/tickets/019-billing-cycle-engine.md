# [TICKET-019] Billing cycle + monthly reset engine

## Status
`blocked`

## Dependencies
- Requires: #017

## Description
Up to this point, every "monthly total" in the UI has been a placeholder computed as the current calendar month. PRD §6.3 and §9 require the cycle to start on `preferences.cycleStartDay` — for someone with a billing cycle starting on the 5th, "this month" runs from the 5th of last month to the 4th of this month. This engine produces:

- `currentCycle: (start: Date, end: Date)` — given `cycleStartDay` + today
- `previousCycle: (start: Date, end: Date)` — same, for the no-limit fallback line (TICKET-014)
- `daysElapsed: Int` and `daysInCycle: Int` — for the estimate calculator (TICKET-014)

Cycle edge cases to handle correctly:
1. Cycle day = 31 in February → cycle starts on Feb 28/29 (last day of month)
2. DST transitions during the cycle → use `Calendar.current.startOfDay(for:)` consistently; cycle boundaries are at local midnight
3. Cycle start day > current day → current cycle started last month
4. Cycle start day == current day → today is day 1 of a fresh cycle

Once this lands, `UsageStore` (TICKET-009) swaps its placeholder calendar-month math for `CycleAwareUsage` based on this engine, and the threshold engine (TICKET-020) can compute percentages correctly.

## Acceptance Criteria
- [ ] `BillingCycle.current(forStartDay:on:)` and `.previous(forStartDay:on:)` produce correct `(start, end)` for these test cases:
  - Start day 1, today is the 15th of June → cycle = June 1 → June 30
  - Start day 5, today is the 3rd of June → cycle = May 5 → June 4 (current month is "May's" cycle)
  - Start day 31, current month is February (28 days) → cycle starts Feb 28 (last day, since 31 doesn't exist)
  - Start day 31, current month is April (30 days) → cycle starts April 30 (or March 31 if today is < 30 — confirm behavior)
- [ ] `daysElapsed(in: cycle, on: today) -> Int` returns ≥ 1 (today counts as day 1, never 0); `daysInCycle(in: cycle) -> Int` returns 28–32 depending on month
- [ ] `CycleAwareUsage` reads `daily_aggregates` filtered by the current cycle window; replaces the placeholder from TICKET-009 in `UsageStore`'s `monthToDateBytes` and `topApps` queries
- [ ] `UsageStore.previousCycleTotalBytes` reads from the previous cycle window — used by TICKET-014's no-limit branch
- [ ] DST: cycle boundaries are at local midnight; springing forward / falling back does not shift cycle by an hour
- [ ] Unit tests cover all four edge cases above plus a DST date
- [ ] Changing `preferences.cycleStartDay` while the app is running triggers an immediate `UsageStore` recompute; UI updates within 500ms

## Implementation Notes
- **Files to create**: `Cycle/BillingCycle.swift` (pure value type), `Cycle/CycleAwareUsage.swift` (DB read layer), `CycleTests/BillingCycleTests.swift`
- **`BillingCycle` shape**:
  ```swift
  struct BillingCycle {
      let start: Date
      let end: Date  // exclusive
      static func current(forStartDay: Int, on reference: Date = Date(), calendar: Calendar = .current) -> BillingCycle
      static func previous(forStartDay: Int, on reference: Date = Date(), calendar: Calendar = .current) -> BillingCycle
      var daysInCycle: Int { ... }
      func daysElapsed(on reference: Date) -> Int { ... }
  }
  ```
- **Algorithm sketch** (current cycle, start day = N):
  1. `let startMonth: Date` = first day of current month at local midnight
  2. `let candidate = clamp(N, to: daysInMonth(startMonth))` → date at day `candidate` of `startMonth`
  3. If `reference < candidate` → cycle started last month: recompute `startMonth` as previous month, clamp again
  4. End = same logic on next month
- **DST**: use `Calendar.current.date(byAdding: .day, value: …, to: …)` rather than naive `TimeInterval` math
- **Clamp helper**: `daysInMonth(for: Date) -> Int` using `calendar.range(of: .day, in: .month, for: …)?.count ?? 30`
- **Update propagation**: `UsageStore` observes `preferences.cycleStartDay` via the `@Observable` macro; on change, re-subscribe the `ValueObservation` with the new cycle window
- **No retroactive correction**: changing the cycle day mid-cycle adopts the new day starting "now"; do not retroactively renumber past cycles. Document this clearly

## Testing
- Set cycle day = 1 → `BillingCycle.current` for June 15 → June 1 to June 30
- Set cycle day = 5 → on June 3 → May 5 to June 4
- Set cycle day = 31 → on Feb 10 → cycle starts Jan 31 (or last day of Jan if no 31st? — verify with test)
- Set cycle day = 31 → on Feb 28 / 29 → confirm next cycle starts on the 28/29 (last day)
- DST transition: simulate March/November dates around the transition → boundaries unchanged
- In running app, set cycle day = 15 in Settings while overall is "the 14th" → main window hero rebases to "May 15 – June 14" range, numbers update accordingly
- `UsageStore.previousCycleTotalBytes` matches a manual SQL query for the previous cycle window
- All unit tests pass: `xcodebuild test -scheme Tally -only-testing:CycleTests`
