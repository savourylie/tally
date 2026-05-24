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
}
