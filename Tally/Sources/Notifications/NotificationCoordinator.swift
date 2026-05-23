import Foundation
import UserNotifications

/// Handles `UNUserNotificationCenter` authorization and notification delivery.
///
/// On app launch, requests `.alert + .sound` permission once. If the user
/// denies, logs the refusal and silently skips future scheduling — never
/// pesters the user.
///
/// Also acts as `UNUserNotificationCenterDelegate` to allow banner display
/// while the app is in the foreground.
@MainActor
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private(set) var isAuthorized = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization

    /// Requests notification authorization. Safe to call multiple times —
    /// the OS no-ops after the first grant/deny.
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
            if granted {
                Log.notif.info("[notif] authorization granted")
            } else {
                Log.notif.info("[notif] authorization denied by user")
            }
        } catch {
            isAuthorized = false
            Log.notif.error("[notif] authorization error: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Scheduling

    /// Fires a local notification immediately for the given threshold percentage.
    func fireThresholdNotification(percent: Int) {
        guard isAuthorized else {
            Log.notif.debug("[notif] skipped \(percent, privacy: .public)% — not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Tally"
        content.body = bodyForThreshold(percent)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tally.threshold.\(percent)",
            content: content,
            trigger: nil // fire immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.notif.error("[notif] failed to schedule \(percent, privacy: .public)%: \(String(describing: error), privacy: .public)")
            } else {
                Log.notif.info("[notif] fired \(percent, privacy: .public)% notification")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banner + sound even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: - Copy

    private func bodyForThreshold(_ percent: Int) -> String {
        switch percent {
        case 100:
            return "這個月的流量已經用完了"
        default:
            return "這個月的流量已經用了 \(percent)% 了"
        }
    }
}
