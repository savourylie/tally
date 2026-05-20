import Foundation

struct AppUsageEntry: Identifiable, Equatable, Sendable {
    enum Kind: Hashable, Sendable {
        case app(bundleID: String)
        case category(name: String)
    }

    let kind: Kind
    let bytesIn: Int64
    let bytesOut: Int64
    let metadata: AppMetadata

    var id: Kind { kind }
    var totalBytes: Int64 { bytesIn + bytesOut }
}
