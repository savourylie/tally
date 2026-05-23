import Foundation

enum AppOrCategoryEntry: Hashable, Sendable {
    case app(bundleID: String)
    case category(name: String)
}
