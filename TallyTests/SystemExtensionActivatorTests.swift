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

    // MARK: - TICKET-033 collection health decision

    private let derivedDataAppURL = URL(
        fileURLWithPath: "/Users/example/Library/Developer/Xcode/DerivedData/Tally/Build/Products/Debug/Tally.app"
    )
    private let applicationsAppURL = URL(fileURLWithPath: "/Applications/Tally.app")

    func testCollectionHealthyWhenEnabledWithOurProvider() {
        let health = SystemExtensionActivator.collectionHealth(
            enabledProviderBundleID: SystemExtensionActivator.extensionBundleIdentifier,
            isEnabled: true,
            forAppBundleURL: applicationsAppURL
        )

        XCTAssertEqual(health, .healthy)
    }

    func testCollectionUnavailableWhenEnabledWithForeignProvider() {
        let health = SystemExtensionActivator.collectionHealth(
            enabledProviderBundleID: "com.someoneelse.filter",
            isEnabled: true,
            forAppBundleURL: applicationsAppURL
        )

        guard case .unavailable = health else {
            return XCTFail("A foreign enabled provider must not be treated as our live collection")
        }
    }

    func testCollectionUnavailableWhenDisabledInApplicationsUsesReapproveCopy() {
        let health = SystemExtensionActivator.collectionHealth(
            enabledProviderBundleID: nil,
            isEnabled: false,
            forAppBundleURL: applicationsAppURL
        )

        guard case .unavailable(let message) = health else {
            return XCTFail("A disabled filter must be unavailable")
        }
        // In /Applications the caller attempts re-enable, so the copy is the generic
        // re-approve message — NOT the move-to-Applications path.
        XCTAssertFalse(message.contains("DerivedData"))
        XCTAssertFalse(message.contains("/Applications/Tally.app"))
    }

    func testCollectionUnavailableRequiresMoveFromDerivedDataWhenDisabled() {
        let health = SystemExtensionActivator.collectionHealth(
            enabledProviderBundleID: nil,
            isEnabled: false,
            forAppBundleURL: derivedDataAppURL
        )

        guard case .unavailable(let message) = health else {
            return XCTFail("A disabled filter in DerivedData must be unavailable")
        }
        XCTAssertTrue(message.contains("DerivedData"))
        XCTAssertTrue(message.contains("/Applications/Tally.app"))
    }

    func testCollectionHealthyWhenEnabledEvenFromDerivedData() {
        // An already-enabled filter is healthy regardless of bundle location — we
        // do not force a move when collection is genuinely live (AC2 idempotency).
        let health = SystemExtensionActivator.collectionHealth(
            enabledProviderBundleID: SystemExtensionActivator.extensionBundleIdentifier,
            isEnabled: true,
            forAppBundleURL: derivedDataAppURL
        )

        XCTAssertEqual(health, .healthy)
    }
}
