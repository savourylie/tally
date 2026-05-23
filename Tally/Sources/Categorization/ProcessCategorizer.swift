import Foundation
import GRDB
import AppKit

actor ProcessCategorizer {
    private let dbPool: DatabasePool
    private var categoryMap: [String: String] = [:] // process_identifier -> category_name
    private var unmappedLogged = Set<String>()

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func load() async {
        do {
            let map: [String: String] = try await dbPool.read { db in
                var result: [String: String] = [:]
                let rows = try Row.fetchAll(db, sql: """
                    SELECT process_identifier, category_name 
                    FROM process_categories
                    """)
                for row in rows {
                    let pid: String = row["process_identifier"]
                    let cat: String = row["category_name"]
                    result[pid] = cat
                }
                return result
            }
            self.categoryMap = map
            Log.agg.info("[categorizer] loaded \(map.count, privacy: .public) process categories")
        } catch {
            Log.agg.error("[categorizer] failed to load process categories: \(String(describing: error), privacy: .public)")
        }
    }

    func categorize(bundleID: String?, category: String?) -> AppOrCategoryEntry {
        if let bundleID = bundleID, !bundleID.isEmpty {
            let identifier = bundleID
            let baseName = URL(fileURLWithPath: bundleID).lastPathComponent
            
            // Check category mapping first to capture system processes (daemons)
            if let catName = categoryMap[identifier] {
                return .category(name: catName)
            } else if let catName = categoryMap[baseName] {
                return .category(name: catName)
            }
            // Otherwise check if it resolves to an installed GUI application
            else if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
                return .app(bundleID: bundleID)
            }
            // Fall back to unmapped logging and system other
            else {
                if !unmappedLogged.contains(baseName) {
                    unmappedLogged.insert(baseName)
                    Log.agg.debug("[categorizer] unmapped process: \(baseName, privacy: .public)")
                }
                return .category(name: "系統其他")
            }
        } else if let category = category, !category.isEmpty {
            return .category(name: category)
        } else {
            return .category(name: "系統其他")
        }
    }
}
