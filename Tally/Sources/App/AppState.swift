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

        // TICKET-033: the production NE path starts suspended (collectionHealthy:
        // false) so historical aggregates never flash as live before the launch-time
        // health check resolves. The nettop fallback stays healthy by default.
#if DEBUG && USE_NETTOP
        let collectionInitiallyHealthy = true
#else
        let collectionInitiallyHealthy = false
#endif
        let store = UsageStore(
            dbPool: database.dbPool,
            metadataService: appMetadata,
            categorizer: categorizer,
            preferences: preferences,
            collectionHealthy: collectionInitiallyHealthy
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
#if DEBUG && USE_NETTOP
        flowCollector.start()
#else
        startProductionCollectorGated()
#endif

        // Request notification authorization and start threshold monitoring
        Task {
            await coordinator.requestAuthorization()
            self.thresholdEngine.start()
        }
    }

#if !(DEBUG && USE_NETTOP)
    /// TICKET-033: gate production NE collection on confirmed content-filter health.
    /// Before onboarding completes the user drives activation through `PermissionStep`,
    /// so the gate is deferred until then (AC7); afterwards it runs on each launch.
    private func startProductionCollectorGated() {
        guard let ne = collector as? NEFlowCollector else {
            collector.start()
            return
        }
        if preferences.onboardingComplete {
            runHealthGate(ne)
        } else {
            Task { @MainActor in
                while !preferences.onboardingComplete {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        withObservationTracking {
                            _ = preferences.onboardingComplete
                        } onChange: {
                            continuation.resume()
                        }
                    }
                }
                runHealthGate(ne)
            }
        }
    }

    /// Runs the launch-time health check, then either starts polling (healthy) or
    /// puts both the collector and the store into an explicit non-live state (AC4, AC5).
    private func runHealthGate(_ ne: NEFlowCollector) {
        Task { @MainActor in
            switch await systemExtensionActivator.verifyCollectionHealth() {
            case .healthy:
                usageStore.markCollectionHealthy()
                ne.start()
            case .unavailable(let reason):
                ne.markUnavailable(reason)
                usageStore.markCollectionUnavailable(reason)
            }
        }
    }
#endif
}

private var isDevelopmentBuild: Bool {
#if DEBUG
    true
#else
    false
#endif
}
