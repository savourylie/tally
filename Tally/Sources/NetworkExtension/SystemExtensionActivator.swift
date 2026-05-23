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

    var isEnabled: Bool {
        if case .enabled = self { return true }
        return false
    }

    var canRetry: Bool {
        switch self {
        case .idle, .denied, .failed:
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
            return "請到系統設定批准 Tally。批准後這裡會自動更新。"
        case .enabled:
            return "已經批准，Tally 可以開始統計每個 app 的流量。"
        case .denied(let message), .failed(let message):
            return message
        }
    }
}

@Observable
final class SystemExtensionActivator: NSObject {
    static let extensionBundleIdentifier = "com.calvinku.tally.filter"

    private(set) var state: SystemExtensionActivationState = .idle

    @ObservationIgnored private var requestInFlight = false

    func requestActivation() {
        guard !requestInFlight else { return }
        guard state.canRetry else { return }

        requestInFlight = true
        state = .activating

        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.extensionBundleIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        Log.ne.info("[ne] submitted system extension activation request")
    }

    func requestActivationIfNeeded() {
        guard state.canRetry else { return }
        requestActivation()
    }

    func openSecuritySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Security"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            Log.ui.info("SystemExtensionActivator: opened System Settings -> Privacy & Security")
        }
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
                    self.state = .failed("目前看不到網路使用情況，請確認 Tally 已在系統設定中獲准。")
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
            state = .failed("目前看不到網路使用情況，請重新批准 Tally。")
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
                state = .denied("你剛剛沒有批准 Tally。請到系統設定批准後再繼續。")
            case .authorizationRequired:
                state = .waitingForApproval
            default:
                state = .failed("目前看不到網路使用情況，請重新批准 Tally。")
            }
        } else {
            state = .failed("目前看不到網路使用情況，請重新批准 Tally。")
        }
        Log.ne.error("[ne] system extension activation failed error=\(String(describing: error), privacy: .public)")
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
