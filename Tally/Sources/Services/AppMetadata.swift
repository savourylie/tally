import AppKit
import Foundation

struct AppMetadata: @unchecked Sendable, Equatable {
    let displayName: String
    let icon: NSImage

    static func == (lhs: AppMetadata, rhs: AppMetadata) -> Bool {
        lhs.displayName == rhs.displayName && lhs.icon === rhs.icon
    }
}
