import XCTest
@testable import Tally

final class SystemExtensionActivatorTests: XCTestCase {
    func testActivationPreflightAllowsApplicationsBundle() {
        let appURL = URL(fileURLWithPath: "/Applications/Tally.app")

        XCTAssertNil(SystemExtensionActivator.activationPreflightState(forAppBundleURL: appURL))
    }

    func testActivationPreflightAllowsFirmlinkedApplicationsBundle() {
        let appURL = URL(fileURLWithPath: "/System/Volumes/Data/Applications/Tally.app")

        XCTAssertNil(SystemExtensionActivator.activationPreflightState(forAppBundleURL: appURL))
    }

    func testActivationPreflightRejectsDerivedDataBundle() {
        let appURL = URL(
            fileURLWithPath: "/Users/example/Library/Developer/Xcode/DerivedData/Tally/Build/Products/Debug/Tally.app"
        )

        guard case .needsMoveToApplications(let message)? =
                SystemExtensionActivator.activationPreflightState(forAppBundleURL: appURL)
        else {
            return XCTFail("Expected DerivedData app bundle to be rejected")
        }

        XCTAssertTrue(message.contains("DerivedData"))
        XCTAssertTrue(message.contains("/Applications/Tally.app"))
    }

    func testActivationPreflightRejectsOtherNonApplicationsBundle() {
        let appURL = URL(fileURLWithPath: "/Users/example/Downloads/Tally.app")

        guard case .needsMoveToApplications(let message)? =
                SystemExtensionActivator.activationPreflightState(forAppBundleURL: appURL)
        else {
            return XCTFail("Expected non-Applications app bundle to be rejected")
        }

        XCTAssertTrue(message.contains("/Users/example/Downloads/Tally.app"))
        XCTAssertTrue(message.contains("/Applications/Tally.app"))
    }
}
