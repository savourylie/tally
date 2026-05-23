import Observation

enum SidebarSelection: String, CaseIterable, Identifiable {
    case overview
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "總覽"
        case .settings:
            return "設定"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "chart.bar"
        case .settings:
            return "gearshape"
        }
    }

    var placeholder: String {
        switch self {
        case .overview:
            return "Overview placeholder"
        case .settings:
            return "Settings placeholder"
        }
    }
}

@MainActor
@Observable
final class MainWindowSessionState {
    var selection: SidebarSelection = .overview
}
