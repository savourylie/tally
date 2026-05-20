import AppKit
import Foundation
import GRDB

actor AppMetadataService {
    enum Key: Hashable, Sendable {
        case bundleID(String)
        case category(String)
    }

    private var cache: [Key: AppMetadata] = [:]
    private let categoryMap: [String: CategoryEntry]

    init(dbPool: DatabasePool) {
        self.categoryMap = Self.loadCategoryMap(dbPool: dbPool)
        Self.registerWorkspaceObservers(target: self)
        Log.meta.info("[meta] init categories=\(self.categoryMap.count, privacy: .public)")
    }

    func metadata(forBundleID bundleID: String) -> AppMetadata {
        if let cached = cache[.bundleID(bundleID)] { return cached }
        let resolved = Self.resolveBundle(bundleID)
        cache[.bundleID(bundleID)] = resolved
        Log.meta.debug("[meta] resolve bundle=\(bundleID, privacy: .public) name=\(resolved.displayName, privacy: .public)")
        return resolved
    }

    func metadata(forCategory categoryName: String) -> AppMetadata {
        if let cached = cache[.category(categoryName)] { return cached }
        let resolved = Self.resolveCategory(categoryName, map: categoryMap)
        cache[.category(categoryName)] = resolved
        Log.meta.debug("[meta] resolve category=\(categoryName, privacy: .public) name=\(resolved.displayName, privacy: .public)")
        return resolved
    }

    func evictBundleID(_ bundleID: String) {
        guard cache.removeValue(forKey: .bundleID(bundleID)) != nil else { return }
        Log.meta.debug("[meta] evict bundle=\(bundleID, privacy: .public)")
    }
}

private struct CategoryEntry {
    let displayName: String
    let iconName: String
}

// MARK: - DB load

private extension AppMetadataService {
    static func loadCategoryMap(dbPool: DatabasePool) -> [String: CategoryEntry] {
        do {
            return try dbPool.read { db in
                var map: [String: CategoryEntry] = [:]
                let rows = try Row.fetchAll(db, sql: """
                    SELECT DISTINCT category_name, icon_name, display_name
                    FROM process_categories
                    """)
                for row in rows {
                    let category: String = row["category_name"]
                    let display: String = row["display_name"]
                    let icon: String = row["icon_name"]
                    map[category] = CategoryEntry(displayName: display, iconName: icon)
                }
                return map
            }
        } catch {
            Log.meta.error("[meta] load categories failed: \(String(describing: error), privacy: .public)")
            return [:]
        }
    }
}

// MARK: - Lookups

private extension AppMetadataService {
    static func resolveBundle(_ bundleID: String) -> AppMetadata {
        let workspace = NSWorkspace.shared
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
            return placeholder(displayName: bundleID)
        }
        let bundle = Bundle(url: url)
        let name = (bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle?.localizedInfoDictionary?["CFBundleName"] as? String)
            ?? (bundle?.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let icon = workspace.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        return AppMetadata(displayName: name, icon: icon)
    }

    static func resolveCategory(_ name: String, map: [String: CategoryEntry]) -> AppMetadata {
        guard let entry = map[name] else {
            return placeholder(displayName: name)
        }
        let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        let raw = NSImage(systemSymbolName: entry.iconName, accessibilityDescription: entry.displayName)
        let icon = raw?.withSymbolConfiguration(config) ?? placeholderImage()
        return AppMetadata(displayName: entry.displayName, icon: icon)
    }

    static func placeholder(displayName: String) -> AppMetadata {
        AppMetadata(displayName: displayName, icon: placeholderImage())
    }

    static func placeholderImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        let img = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: "unknown app")
        return img?.withSymbolConfiguration(config) ?? NSImage()
    }
}

// MARK: - NSWorkspace observers

private extension AppMetadataService {
    static func registerWorkspaceObservers(target: AppMetadataService) {
        let nc = NSWorkspace.shared.notificationCenter
        let handler: @Sendable (Notification) -> Void = { [weak target] notif in
            guard let target,
                  let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bid = app.bundleIdentifier else { return }
            Task { await target.evictBundleID(bid) }
        }
        nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main,
            using: handler
        )
        nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main,
            using: handler
        )
    }
}
