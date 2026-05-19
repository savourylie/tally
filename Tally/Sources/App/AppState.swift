import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    let database: DatabaseManager
    let usageStore: UsageStore?
    let collector: FlowCollector?

    init() {
        do {
            self.database = try DatabaseManager()
        } catch {
            Log.db.error("[db] init failed: \(String(describing: error), privacy: .public)")
            fatalError("DatabaseManager init failed: \(error)")
        }

        self.usageStore = nil
        Log.store.info("[store] init")

        self.collector = nil
        Log.collector.info("[collector] starting")
    }
}

// Stub. Filled by TICKET-009.
final class UsageStore {}

// Stub. Filled by TICKET-006.
final class FlowCollector {}
