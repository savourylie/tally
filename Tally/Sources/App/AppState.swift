import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    let database: DatabaseManager
    let usageStore: UsageStore?
    let collector: any FlowCollector

    init() {
        do {
            self.database = try DatabaseManager()
        } catch {
            Log.db.error("[db] init failed: \(String(describing: error), privacy: .public)")
            fatalError("DatabaseManager init failed: \(error)")
        }

        self.usageStore = nil
        Log.store.info("[store] init")

        let nettop = NettopCollector(dbPool: database.dbPool)
        self.collector = nettop
        nettop.start()
    }
}

// Stub. Filled by TICKET-009.
final class UsageStore {}
