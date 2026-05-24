import AppKit
import Foundation
import NetworkExtension
import Observation
import SystemExtensions

enum SystemExtensionActivationState: Equatable, Sendable {
    case idle
    case activating
    case waitingForApproval
    case enabled
    case denied(String)
    case failed(String)
    // macOS rejects system-extension activation when the host app is outside
    // /Applications (e.g. Downloads, DerivedData, a mounted DMG). User must
    // move the app and relaunch; visiting Settings will not help.
    case needsMoveToApplications(String)

    var isEnabled: Bool {
        if case .enabled = self { return true }
        return false
    }

    var canRetry: Bool {
        switch self {
        case .idle, .denied, .failed, .needsMoveToApplications(_):
            return true
        case .activating, .waitingForApproval, .enabled:
            return false
        }
    }

    var userMessage: String {
        switch self {
        case .idle:
            return "Tally 會請 macOS 顯示批准提示。"
        case .activating:
            return "正在請 macOS 打開批准流程。"
        case .waitingForApproval:
            return "請到『登入項目與擴充功能 → 網路擴充功能』批准 Tally。批准後這裡會自動更新。"
        case .enabled:
            return "已經批准，Tally 可以開始統計每個 app 的流量。"
        case .denied(let message), .failed(let message), .needsMoveToApplications(let message):
            return message
        }
    }
}

@Observable
final class SystemExtensionActivator: NSObject {
    static let extensionBundleIdentifier = "com.calvinku.tally.filter"
    static let expectedAppBundlePath = "/Applications/Tally.app"

    private(set) var state: SystemExtensionActivationState = .idle

    @ObservationIgnored private var requestInFlight = false
    @ObservationIgnored private let appBundleURL: URL

    init(appBundleURL: URL = Bundle.main.bundleURL) {
        self.appBundleURL = appBundleURL
        super.init()
    }

    func requestActivation() {
        guard !requestInFlight else { return }
        guard state.canRetry else { return }

        let appBundlePath = appBundleURL.standardizedFileURL.path
        Log.ne.info(
            "[ne] preparing system extension activation appBundle=\(appBundlePath, privacy: .public) extension=\(Self.extensionBundleIdentifier, privacy: .public)"
        )

        if let preflightState = Self.activationPreflightState(forAppBundleURL: appBundleURL) {
            state = preflightState
            Log.ne.error(
                "[ne] system extension activation preflight failed appBundle=\(appBundlePath, privacy: .public) expected=\(Self.expectedAppBundlePath, privacy: .public) extension=\(Self.extensionBundleIdentifier, privacy: .public)"
            )
            return
        }

        requestInFlight = true
        state = .activating

        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.extensionBundleIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        Log.ne.info(
            "[ne] submitted system extension activation request appBundle=\(appBundlePath, privacy: .public) extension=\(Self.extensionBundleIdentifier, privacy: .public)"
        )
    }

    func requestActivationIfNeeded() {
        guard state.canRetry else { return }
        requestActivation()
    }

    func openExtensionsSettings() {
        let urlString = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            Log.ui.info("SystemExtensionActivator: opened System Settings -> Login Items & Extensions")
        }
    }

    func recoverActivation() {
        if case .waitingForApproval = state {
            openExtensionsSettings()
        } else if case .needsMoveToApplications(_) = state {
            revealAppInFinder()
        } else if state.canRetry {
            requestActivation()
        }
    }

    func revealAppInFinder() {
        let appURL = appBundleURL
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
        Log.ui.info("SystemExtensionActivator: revealed app in Finder at \(appURL.path, privacy: .public)")
    }

    static func activationPreflightState(
        forAppBundleURL appBundleURL: URL
    ) -> SystemExtensionActivationState? {
        let appBundlePath = appBundleURL.standardizedFileURL.path
        guard isSupportedAppBundlePath(appBundlePath) else {
            return .needsMoveToApplications(moveToApplicationsMessage(for: appBundlePath))
        }
        return nil
    }

    private static func isSupportedAppBundlePath(_ path: String) -> Bool {
        path == expectedAppBundlePath
            || path == "/System/Volumes/Data\(expectedAppBundlePath)"
    }

    private static func moveToApplicationsMessage(for appBundlePath: String) -> String {
        if appBundlePath.contains("/DerivedData/") {
            return "Tally 現在是從 Xcode 的 DerivedData 執行，macOS 不會在「網路擴充功能」顯示這個版本。請先關閉目前這個 Tally，然後從 /Applications/Tally.app 重新打開。"
        }

        return "Tally 現在是從 \(appBundlePath) 執行。請把 Tally 放在 /Applications/Tally.app，並從「應用程式」重新打開；macOS 才會顯示網路權限。"
    }

    private func finishEnabled() {
        Task {
            do {
                try await ContentFilterConfigurator.enable()
                await MainActor.run {
                    self.requestInFlight = false
                    self.state = .enabled
                }
                Log.ne.info("[ne] content filter enabled")
            } catch {
                await MainActor.run {
                    self.requestInFlight = false
                    self.state = .failed("Tally 已送出批准流程，但內容過濾器還沒啟用。請按「再試一次」重新檢查。")
                }
                Log.ne.error("[ne] content filter enable failed error=\(String(describing: error), privacy: .public)")
            }
        }
    }
}

extension SystemExtensionActivator: @unchecked Sendable {}

extension SystemExtensionActivator: OSSystemExtensionRequestDelegate {
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        requestInFlight = false
        state = .waitingForApproval
        Log.ne.info("[ne] system extension requires user approval")
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        switch result {
        case .completed:
            Log.ne.info("[ne] system extension activation completed")
            finishEnabled()
        case .willCompleteAfterReboot:
            requestInFlight = false
            state = .waitingForApproval
            Log.ne.info("[ne] system extension activation will complete after reboot")
        @unknown default:
            requestInFlight = false
            state = .failed("macOS 沒有完成 Tally 的網路權限流程。請按「再試一次」重新送出要求。")
        }
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFailWithError error: Error
    ) {
        requestInFlight = false
        let nsError = error as NSError
        if nsError.domain == OSSystemExtensionErrorDomain,
           let code = OSSystemExtensionError.Code(rawValue: nsError.code) {
            switch code {
            case .requestCanceled, .forbiddenBySystemPolicy:
                state = .denied("macOS 尚未批准 Tally。請按「再試一次」重新送出網路權限要求。")
            case .authorizationRequired:
                state = .waitingForApproval
            case .unsupportedParentBundleLocation:
                state = .needsMoveToApplications(Self.moveToApplicationsMessage(for: appBundleURL.standardizedFileURL.path))
            case .extensionNotFound:
                state = .failed("macOS 找不到 Tally app bundle 裡可註冊的網路擴充功能。請用最新 build 取代 /Applications/Tally.app，重新打開後再按「再試一次」。")
            case .validationFailed:
                state = .failed("macOS 找到 Tally 的網路擴充功能，但它的 bundle 設定無法通過驗證。請用最新 build 取代 /Applications/Tally.app，重新打開後再按「再試一次」。")
            default:
                state = .failed("macOS 無法送出 Tally 的網路權限要求。請按「再試一次」。")
            }
        } else {
            state = .failed("macOS 無法送出 Tally 的網路權限要求。請按「再試一次」。")
        }
        Log.ne.error(
            "[ne] system extension activation failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) appBundle=\(self.appBundleURL.path, privacy: .public) extension=\(Self.extensionBundleIdentifier, privacy: .public) error=\(String(describing: error), privacy: .public)"
        )
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension replacement: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        Log.ne.info("[ne] replacing system extension version=\(existing.bundleShortVersion, privacy: .public)")
        return .replace
    }
}

private enum ContentFilterConfigurator {
    static func enable() async throws {
        let manager = NEFilterManager.shared()
        try await load(manager)

        let configuration = manager.providerConfiguration ?? NEFilterProviderConfiguration()
        configuration.filterSockets = true
        configuration.filterPackets = false
        configuration.filterDataProviderBundleIdentifier = SystemExtensionActivator.extensionBundleIdentifier
        configuration.vendorConfiguration = [
            "AppGroup": TallyAppGroup.identifier,
            "FlowEventsFile": TallyAppGroup.flowEventsFilename,
        ]

        manager.localizedDescription = "Tally"
        manager.providerConfiguration = configuration
        manager.isEnabled = true

        try await save(manager)
    }

    private static func load(_ manager: NEFilterManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func save(_ manager: NEFilterManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
