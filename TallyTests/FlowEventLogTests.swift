import XCTest
@testable import Tally

final class FlowEventLogTests: XCTestCase {
    private var containerURL: URL!

    override func setUpWithError() throws {
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TallyFlowEventLogTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let containerURL {
            try? FileManager.default.removeItem(at: containerURL)
        }
        containerURL = nil
    }

    func testAppendAndDrainRoundTrip() throws {
        let events = [
            FlowEvent(
                timestamp: 1_779_523_200,
                bundleId: "com.apple.Safari",
                executableName: "Safari",
                bytesIn: 42,
                bytesOut: 9
            ),
            FlowEvent(
                timestamp: 1_779_523_201,
                bundleId: nil,
                executableName: "mDNSResponder",
                bytesIn: 3,
                bytesOut: 4
            ),
        ]

        try FlowEventLog.append(events, to: containerURL)

        XCTAssertEqual(try FlowEventLog.drain(from: containerURL), events)
        XCTAssertEqual(try FlowEventLog.drain(from: containerURL), [])
    }

    func testCodecKeepsPartialRecordAsRemainder() throws {
        let complete = FlowEvent(
            timestamp: 1,
            bundleId: "com.example.complete",
            executableName: "Complete",
            bytesIn: 10,
            bytesOut: 20
        )
        let partial = FlowEvent(
            timestamp: 2,
            bundleId: "com.example.partial",
            executableName: "Partial",
            bytesIn: 30,
            bytesOut: 40
        )

        var data = try FlowEventCodec.encode(complete)
        let partialData = try FlowEventCodec.encode(partial)
        data.append(partialData.dropLast(5))

        let firstPass = FlowEventCodec.decode(data)
        XCTAssertEqual(firstPass.events, [complete])
        XCTAssertFalse(firstPass.remainder.isEmpty)

        var recovered = firstPass.remainder
        recovered.append(partialData.suffix(5))
        let secondPass = FlowEventCodec.decode(recovered)
        XCTAssertEqual(secondPass.events, [partial])
        XCTAssertTrue(secondPass.remainder.isEmpty)
    }
}
