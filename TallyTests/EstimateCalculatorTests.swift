import XCTest

final class EstimateCalculatorTests: XCTestCase {
    private let gibibyte = Int64(1_073_741_824)

    func testProjectedTotalProjectsLinearly() {
        let projected = EstimateCalculator.projectedTotalBytes(
            mtdBytes: 12 * gibibyte,
            daysElapsed: 15,
            daysInCycle: 30
        )

        XCTAssertEqual(projected, 24 * gibibyte)
    }

    func testProjectedTotalReturnsMTDWhenDaysElapsedIsZero() {
        let projected = EstimateCalculator.projectedTotalBytes(
            mtdBytes: 12 * gibibyte,
            daysElapsed: 0,
            daysInCycle: 30
        )

        XCTAssertEqual(projected, 12 * gibibyte)
    }

    func testProjectedTotalReturnsMTDWhenCycleLengthIsInvalid() {
        let projected = EstimateCalculator.projectedTotalBytes(
            mtdBytes: 12 * gibibyte,
            daysElapsed: 15,
            daysInCycle: 0
        )

        XCTAssertEqual(projected, 12 * gibibyte)
    }
}
