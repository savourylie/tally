import Foundation

/// Tracks which notification thresholds have already fired in the current
/// billing cycle, preventing duplicate alerts.
///
/// Keys are stored in `UserDefaults` with the format:
///   `pref.notif.fired.<yyyy-MM-dd>.<80|95|100>`
///
/// On each check the ledger lazily cleans up keys from cycles older than 2
/// periods back.
struct FiredThresholdsLedger {
    private let store: UserDefaults

    /// ISO-8601 date formatter for cycle-start keys.
    private static let iso: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    init(store: UserDefaults = UserDefaults(suiteName: "com.calvinku.Tally.preferences") ?? .standard) {
        self.store = store
    }

    // MARK: - Public API

    /// Returns `true` if the given threshold has already fired in the cycle
    /// that starts on `cycleStart`.
    func hasFired(threshold: Int, cycleStart: Date) -> Bool {
        let key = Self.key(threshold: threshold, cycleStart: cycleStart)
        return store.bool(forKey: key)
    }

    /// Records that `threshold` has fired for the cycle starting on `cycleStart`.
    func markFired(threshold: Int, cycleStart: Date) {
        let key = Self.key(threshold: threshold, cycleStart: cycleStart)
        store.set(true, forKey: key)
        Log.notif.info("[notif] marked fired: \(key, privacy: .public)")
    }

    /// Removes ledger entries for cycles older than `keepCycles` periods
    /// before `currentCycleStart`.
    func cleanupStaleEntries(currentCycleStart: Date, keepCycles: Int = 2) {
        let prefix = "pref.notif.fired."
        let currentKey = Self.iso.string(from: currentCycleStart)

        // Walk all keys and remove those that are from old cycles
        let allKeys = store.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(prefix)
        }

        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .month, value: -keepCycles, to: currentCycleStart)
            ?? currentCycleStart

        for key in allKeys {
            // Extract the date part: pref.notif.fired.YYYY-MM-DD.XX
            let parts = key.dropFirst(prefix.count)
            let dateStr = String(parts.prefix(10)) // "yyyy-MM-dd"

            guard dateStr != currentKey,
                  let entryDate = Self.iso.date(from: dateStr),
                  entryDate < cutoff else {
                continue
            }

            store.removeObject(forKey: key)
            Log.notif.debug("[notif] cleaned stale key: \(key, privacy: .public)")
        }
    }

    // MARK: - Private

    private static func key(threshold: Int, cycleStart: Date) -> String {
        let dateStr = iso.string(from: cycleStart)
        return "pref.notif.fired.\(dateStr).\(threshold)"
    }
}
