import Foundation
import Observation

/// Subscribes to `UsageStore` updates and fires local notifications when
/// usage crosses 80%, 95%, or 100% of the monthly cap.
///
/// Each threshold fires **at most once per billing cycle** (tracked by
/// `FiredThresholdsLedger`). When multiple thresholds are crossed
/// simultaneously (e.g., 0 → 100%), all enabled ones fire in ascending order.
///
/// Owned by `AppState`; on init subscribes to `usageStore` and `preferences`
/// reactively. Cancellable on app teardown.
@MainActor
@Observable
final class ThresholdEngine {
    static let thresholds: [Int] = [80, 95, 100]

    @ObservationIgnored private let usageStore: UsageStore
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let coordinator: NotificationCoordinator
    @ObservationIgnored private let ledger: FiredThresholdsLedger
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    init(
        usageStore: UsageStore,
        preferences: Preferences,
        coordinator: NotificationCoordinator,
        ledger: FiredThresholdsLedger = FiredThresholdsLedger()
    ) {
        self.usageStore = usageStore
        self.preferences = preferences
        self.coordinator = coordinator
        self.ledger = ledger
        Log.notif.info("[notif] ThresholdEngine init")
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Start observing `usageStore.monthToDateBytes` for threshold crossings.
    func start() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            // Initial evaluation
            self?.evaluate()

            // Reactive loop — re-evaluate whenever usage or preferences change
            while !Task.isCancelled {
                guard let self else { return }
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    _ = withObservationTracking {
                        // Touch the properties we want to observe
                        _ = self.usageStore.monthToDateBytes
                        _ = self.usageStore.currentCycle
                        _ = self.preferences.monthlyLimitGB
                        _ = self.preferences.alertAt80
                        _ = self.preferences.alertAt95
                        _ = self.preferences.alertAt100
                    } onChange: {
                        continuation.resume()
                    }
                }

                if !Task.isCancelled {
                    self.evaluate()
                }
            }
        }
    }

    // MARK: - Evaluation

    /// Check current usage percentage against each threshold and fire
    /// notifications as needed.
    private func evaluate() {
        // Defensive: no cap → no notifications
        guard let capBytes = usageStore.monthlyCapBytes, capBytes > 0 else {
            Log.notif.debug("[notif] no cap set — skipping evaluation")
            return
        }

        guard let cycle = usageStore.currentCycle else {
            Log.notif.debug("[notif] no current cycle — skipping evaluation")
            return
        }

        let totalBytes = usageStore.monthToDateBytes.bytesIn + usageStore.monthToDateBytes.bytesOut
        let percentage = Double(totalBytes) / Double(capBytes) * 100.0

        Log.notif.debug("[notif] evaluate: \(Int(percentage), privacy: .public)% (\(totalBytes, privacy: .public) / \(capBytes, privacy: .public))")

        // Clean up stale ledger entries lazily
        ledger.cleanupStaleEntries(currentCycleStart: cycle.start)

        // Fire thresholds in ascending order (80, 95, 100)
        for threshold in Self.thresholds {
            guard percentage >= Double(threshold) else { continue }
            guard isThresholdEnabled(threshold) else { continue }
            guard !ledger.hasFired(threshold: threshold, cycleStart: cycle.start) else { continue }

            // Fire!
            coordinator.fireThresholdNotification(percent: threshold)
            ledger.markFired(threshold: threshold, cycleStart: cycle.start)
        }
    }

    /// Returns whether the given threshold is enabled in user preferences.
    private func isThresholdEnabled(_ threshold: Int) -> Bool {
        switch threshold {
        case 80:  return preferences.alertAt80
        case 95:  return preferences.alertAt95
        case 100: return preferences.alertAt100
        default:  return false
        }
    }
}
