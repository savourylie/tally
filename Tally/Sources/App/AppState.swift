import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    let database: DatabaseManager
    let usageStore: UsageStore?
    let collector: any FlowCollector
    let aggregator: Aggregator
    let appMetadata: AppMetadataService

    init() {
        do {
            self.database = try DatabaseManager()
        } catch {
            Log.db.error("[db] init failed: \(String(describing: error), privacy: .public)")
            fatalError("DatabaseManager init failed: \(error)")
        }

        self.usageStore = nil
        Log.store.info("[store] init")

        self.appMetadata = AppMetadataService(dbPool: database.dbPool)

        let nettop = NettopCollector(dbPool: database.dbPool)
        self.collector = nettop
        nettop.start()

        let agg = Aggregator(dbPool: database.dbPool)
        self.aggregator = agg
        Task { await agg.start() }
    }
}

// Stub. Filled by TICKET-009.
final class UsageStore {}
