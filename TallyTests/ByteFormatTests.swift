import XCTest
@testable import Tally

/// Tests for `ByteFormat` (TICKET-025) — the shared byte → display-string /
/// chart-value helper. Pure value logic, so no database or `@MainActor` setup.
final class ByteFormatTests: XCTestCase {

    // MARK: - adaptive: GB ↔ MB switchover

    /// The true boundary is 0.01 GB = 0.01 × 1_073_741_824 = 10_737_418.24 bytes.
    /// `adaptive` uses `gb >= 0.01` on the raw GB value (identical to `AppRow`),
    /// so these two integers straddle the switchover.
    func testAdaptiveSwitchesAtPointZeroOneGigabyteBoundary() {
        XCTAssertEqual(ByteFormat.adaptive(10_737_418), "10.2 MB") // just below 0.01 GB
        XCTAssertEqual(ByteFormat.adaptive(10_737_419), "0.01 GB") // just at/above 0.01 GB
    }

    func testAdaptiveBelowBoundaryFormatsAsMegabytes() {
        XCTAssertEqual(ByteFormat.adaptive(5_000_000), "4.8 MB")
        XCTAssertEqual(ByteFormat.adaptive(10_000_000), "9.5 MB")
    }

    func testAdaptiveAboveBoundaryFormatsAsGigabytes() {
        XCTAssertEqual(ByteFormat.adaptive(13_300_000_000), "12.39 GB") // %.2f in adaptive
    }

    // MARK: - gigabytes: decimal rules

    func testGigabytesDefaultsToOneDecimal() {
        XCTAssertEqual(ByteFormat.gigabytes(13_300_000_000), "12.4 GB")
    }

    func testGigabytesHonoursDecimalsArgument() {
        XCTAssertEqual(ByteFormat.gigabytes(13_300_000_000, decimals: 2), "12.39 GB")
    }

    // MARK: - Zero

    func testZeroBytes() {
        XCTAssertEqual(ByteFormat.adaptive(0), "0.0 MB")
        XCTAssertEqual(ByteFormat.gigabytes(0), "0.0 GB")
    }

    // MARK: - gigabytesValue (chart axis)

    func testGigabytesValueReturnsRawGigabytes() {
        XCTAssertEqual(ByteFormat.gigabytesValue(1_073_741_824), 1.0, accuracy: 0.0001)
        XCTAssertEqual(ByteFormat.gigabytesValue(0), 0.0, accuracy: 0.0001)
    }
}
