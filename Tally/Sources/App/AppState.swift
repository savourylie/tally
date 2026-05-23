import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    let database: DatabaseManager
    let appMetadata: AppMetadataService
    let processCategorizer: ProcessCategorizer
    let usageStore: UsageStore
    let collector: any FlowCollector
    let aggregator: Aggregator
    let mainWindow: MainWindowSessionState
    let preferences: Preferences
    let systemExtensionActivator: SystemExtensionActivator
    let notificationCoordinator: NotificationCoordinator
    let thresholdEngine: ThresholdEngine

    init() {
        self.mainWindow = MainWindowSessionState()
        self.preferences = Preferences()
        self.systemExtensionActivator = SystemExtensionActivator()

        do {
            self.database = try DatabaseManager()
        } catch {
            Log.db.error("[db] init failed: \(String(describing: error), privacy: .public)")
            fatalError("DatabaseManager init failed: \(error)")
        }

        self.appMetadata = AppMetadataService(dbPool: database.dbPool)
        
        let categorizer = ProcessCategorizer(dbPool: database.dbPool)
        self.processCategorizer = categorizer
        Task {
            await categorizer.load()
        }

        let store = UsageStore(
            dbPool: database.dbPool,
            metadataService: appMetadata,
            categorizer: categorizer,
            preferences: preferences
        )
        store.start()
        self.usageStore = store

        let agg = Aggregator(dbPool: database.dbPool)
        self.aggregator = agg

        let flowCollector: any FlowCollector
#if DEBUG && USE_NETTOP
        flowCollector = NettopCollector(dbPool: database.dbPool) {
            await agg.runOnce()
        }
#else
        flowCollector = NEFlowCollector(
            dbPool: database.dbPool,
            allowDevelopmentFallback: isDevelopmentBuild
        ) {
            await agg.runOnce()
        }
#endif
        self.collector = flowCollector

        // Notification engine
        let coordinator = NotificationCoordinator()
        self.notificationCoordinator = coordinator
        self.thresholdEngine = ThresholdEngine(
            usageStore: store,
            preferences: preferences,
            coordinator: coordinator
        )

        Task { await agg.start() }
        flowCollector.start()

        // Request notification authorization and start threshold monitoring
        Task {
            await coordinator.requestAuthorization()
            self.thresholdEngine.start()
        }
    }
}

private var isDevelopmentBuild: Bool {
#if DEBUG
    true
#else
    false
#endif
}
