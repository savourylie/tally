import Foundation

/// A billing cycle defined by a start date (inclusive) and an end date (exclusive).
///
/// The cycle boundaries are computed from the user's preferred `cycleStartDay`
/// (1–31). When a month has fewer days than `cycleStartDay`, the cycle starts
/// on the last day of that month (e.g., start day 31 in February → Feb 28/29).
///
/// All boundary dates are at local midnight via `Calendar.current.startOfDay(for:)`,
/// so DST transitions never shift a cycle boundary by an hour.
struct BillingCycle: Sendable, Equatable {
    /// First day of the cycle (inclusive), at local midnight.
    let start: Date
    /// First day of the *next* cycle (exclusive), at local midnight.
    let end: Date

    /// Number of days in this cycle.
    var daysInCycle: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return components.day ?? 30
    }

    /// How many days have elapsed in this cycle as of `reference`.
    /// Returns ≥ 1 (today counts as day 1, never 0).
    func daysElapsed(on reference: Date = .now, calendar: Calendar = .current) -> Int {
        let ref = calendar.startOfDay(for: reference)
        let components = calendar.dateComponents([.day], from: start, to: ref)
        let elapsed = (components.day ?? 0) + 1 // today is day 1
        return max(elapsed, 1)
    }

    // MARK: - Factory Methods

    /// Returns the billing cycle that contains `reference`.
    ///
    /// - Parameters:
    ///   - startDay: The user's preferred cycle start day (1–31).
    ///   - reference: The reference date (defaults to now).
    ///   - calendar: Calendar to use for date math (defaults to `.current`).
    static func current(
        forStartDay startDay: Int,
        on reference: Date = .now,
        calendar: Calendar = .current
    ) -> BillingCycle {
        let ref = calendar.startOfDay(for: reference)
        let cycleStart = computeCycleStart(forStartDay: startDay, containing: ref, calendar: calendar)
        let cycleEnd = computeNextCycleStart(after: cycleStart, startDay: startDay, calendar: calendar)
        return BillingCycle(start: cycleStart, end: cycleEnd)
    }

    /// Returns the billing cycle immediately before the one containing `reference`.
    static func previous(
        forStartDay startDay: Int,
        on reference: Date = .now,
        calendar: Calendar = .current
    ) -> BillingCycle {
        let currentCycle = Self.current(forStartDay: startDay, on: reference, calendar: calendar)
        // The previous cycle ends where the current one starts.
        // Walk back one day from current start to find a date inside the previous cycle.
        let dayBeforeCurrent = calendar.date(byAdding: .day, value: -1, to: currentCycle.start) ?? currentCycle.start
        return Self.current(forStartDay: startDay, on: dayBeforeCurrent, calendar: calendar)
    }

    // MARK: - Internal Helpers

    /// Given a reference date and a start day, compute the start of the cycle
    /// that contains the reference date.
    private static func computeCycleStart(
        forStartDay startDay: Int,
        containing reference: Date,
        calendar: Calendar
    ) -> Date {
        let ref = calendar.startOfDay(for: reference)
        let refComponents = calendar.dateComponents([.year, .month, .day], from: ref)

        // Try building the cycle start in the same month as reference
        let clampedDay = clampDay(startDay, inYear: refComponents.year!, month: refComponents.month!, calendar: calendar)

        var candidateComponents = DateComponents()
        candidateComponents.year = refComponents.year
        candidateComponents.month = refComponents.month
        candidateComponents.day = clampedDay

        let candidate = calendar.startOfDay(for: calendar.date(from: candidateComponents)!)

        if candidate <= ref {
            // Cycle started this month (on or before today)
            return candidate
        } else {
            // Cycle hasn't started yet this month → it started last month
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: candidate)!
            let prevComponents = calendar.dateComponents([.year, .month], from: previousMonth)
            let prevClamped = clampDay(startDay, inYear: prevComponents.year!, month: prevComponents.month!, calendar: calendar)

            var prevCandidateComponents = DateComponents()
            prevCandidateComponents.year = prevComponents.year
            prevCandidateComponents.month = prevComponents.month
            prevCandidateComponents.day = prevClamped

            return calendar.startOfDay(for: calendar.date(from: prevCandidateComponents)!)
        }
    }

    /// Compute the start of the next cycle after `cycleStart`.
    private static func computeNextCycleStart(
        after cycleStart: Date,
        startDay: Int,
        calendar: Calendar
    ) -> Date {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: cycleStart)!
        let nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        let clampedDay = clampDay(startDay, inYear: nextComponents.year!, month: nextComponents.month!, calendar: calendar)

        var nextCandidateComponents = DateComponents()
        nextCandidateComponents.year = nextComponents.year
        nextCandidateComponents.month = nextComponents.month
        nextCandidateComponents.day = clampedDay

        return calendar.startOfDay(for: calendar.date(from: nextCandidateComponents)!)
    }

    /// Clamp `day` to the number of days in the given month.
    /// For example, day 31 in February → 28 or 29.
    private static func clampDay(_ day: Int, inYear year: Int, month: Int, calendar: Calendar) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count else {
            return min(max(day, 1), 28) // fallback
        }
        return min(max(day, 1), daysInMonth)
    }
}
