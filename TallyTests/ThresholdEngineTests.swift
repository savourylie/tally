import XCTest
import GRDB
@testable import Tally

@MainActor
final class MockNotificationCoordinator: NotificationCoordinator {
    var firedThresholds: [Int] = []
    var onFire: ((Int) -> Void)?

    override var isAuthorized: Bool {
        return true
    }

    override func requestAuthorization() async {
        // No-op for mock
    }

    override func fireThresholdNotification(percent: Int) {
        firedThresholds.append(percent)
        onFire?(percent)
    }
}

@MainActor
final class ThresholdEngineTests: XCTestCase {
    private var suiteName: String!
    private var tempDbURL: URL!
    private var dbPool: DatabasePool!
    private var preferences: Preferences!
    private var metadataService: AppMetadataService!
    private var categorizer: ProcessCategorizer!
    private var usageStore: UsageStore!
    private var coordinator: MockNotificationCoordinator!
    private var ledger: FiredThresholdsLedger!
    private var engine: ThresholdEngine!

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    override func setUp() async throws {
        try await super.setUp()

        // 1. Setup isolated Preferences with a unique suite name per test to prevent test pollution
        suiteName = "com.calvinku.Tally.threshold.tests.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        let testDefaults = UserDefaults(suiteName: suiteName)!
        preferences = Preferences(store: testDefaults)

        // 2. Setup isolated temp database
        tempDbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-tally-\(UUID().uuidString).sqlite")
        dbPool = try DatabasePool(path: tempDbURL.path)
        try Migrations.makeMigrator().migrate(dbPool)

        // 3. Setup metadata and categorizer services
        metadataService = AppMetadataService(dbPool: dbPool)
        categorizer = ProcessCategorizer(dbPool: dbPool)
        await categorizer.load()

        // 4. Setup UsageStore
        usageStore = UsageStore(
            dbPool: dbPool,
            metadataService: metadataService,
            categorizer: categorizer,
            preferences: preferences
        )

        // 5. Setup Notification Coordinator & Ledger
        coordinator = MockNotificationCoordinator()
        ledger = FiredThresholdsLedger(store: testDefaults)

        // 6. Setup ThresholdEngine
        engine = ThresholdEngine(
            usageStore: usageStore,
            preferences: preferences,
            coordinator: coordinator,
            ledger: ledger
        )

        // Start engines
        usageStore.start()
        engine.start()
    }

    override func tearDown() async throws {
        engine = nil
        usageStore = nil
        categorizer = nil
        metadataService = nil
        coordinator = nil
        ledger = nil
        dbPool = nil
        
        // Wait a brief moment to let GRDB close database connections cleanly before file deletion
        try? await Task.sleep(for: .milliseconds(100))
        
        try? FileManager.default.removeItem(at: tempDbURL)
        UserDefaults.standard.removePersistentDomain(forName: suiteName)

        try await super.tearDown()
    }

    // MARK: - Helpers

    private func setMTDUsage(bytesIn: Int64, bytesOut: Int64) throws {
        let todayStr = dateFormatter.string(from: Date.now)
        try dbPool.write { db in
            // Clear old aggregates
            try db.execute(sql: "DELETE FROM daily_aggregates")
            
            // Insert new aggregate
            try db.execute(
                sql: """
                    INSERT INTO daily_aggregates (date, bundle_id, category, total_in, total_out)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [todayStr, "com.apple.Safari", nil, bytesIn, bytesOut]
            )
        }
    }

    // MARK: - Tests

    func test80PercentFires() async throws {
        // Cap = 10 GB (10,737,418,240 bytes)
        preferences.monthlyLimitGB = 10.0
        
        let exp = expectation(description: "80% notification fired")
        coordinator.onFire = { percent in
            if percent == 80 {
                exp.fulfill()
            }
        }

        // Set MTD to 8.5 GB (9,126,805,504 bytes), which is ~85% (>80%)
        let mtdBytes = Int64(8.5 * 1_073_741_824)
        try setMTDUsage(bytesIn: mtdBytes, bytesOut: 0)

        await fulfillment(of: [exp], timeout: 2.0)

        XCTAssertEqual(coordinator.firedThresholds, [80])
    }

    func testNotificationDeduplication() async throws {
        preferences.monthlyLimitGB = 10.0

        let exp = expectation(description: "80% notification fired once")
        coordinator.onFire = { percent in
            if percent == 80 {
                exp.fulfill()
            }
        }

        let mtdBytes = Int64(8.5 * 1_073_741_824)
        try setMTDUsage(bytesIn: mtdBytes, bytesOut: 0)

        await fulfillment(of: [exp], timeout: 2.0)

        // Try setting usage again to trigger evaluate() again
        try setMTDUsage(bytesIn: mtdBytes + 1000, bytesOut: 0)

        // Sleep briefly to ensure no duplicate notifications are posted
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(coordinator.firedThresholds, [80])
    }

    func testSequenceCrossingFiresAllInAscendingOrder() async throws {
        preferences.monthlyLimitGB = 10.0

        var received: [Int] = []
        let exp = expectation(description: "All notifications fired")
        exp.expectedFulfillmentCount = 3
        coordinator.onFire = { percent in
            received.append(percent)
            exp.fulfill()
        }

        // Set MTD to 10.5 GB (~105%), crossing 80, 95, 100 all at once
        let mtdBytes = Int64(10.5 * 1_073_741_824)
        try setMTDUsage(bytesIn: mtdBytes, bytesOut: 0)

        await fulfillment(of: [exp], timeout: 2.0)

        // Order must be ascending: 80, 95, 100
        XCTAssertEqual(received, [80, 95, 100])
    }

    func testDisabledThresholdIsSkipped() async throws {
        preferences.monthlyLimitGB = 10.0
        
        // Disable 95% threshold
        preferences.alertAt95 = false

        var received: [Int] = []
        let exp = expectation(description: "80 and 100 notifications fired")
        exp.expectedFulfillmentCount = 2
        coordinator.onFire = { percent in
            received.append(percent)
            exp.fulfill()
        }

        // Set MTD to 10.5 GB, crossing all three
        let mtdBytes = Int64(10.5 * 1_073_741_824)
        try setMTDUsage(bytesIn: mtdBytes, bytesOut: 0)

        await fulfillment(of: [exp], timeout: 2.0)

        // 95 should be missing
        XCTAssertEqual(received, [80, 100])
    }

    func testCycleRolloverResetsLedger() async throws {
        preferences.monthlyLimitGB = 10.0

        let exp1 = expectation(description: "First 80% fired")
        coordinator.onFire = { percent in
            if percent == 80 { exp1.fulfill() }
        }

        let mtdBytes = Int64(8.5 * 1_073_741_824)
        try setMTDUsage(bytesIn: mtdBytes, bytesOut: 0)
        await fulfillment(of: [exp1], timeout: 2.0)

        XCTAssertEqual(coordinator.firedThresholds, [80])

        // Now simulate cycle rollover by changing the cycleStartDay.
        // Changing cycleStartDay to a different day (e.g. today's day + 5) will establish a new cycle,
        // which has a different start date, resetting the deduplication key!
        coordinator.firedThresholds.removeAll()
        coordinator.onFire = nil

        let exp2 = expectation(description: "Second 80% fired after cycle start day changed")
        coordinator.onFire = { percent in
            if percent == 80 { exp2.fulfill() }
        }

        // Change start day explicitly to 5 (or 1 if it's already 5), ensuring the cycle shifts
        let currentStartDay = preferences.cycleStartDay
        let newStartDay = currentStartDay == 1 ? 5 : 1
        preferences.cycleStartDay = newStartDay

        // Wait for observation restart to propagate cleanly using structured async wait
        try? await Task.sleep(for: .milliseconds(300))
        
        try setMTDUsage(bytesIn: mtdBytes + 2000, bytesOut: 0)

        await fulfillment(of: [exp2], timeout: 3.0)
        XCTAssertEqual(coordinator.firedThresholds, [80])
    }
}
