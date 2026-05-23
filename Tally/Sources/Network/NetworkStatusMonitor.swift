import CoreWLAN
import Foundation
import Network

final class NetworkStatusMonitor: @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.calvinku.tally.network-status")
    private let onChange: @MainActor @Sendable (NetworkConnection) -> Void
    private var didStart = false

    init(onChange: @escaping @MainActor @Sendable (NetworkConnection) -> Void) {
        self.monitor = NWPathMonitor()
        self.onChange = onChange
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        let onChange = onChange
        monitor.pathUpdateHandler = { path in
            let connection = Self.connection(for: path)
            Task { @MainActor in
                onChange(connection)
            }
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }

    deinit {
        cancel()
    }

    private static func connection(for path: NWPath) -> NetworkConnection {
        guard path.status == .satisfied else {
            return .offline
        }

        if path.usesInterfaceType(.wifi) {
            // Hotspot detection is deferred to v0.2; MVP reports the active Wi-Fi name as-is.
            return .wifi(name: activeSSID() ?? "Wi-Fi")
        }

        if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }

        return .ethernet
    }

    private static func activeSSID() -> String? {
        guard let ssid = CWWiFiClient.shared().interface()?.ssid(),
              !ssid.isEmpty else {
            return nil
        }
        return ssid
    }
}
