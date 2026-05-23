import XCTest
@testable import Tally

final class BillingCycleTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ string: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        if let d = df.date(from: string) {
            return d
        }
        let df2 = DateFormatter()
        df2.dateFormat = "yyyy-MM-dd"
        df2.locale = Locale(identifier: "en_US_POSIX")
        df2.calendar = calendar
        df2.timeZone = calendar.timeZone
        return df2.date(from: string)!
    }

    func testStandardCycleBoundaries() {
        // Today is 2026-05-23
        let today = date("2026-05-23")

        // 1. Cycle starting on day 1
        let cycle1 = BillingCycle.current(forStartDay: 1, on: today, calendar: calendar)
        XCTAssertEqual(cycle1.start, date("2026-05-01"))
        XCTAssertEqual(cycle1.end, date("2026-06-01"))
        XCTAssertEqual(cycle1.daysInCycle, 31)

        // 2. Cycle starting on day 5
        let cycle5 = BillingCycle.current(forStartDay: 5, on: today, calendar: calendar)
        XCTAssertEqual(cycle5.start, date("2026-05-05"))
        XCTAssertEqual(cycle5.end, date("2026-06-05"))
        XCTAssertEqual(cycle5.daysInCycle, 31)

        // 3. Cycle starting on day 31
        let cycle31 = BillingCycle.current(forStartDay: 31, on: today, calendar: calendar)
        // Today is May 23. If startDay is 31, candidate in May is May 31, which is > today (May 23). So it started last month on Apr 30 (since Apr has 30 days, 31 clamps to 30)
        XCTAssertEqual(cycle31.start, date("2026-04-30"))
        XCTAssertEqual(cycle31.end, date("2026-05-31"))
        XCTAssertEqual(cycle31.daysInCycle, 31) // Apr 30 to May 31 is 31 days
    }

    func testFebruaryBoundaryClampingLeapYear() {
        // Leap year: 2024 has 29 days in Feb.
        let febDate = date("2024-02-15")

        // Cycle start 31 should clamp to 29 in Feb 2024
        let cycle31 = BillingCycle.current(forStartDay: 31, on: febDate, calendar: calendar)
        // Since Feb 15 < Feb 29, the cycle must have started in the previous month (Jan 31)
        XCTAssertEqual(cycle31.start, date("2024-01-31"))
        XCTAssertEqual(cycle31.end, date("2024-02-29")) // Clamped to 29th

        // Now if reference is Feb 29 (leap day)
        let leapDay = date("2024-02-29")
        let cycleLeap = BillingCycle.current(forStartDay: 31, on: leapDay, calendar: calendar)
        XCTAssertEqual(cycleLeap.start, date("2024-02-29"))
        XCTAssertEqual(cycleLeap.end, date("2024-03-31"))
    }

    func testFebruaryBoundaryClampingNonLeapYear() {
        // Non-leap year: 2026 has 28 days in Feb.
        let febDate = date("2026-02-15")

        // Cycle start 31 should clamp to 28 in Feb 2026
        let cycle31 = BillingCycle.current(forStartDay: 31, on: febDate, calendar: calendar)
        // Since Feb 15 < Feb 28, cycle started in Jan 31
        XCTAssertEqual(cycle31.start, date("2026-01-31"))
        XCTAssertEqual(cycle31.end, date("2026-02-28")) // Clamped to 28th

        // Reference is Feb 28
        let febEnd = date("2026-02-28")
        let cycleEnd = BillingCycle.current(forStartDay: 31, on: febEnd, calendar: calendar)
        XCTAssertEqual(cycleEnd.start, date("2026-02-28"))
        XCTAssertEqual(cycleEnd.end, date("2026-03-31"))
    }

    func testPreviousCycleCalculation() {
        let today = date("2026-05-23")

        let prevCycle1 = BillingCycle.previous(forStartDay: 1, on: today, calendar: calendar)
        XCTAssertEqual(prevCycle1.start, date("2026-04-01"))
        XCTAssertEqual(prevCycle1.end, date("2026-05-01"))

        let prevCycle31 = BillingCycle.previous(forStartDay: 31, on: today, calendar: calendar)
        // Current cycle started Apr 30, ended May 31.
        // Previous cycle started Mar 31, ended Apr 30.
        XCTAssertEqual(prevCycle31.start, date("2026-03-31"))
        XCTAssertEqual(prevCycle31.end, date("2026-04-30"))
    }

    func testDaysElapsedCalculation() {
        let start = date("2026-05-01")
        let end = date("2026-06-01")
        let cycle = BillingCycle(start: start, end: end)

        // Day 1 (same day as start)
        XCTAssertEqual(cycle.daysElapsed(on: date("2026-05-01"), calendar: calendar), 1)

        // Day 15
        XCTAssertEqual(cycle.daysElapsed(on: date("2026-05-15"), calendar: calendar), 15)

        // Day 31 (last day of cycle)
        XCTAssertEqual(cycle.daysElapsed(on: date("2026-05-31"), calendar: calendar), 31)

        // Reference date before start (defensive case: should return at least 1)
        XCTAssertEqual(cycle.daysElapsed(on: date("2026-04-20"), calendar: calendar), 1)
    }
}
