import GRDB
import XCTest
@testable import Tally

/// Tests for `UsageStore.fetchTodaySnapshot` — the `nonisolated` query that backs
/// the live "today" total and freshness timestamp (TICKET-026). Exercised directly
/// against a temp on-disk database so no `@MainActor` store is constructed.
final class UsageStoreQueryTests: XCTestCase {
    private var rootURL: URL!
    private var dbPool: DatabasePool!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TallyUsageStoreQueryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let dbURL = rootURL.appendingPathComponent("tally.sqlite")
        dbPool = try DatabasePool(path: dbURL.path)
        try Migrations.makeMigrator().migrate(dbPool)
    }

    override func tearDownWithError() throws {
        dbPool = nil
        if let rootURL {
            try? FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
    }

    // MARK: - Helpers

    /// Insert a single `flow_samples` row at the given Unix timestamp.
    private func insertSample(timestamp: Int64, bytesIn: Int64, bytesOut: Int64) async throws {
        try await dbPool.write { db in
            var sample = FlowSample(
                id: nil,
                timestamp: timestamp,
                bundleId: "com.apple.Safari",
                executableName: "Safari",
                bytesIn: bytesIn,
                bytesOut: bytesOut,
                networkId: nil
            )
            try sample.insert(db)
        }
    }

    private func snapshot(startOfToday: Int64) async throws -> TodaySnapshot {
        try await dbPool.read { db in
            try UsageStore.fetchTodaySnapshot(db, startOfToday: startOfToday)
        }
    }

    /// Insert a single `daily_aggregates` row. `bundleId` varies so two rows can
    /// share a `date` without violating the `(date,bundle_id,category,network_id)`
    /// unique key. Mirrors `ThresholdEngineTests.setMTDUsage`'s raw-SQL insert.
    private func insertAggregate(date: String, bundleId: String?, bytesIn: Int64, bytesOut: Int64) async throws {
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_aggregates (date, bundle_id, category, total_in, total_out)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [date, bundleId, nil, bytesIn, bytesOut]
            )
        }
    }

    /// Parse a `yyyy-MM-dd` string to a local-midnight `Date`, using the same
    /// formatter config the store uses, so keys line up in `buildTrend`.
    private let dateFormatter = UsageStore.makeDateFormatter()
    private func date(_ string: String) -> Date {
        guard let d = dateFormatter.date(from: string) else {
            preconditionFailure("bad test date: \(string)")
        }
        return d
    }

    // MARK: - Tests

    /// Today's sum excludes a row from yesterday, and `MAX(timestamp)` is the
    /// freshest of today's rows.
    func testTodaySumExcludesYesterdayAndReturnsFreshestTimestamp() async throws {
        let startOfToday: Int64 = 1_779_523_200 // arbitrary fixed local-midnight bound

        // Yesterday — must be excluded.
        try await insertSample(timestamp: startOfToday - 100, bytesIn: 9_000, bytesOut: 8_000)
        // Today — two rows; the later one is the freshest.
        try await insertSample(timestamp: startOfToday + 100, bytesIn: 1_024, bytesOut: 512)
        try await insertSample(timestamp: startOfToday + 200, bytesIn: 2_048, bytesOut: 256)

        let snap = try await snapshot(startOfToday: startOfToday)

        XCTAssertEqual(snap.bytesIn, 1_024 + 2_048)
        XCTAssertEqual(snap.bytesOut, 512 + 256)
        XCTAssertEqual(snap.lastSampleTimestamp, startOfToday + 200)
    }

    /// A boundary row exactly at `startOfToday` is included (`timestamp >= bound`).
    func testRowAtMidnightBoundaryIsIncluded() async throws {
        let startOfToday: Int64 = 1_779_523_200

        try await insertSample(timestamp: startOfToday, bytesIn: 500, bytesOut: 250)

        let snap = try await snapshot(startOfToday: startOfToday)

        XCTAssertEqual(snap.bytesIn, 500)
        XCTAssertEqual(snap.bytesOut, 250)
        XCTAssertEqual(snap.lastSampleTimestamp, startOfToday)
    }

    /// Empty table (fresh install): zero bytes and a `nil` — not `0` — timestamp.
    func testEmptyTableYieldsZeroBytesAndNilTimestamp() async throws {
        let startOfToday: Int64 = 1_779_523_200

        let snap = try await snapshot(startOfToday: startOfToday)

        XCTAssertEqual(snap.bytesIn, 0)
        XCTAssertEqual(snap.bytesOut, 0)
        XCTAssertNil(snap.lastSampleTimestamp)
    }

    /// Rows exist but all predate today: the `WHERE timestamp >= ?` filter governs
    /// the freshness signal too, so it stays `nil`.
    func testRowsExistButNoneTodayYieldsNilTimestamp() async throws {
        let startOfToday: Int64 = 1_779_523_200

        try await insertSample(timestamp: startOfToday - 3_600, bytesIn: 7_000, bytesOut: 3_000)
        try await insertSample(timestamp: startOfToday - 1, bytesIn: 1_000, bytesOut: 500)

        let snap = try await snapshot(startOfToday: startOfToday)

        XCTAssertEqual(snap.bytesIn, 0)
        XCTAssertEqual(snap.bytesOut, 0)
        XCTAssertNil(snap.lastSampleTimestamp)
    }

    // MARK: - Daily trend (TICKET-027)

    /// `fetchDailyTrend` groups by date and sums across rows of the same day,
    /// returns days ascending, and emits only days that have rows (a gap day is
    /// absent here — zero-fill is `buildTrend`'s job).
    func testFetchDailyTrendGroupsAndSumsPerDate() async throws {
        try await insertAggregate(date: "2026-05-20", bundleId: "com.a", bytesIn: 100, bytesOut: 50)
        try await insertAggregate(date: "2026-05-20", bundleId: "com.b", bytesIn: 200, bytesOut: 25)
        try await insertAggregate(date: "2026-05-22", bundleId: "com.a", bytesIn: 10, bytesOut: 10)

        let rows = try await dbPool.read { db in
            try UsageStore.fetchDailyTrend(db, start: "2026-05-20", end: "2026-05-22")
        }

        XCTAssertEqual(rows, [
            DailyTrendRow(date: "2026-05-20", bytesIn: 300, bytesOut: 75),
            DailyTrendRow(date: "2026-05-22", bytesIn: 10, bytesOut: 10),
        ])
    }

    /// `buildTrend` zero-fills gap days and **substitutes** today's entry with the
    /// live `todayBytes`, overriding any (lagging) aggregate row for today.
    func testBuildTrendZeroFillsGapsAndSubstitutesTodayWithLiveBytes() {
        let rows = [
            DailyTrendRow(date: "2026-05-20", bytesIn: 300, bytesOut: 75),
            DailyTrendRow(date: "2026-05-22", bytesIn: 10, bytesOut: 10),
            DailyTrendRow(date: "2026-05-24", bytesIn: 7, bytesOut: 7), // stale aggregate for today
        ]

        let trend = UsageStore.buildTrend(
            rows: rows,
            start: date("2026-05-20"),
            end: date("2026-05-24"),
            todayBytes: UsageStore.BytePair(bytesIn: 999, bytesOut: 1),
            now: date("2026-05-24")
        )

        // Continuous bars across the full inclusive range.
        XCTAssertEqual(trend.map(\.date), [
            date("2026-05-20"), date("2026-05-21"), date("2026-05-22"),
            date("2026-05-23"), date("2026-05-24"),
        ])
        XCTAssertEqual(trend[0].bytesIn, 300)            // real data
        XCTAssertEqual(trend[0].bytesOut, 75)
        XCTAssertEqual(trend[1].total, 0)               // gap zero-filled
        XCTAssertEqual(trend[2].total, 20)              // real data
        XCTAssertEqual(trend[3].total, 0)               // gap zero-filled
        XCTAssertEqual(trend[4].bytesIn, 999)           // today = live bytes, NOT the (7,7) row
        XCTAssertEqual(trend[4].bytesOut, 1)
    }

    /// Week bounds cover the 7 days `today-6d … today`, inclusive.
    func testWeekWindowBoundsCoverLastSevenDays() {
        let bounds = UsageStore.weekWindowBounds(now: date("2026-05-24"))
        XCTAssertEqual(bounds.start, "2026-05-18")
        XCTAssertEqual(bounds.end, "2026-05-24")
    }

    /// Switching `trendWindow` changes the returned date range.
    func testTrendBoundsDifferByWindow() {
        let now = date("2026-05-24")

        // currentCycle (start day 1) → the whole of May; cycle.end is exclusive
        // (Jun 1) so the last included day is May 31.
        let cycle = UsageStore.trendBounds(window: .currentCycle, cycleStartDay: 1, now: now)
        XCTAssertEqual(cycle.start, date("2026-05-01"))
        XCTAssertEqual(cycle.end, date("2026-05-31"))

        // last30Days → today-29d … today.
        let last30 = UsageStore.trendBounds(window: .last30Days, cycleStartDay: 1, now: now)
        XCTAssertEqual(last30.start, date("2026-04-25"))
        XCTAssertEqual(last30.end, now)

        XCTAssertNotEqual(cycle.start, last30.start)
    }

    /// `fetchRangeTotal` (which backs `weekBytes`) sums only rows inside the
    /// window, excluding the day before and the day after.
    func testFetchRangeTotalSumsOnlyWithinWindow() async throws {
        try await insertAggregate(date: "2026-05-17", bundleId: "com.a", bytesIn: 1_000, bytesOut: 1_000) // before
        try await insertAggregate(date: "2026-05-18", bundleId: "com.a", bytesIn: 100, bytesOut: 50)      // first in window
        try await insertAggregate(date: "2026-05-24", bundleId: "com.a", bytesIn: 7, bytesOut: 3)         // last in window
        try await insertAggregate(date: "2026-05-25", bundleId: "com.a", bytesIn: 5_000, bytesOut: 5_000) // after

        let bounds = UsageStore.weekWindowBounds(now: date("2026-05-24"))
        let week = try await dbPool.read { db in
            try UsageStore.fetchRangeTotal(db, start: bounds.start, end: bounds.end)
        }

        XCTAssertEqual(week.bytesIn, 100 + 7)
        XCTAssertEqual(week.bytesOut, 50 + 3)
    }
}
