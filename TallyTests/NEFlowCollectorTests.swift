import GRDB
import XCTest
@testable import Tally

@MainActor
final class NEFlowCollectorTests: XCTestCase {
    private var rootURL: URL!
    private var containerURL: URL!
    private var dbPool: DatabasePool!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TallyNEFlowCollectorTests-\(UUID().uuidString)", isDirectory: true)
        containerURL = rootURL.appendingPathComponent("AppGroup", isDirectory: true)
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )

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
        containerURL = nil
    }

    func testConsumePendingEventsInsertsFlowSamplesAndFlushes() async throws {
        let didFlush = expectation(description: "did flush")
        let event = FlowEvent(
            timestamp: 1_779_523_200,
            bundleId: "com.apple.Safari",
            executableName: "Safari",
            bytesIn: 1_024,
            bytesOut: 512
        )
        try FlowEventLog.append(event, to: containerURL)

        let collector = NEFlowCollector(
            dbPool: dbPool,
            appGroupURL: containerURL,
            didFlush: {
                didFlush.fulfill()
            }
        )

        let inserted = try await collector.consumePendingEventsOnce()
        XCTAssertEqual(inserted, 1)
        await fulfillment(of: [didFlush], timeout: 1)

        let samples = try await dbPool.read { db in
            try FlowSample.fetchAll(db)
        }
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].timestamp, event.timestamp)
        XCTAssertEqual(samples[0].bundleId, event.bundleId)
        XCTAssertEqual(samples[0].executableName, event.executableName)
        XCTAssertEqual(samples[0].bytesIn, event.bytesIn)
        XCTAssertEqual(samples[0].bytesOut, event.bytesOut)
    }
}
