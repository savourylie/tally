import XCTest
@testable import Tally

final class PreferencesTests: XCTestCase {
    private var testUserDefaults: UserDefaults!
    private var preferences: Preferences!
    private let suiteName = "com.calvinku.Tally.preferences.tests"

    override func setUp() {
        super.setUp()
        // Remove suite to start with a fresh slate for every test
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        testUserDefaults = UserDefaults(suiteName: suiteName)!
        preferences = Preferences(store: testUserDefaults)
    }

    override func tearDown() {
        testUserDefaults = nil
        preferences = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultValues() {
        XCTAssertEqual(preferences.cycleStartDay, 1)
        XCTAssertNil(preferences.monthlyLimitGB)
        XCTAssertTrue(preferences.alertAt80)
        XCTAssertTrue(preferences.alertAt95)
        XCTAssertTrue(preferences.alertAt100)
        XCTAssertFalse(preferences.autostart)
        XCTAssertFalse(preferences.advancedMode)
        XCTAssertFalse(preferences.onboardingComplete)
    }

    func testRoundTripPersistence() {
        preferences.cycleStartDay = 15
        preferences.monthlyLimitGB = 50.0
        preferences.alertAt80 = false
        preferences.alertAt95 = false
        preferences.alertAt100 = false
        preferences.autostart = true
        preferences.advancedMode = true
        preferences.onboardingComplete = true

        // Create a new Preferences instance sharing the same store to verify it survives relaunch
        let relaunchedPrefs = Preferences(store: testUserDefaults)
        XCTAssertEqual(relaunchedPrefs.cycleStartDay, 15)
        XCTAssertEqual(relaunchedPrefs.monthlyLimitGB, 50.0)
        XCTAssertFalse(relaunchedPrefs.alertAt80)
        XCTAssertFalse(relaunchedPrefs.alertAt95)
        XCTAssertFalse(relaunchedPrefs.alertAt100)
        XCTAssertTrue(relaunchedPrefs.autostart)
        XCTAssertTrue(relaunchedPrefs.advancedMode)
        XCTAssertTrue(relaunchedPrefs.onboardingComplete)
    }

    func testCycleStartDayClamping() {
        preferences.cycleStartDay = 0
        XCTAssertEqual(preferences.cycleStartDay, 1)
        XCTAssertEqual(testUserDefaults.integer(forKey: PreferencesKeys.cycleStartDay), 1)

        preferences.cycleStartDay = 32
        XCTAssertEqual(preferences.cycleStartDay, 31)
        XCTAssertEqual(testUserDefaults.integer(forKey: PreferencesKeys.cycleStartDay), 31)

        preferences.cycleStartDay = 15
        XCTAssertEqual(preferences.cycleStartDay, 15)
        XCTAssertEqual(testUserDefaults.integer(forKey: PreferencesKeys.cycleStartDay), 15)

        // Relaunch check
        let relaunched = Preferences(store: testUserDefaults)
        XCTAssertEqual(relaunched.cycleStartDay, 15)
        
        relaunched.cycleStartDay = 45
        XCTAssertEqual(relaunched.cycleStartDay, 31)
        
        let relaunched2 = Preferences(store: testUserDefaults)
        XCTAssertEqual(relaunched2.cycleStartDay, 31)
    }

    func testMonthlyLimitGBSentinel() {
        // Set positive value
        preferences.monthlyLimitGB = 25.5
        XCTAssertEqual(preferences.monthlyLimitGB, 25.5)
        XCTAssertEqual(testUserDefaults.double(forKey: PreferencesKeys.monthlyLimitGB), 25.5)

        // Set to nil (no limit)
        preferences.monthlyLimitGB = nil
        XCTAssertNil(preferences.monthlyLimitGB)
        XCTAssertEqual(testUserDefaults.double(forKey: PreferencesKeys.monthlyLimitGB), 0.0)

        // Set negative value (should be treated as nil)
        preferences.monthlyLimitGB = -5.0
        XCTAssertNil(preferences.monthlyLimitGB)
        XCTAssertEqual(testUserDefaults.double(forKey: PreferencesKeys.monthlyLimitGB), 0.0)

        // Relaunch check
        let relaunched = Preferences(store: testUserDefaults)
        XCTAssertNil(relaunched.monthlyLimitGB)
        
        // Relaunch check after setting negative value
        relaunched.monthlyLimitGB = 100.0
        XCTAssertEqual(testUserDefaults.double(forKey: PreferencesKeys.monthlyLimitGB), 100.0)
        
        relaunched.monthlyLimitGB = -10.0
        XCTAssertNil(relaunched.monthlyLimitGB)
        XCTAssertEqual(testUserDefaults.double(forKey: PreferencesKeys.monthlyLimitGB), 0.0)
        
        let relaunched2 = Preferences(store: testUserDefaults)
        XCTAssertNil(relaunched2.monthlyLimitGB)
    }

    func testOnboardingCompleteReset() {
        XCTAssertFalse(preferences.onboardingComplete)
        
        // Complete onboarding
        preferences.cycleStartDay = 5
        preferences.monthlyLimitGB = 30.0
        preferences.onboardingComplete = true
        
        XCTAssertTrue(preferences.onboardingComplete)
        XCTAssertEqual(preferences.cycleStartDay, 5)
        XCTAssertEqual(preferences.monthlyLimitGB, 30.0)
        
        // Reset onboarding Complete
        preferences.onboardingComplete = false
        XCTAssertFalse(preferences.onboardingComplete)
        
        let relaunched = Preferences(store: testUserDefaults)
        XCTAssertFalse(relaunched.onboardingComplete)
        XCTAssertEqual(relaunched.cycleStartDay, 5)
        XCTAssertEqual(relaunched.monthlyLimitGB, 30.0)
    }
}
