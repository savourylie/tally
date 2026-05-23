import XCTest
@testable import Tally

final class FiredThresholdsLedgerTests: XCTestCase {
    private var store: UserDefaults!
    private var ledger: FiredThresholdsLedger!

    override func setUp() {
        super.setUp()
        store = UserDefaults(suiteName: "com.calvinku.Tally.tests.ledger.\(UUID().uuidString)")!
        ledger = FiredThresholdsLedger(store: store)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(
            forName: store.volatileDomainNames.first ?? ""
        )
        store = nil
        ledger = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func date(_ string: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = .current
        return df.date(from: string)!
    }

    // MARK: - Tests

    func testInitialStateNotFired() {
        let cycleStart = date("2026-05-01")
        XCTAssertFalse(ledger.hasFired(threshold: 80, cycleStart: cycleStart))
        XCTAssertFalse(ledger.hasFired(threshold: 95, cycleStart: cycleStart))
        XCTAssertFalse(ledger.hasFired(threshold: 100, cycleStart: cycleStart))
    }

    func testMarkFiredPersists() {
        let cycleStart = date("2026-05-01")
        ledger.markFired(threshold: 80, cycleStart: cycleStart)

        XCTAssertTrue(ledger.hasFired(threshold: 80, cycleStart: cycleStart))
        XCTAssertFalse(ledger.hasFired(threshold: 95, cycleStart: cycleStart))
        XCTAssertFalse(ledger.hasFired(threshold: 100, cycleStart: cycleStart))
    }

    func testDifferentCyclesAreIndependent() {
        let cycle1 = date("2026-05-01")
        let cycle2 = date("2026-06-01")

        ledger.markFired(threshold: 80, cycleStart: cycle1)

        XCTAssertTrue(ledger.hasFired(threshold: 80, cycleStart: cycle1))
        XCTAssertFalse(ledger.hasFired(threshold: 80, cycleStart: cycle2),
                       "A different cycle should not see the first cycle's fired state")
    }

    func testAllThresholdsCanFireIndependently() {
        let cycleStart = date("2026-05-01")

        ledger.markFired(threshold: 80, cycleStart: cycleStart)
        ledger.markFired(threshold: 95, cycleStart: cycleStart)
        ledger.markFired(threshold: 100, cycleStart: cycleStart)

        XCTAssertTrue(ledger.hasFired(threshold: 80, cycleStart: cycleStart))
        XCTAssertTrue(ledger.hasFired(threshold: 95, cycleStart: cycleStart))
        XCTAssertTrue(ledger.hasFired(threshold: 100, cycleStart: cycleStart))
    }

    func testCleanupRemovesOldEntries() {
        let oldCycle = date("2026-01-01")  // 4+ months ago
        let currentCycle = date("2026-05-01")

        ledger.markFired(threshold: 80, cycleStart: oldCycle)
        XCTAssertTrue(ledger.hasFired(threshold: 80, cycleStart: oldCycle))

        // Clean up with current cycle
        ledger.cleanupStaleEntries(currentCycleStart: currentCycle, keepCycles: 2)

        // Old entry should be removed
        XCTAssertFalse(ledger.hasFired(threshold: 80, cycleStart: oldCycle),
                       "Entries older than keepCycles should be removed")
    }

    func testCleanupPreservesRecentEntries() {
        let recentCycle = date("2026-04-01")
        let currentCycle = date("2026-05-01")

        ledger.markFired(threshold: 80, cycleStart: recentCycle)

        // Clean up — recent cycle is within 2 months
        ledger.cleanupStaleEntries(currentCycleStart: currentCycle, keepCycles: 2)

        // Recent entry should still be present
        XCTAssertTrue(ledger.hasFired(threshold: 80, cycleStart: recentCycle),
                      "Recent entries within keepCycles should be preserved")
    }

    func testCleanupPreservesCurrentCycle() {
        let currentCycle = date("2026-05-01")

        ledger.markFired(threshold: 95, cycleStart: currentCycle)
        ledger.cleanupStaleEntries(currentCycleStart: currentCycle)

        XCTAssertTrue(ledger.hasFired(threshold: 95, cycleStart: currentCycle),
                      "Current cycle entries must never be cleaned up")
    }

    func testLedgerReadsFromSameStore() {
        let cycleStart = date("2026-05-01")
        ledger.markFired(threshold: 80, cycleStart: cycleStart)

        // Create a new ledger instance backed by the same store
        let ledger2 = FiredThresholdsLedger(store: store)
        XCTAssertTrue(ledger2.hasFired(threshold: 80, cycleStart: cycleStart),
                      "A new ledger instance should see previously persisted state")
    }
}
