import Foundation
import CoreServices
import os

actor HelperProcessResolver {
    private var cache: [String: String?] = [:]

    private static let knownHelperPrefixes: [(prefix: String, parent: String)] = [
        ("com.google.Chrome.helper",         "com.google.Chrome"),
        ("com.apple.WebKit.",                "com.apple.Safari"),
        ("com.tinyspeck.slackmacgap.helper", "com.tinyspeck.slackmacgap"),
        ("com.microsoft.edgemac.helper",     "com.microsoft.edgemac"),
    ]

    func parentBundle(forHelper helperBundleId: String) -> String? {
        if let cached = cache[helperBundleId] {
            return cached
        }

        for entry in Self.knownHelperPrefixes where helperBundleId.hasPrefix(entry.prefix) {
            cache[helperBundleId] = entry.parent
            return entry.parent
        }

        let resolved = Self.resolveViaLaunchServices(helperBundleId)
        cache[helperBundleId] = resolved
        if resolved == nil {
            Log.agg.info("[agg] helper resolver miss id=\(helperBundleId, privacy: .public)")
        }
        return resolved
    }

    private static func resolveViaLaunchServices(_ helperBundleId: String) -> String? {
        guard let urls = LSCopyApplicationURLsForBundleIdentifier(
            helperBundleId as CFString, nil
        )?.takeRetainedValue() as? [URL],
              let url = urls.first else {
            return nil
        }

        let parts = url.pathComponents
        guard let firstAppIdx = parts.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return nil
        }
        let outerAppPath = "/" + parts[1...firstAppIdx].joined(separator: "/")
        guard let parent = Bundle(path: outerAppPath)?.bundleIdentifier else {
            return nil
        }
        // If the outermost .app's bundle id equals the helper's own id,
        // it wasn't actually a nested helper — don't roll up.
        guard parent != helperBundleId else { return nil }
        return parent
    }
}
