import Foundation
import Observation

@Observable
final class Preferences {
    private let store: UserDefaults
    typealias Keys = PreferencesKeys

    var cycleStartDay: Int {
        didSet {
            let clamped = max(1, min(31, cycleStartDay))
            if clamped != cycleStartDay {
                cycleStartDay = clamped
            }
            store.set(clamped, forKey: Keys.cycleStartDay)
            Log.pref.info("Preferences: cycleStartDay changed to \(clamped)")
        }
    }

    var monthlyLimitGB: Double? {
        didSet {
            if let limit = monthlyLimitGB, limit >= 0 {
                store.set(limit, forKey: Keys.monthlyLimitGB)
                Log.pref.info("Preferences: monthlyLimitGB changed to \(limit)")
            } else {
                if monthlyLimitGB != nil {
                    monthlyLimitGB = nil
                }
                store.set(0.0, forKey: Keys.monthlyLimitGB)
                Log.pref.info("Preferences: monthlyLimitGB changed to nil (no limit)")
            }
        }
    }

    var alertAt80: Bool {
        didSet {
            store.set(alertAt80, forKey: Keys.alertAt80)
            Log.pref.info("Preferences: alertAt80 changed to \(self.alertAt80)")
        }
    }

    var alertAt95: Bool {
        didSet {
            store.set(alertAt95, forKey: Keys.alertAt95)
            Log.pref.info("Preferences: alertAt95 changed to \(self.alertAt95)")
        }
    }

    var alertAt100: Bool {
        didSet {
            store.set(alertAt100, forKey: Keys.alertAt100)
            Log.pref.info("Preferences: alertAt100 changed to \(self.alertAt100)")
        }
    }

    var autostart: Bool {
        didSet {
            store.set(autostart, forKey: Keys.autostart)
            Log.pref.info("Preferences: autostart changed to \(self.autostart)")
        }
    }

    var advancedMode: Bool {
        didSet {
            store.set(advancedMode, forKey: Keys.advancedMode)
            Log.pref.info("Preferences: advancedMode changed to \(self.advancedMode)")
        }
    }

    var onboardingComplete: Bool {
        didSet {
            store.set(onboardingComplete, forKey: Keys.onboardingComplete)
            Log.pref.info("Preferences: onboardingComplete changed to \(self.onboardingComplete)")
        }
    }

    init(store: UserDefaults = UserDefaults(suiteName: "com.calvinku.Tally.preferences") ?? .standard) {
        self.store = store

        // Register default values for first launch
        let defaults: [String: Any] = [
            Keys.cycleStartDay: 1,
            Keys.monthlyLimitGB: 0.0, // Sentinel for nil (no limit)
            Keys.alertAt80: true,
            Keys.alertAt95: true,
            Keys.alertAt100: true,
            Keys.autostart: false,
            Keys.advancedMode: false,
            Keys.onboardingComplete: false
        ]
        store.register(defaults: defaults)

        // Load initial values from store
        self.cycleStartDay = store.integer(forKey: Keys.cycleStartDay)
        
        let limitVal = store.double(forKey: Keys.monthlyLimitGB)
        self.monthlyLimitGB = limitVal > 0 ? limitVal : nil

        self.alertAt80 = store.bool(forKey: Keys.alertAt80)
        self.alertAt95 = store.bool(forKey: Keys.alertAt95)
        self.alertAt100 = store.bool(forKey: Keys.alertAt100)
        self.autostart = store.bool(forKey: Keys.autostart)
        self.advancedMode = store.bool(forKey: Keys.advancedMode)
        self.onboardingComplete = store.bool(forKey: Keys.onboardingComplete)

        Log.pref.info("Loaded Preferences: cycleStartDay=\(self.cycleStartDay), monthlyLimitGB=\(String(describing: self.monthlyLimitGB)), alertAt80=\(self.alertAt80), alertAt95=\(self.alertAt95), alertAt100=\(self.alertAt100), autostart=\(self.autostart), advancedMode=\(self.advancedMode), onboardingComplete=\(self.onboardingComplete)")
    }
}
