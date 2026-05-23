import Foundation

enum NetworkConnection: Equatable, Sendable {
    case wifi(name: String)
    case ethernet
    case offline

    var displayName: String {
        switch self {
        case .wifi(let name):
            return name
        case .ethernet:
            return "乙太網路"
        case .offline:
            return "未連線"
        }
    }

    var symbolName: String {
        switch self {
        case .wifi:
            return "wifi"
        case .ethernet:
            return "cable.connector"
        case .offline:
            return "wifi.slash"
        }
    }

    var isOffline: Bool {
        self == .offline
    }
}
