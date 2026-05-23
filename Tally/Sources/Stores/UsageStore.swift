import Foundation
import GRDB
import Observation

@MainActor
@Observable
final class UsageStore {
    enum State: Sendable, Equatable {
        case collecting
        case ready
    }

    struct BytePair: Sendable, Equatable {
        var bytesIn: Int64
        var bytesOut: Int64

        static let zero = BytePair(bytesIn: 0, bytesOut: 0)
    }

    private(set) var state: State = .collecting
    private(set) var monthToDateBytes: BytePair = .zero
    private(set) var topEntries: [AppUsageEntry] = []
    private(set) var currentNetwork: NetworkConnection = .offline
    private(set) var previousCycleTotalBytes: Int64 = 0
    private(set) var currentCycle: BillingCycle?
    var currentNetworkDisplay: String {
        currentNetwork.displayName
    }

    /// Monthly cap in bytes, derived from `Preferences.monthlyLimitGB`.
    /// Returns `nil` when the user has not set a limit.
    var monthlyCapBytes: Int64? {
        guard let gb = preferences.monthlyLimitGB, gb > 0 else { return nil }
        return Int64(gb * 1_073_741_824)
    }

    @ObservationIgnored private let dbPool: DatabasePool
    @ObservationIgnored private let metadataService: AppMetadataService
    @ObservationIgnored private let categorizer: ProcessCategorizer
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private var networkMonitor: NetworkStatusMonitor?
    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?
    @ObservationIgnored private var resolveTask: Task<Void, Never>?
    @ObservationIgnored private var lastResolvedKeys: [AppUsageEntry.Kind] = []
    @ObservationIgnored private var cycleObservationTask: Task<Void, Never>?

    init(
        dbPool: DatabasePool,
        metadataService: AppMetadataService,
        categorizer: ProcessCategorizer,
        preferences: Preferences
    ) {
        self.dbPool = dbPool
        self.metadataService = metadataService
        self.categorizer = categorizer
        self.preferences = preferences
        self.networkMonitor = NetworkStatusMonitor { [weak self] connection in
            self?.currentNetwork = connection
        }
        Log.store.info("[store] init")
    }

    deinit {
        networkMonitor?.cancel()
        resolveTask?.cancel()
        cancellable?.cancel()
        cycleObservationTask?.cancel()
    }

    func start() {
        networkMonitor?.start()
        startObservation()
        observeCycleStartDayChanges()
    }

    func topApps(limit: Int) -> [AppUsageEntry] {
        Array(topEntries.prefix(limit))
    }

    // MARK: - Cycle-Aware Observation

    /// Starts (or restarts) the database observation using the current billing
    /// cycle derived from `preferences.cycleStartDay`.
    private func startObservation() {
        // Cancel any existing observation
        cancellable?.cancel()
        cancellable = nil

        let cycle = BillingCycle.current(forStartDay: preferences.cycleStartDay)
        let previousCycle = BillingCycle.previous(forStartDay: preferences.cycleStartDay)
        self.currentCycle = cycle

        let window = Self.dateWindow(from: cycle)
        let previousWindow = Self.dateWindow(from: previousCycle)

        Log.store.info("[store] start cycle window=\(window.start, privacy: .public)..\(window.end, privacy: .public) (startDay=\(self.preferences.cycleStartDay, privacy: .public))")

        let observation = ValueObservation.tracking { db -> RawUsageSnapshot in
            let rows = try Row.fetchAll(db, sql: """
                SELECT bundle_id, category,
                       SUM(total_in)  AS in_,
                       SUM(total_out) AS out_
                FROM daily_aggregates
                WHERE date >= ? AND date <= ?
                GROUP BY bundle_id, category
                ORDER BY (in_ + out_) DESC
                """, arguments: [window.start, window.end])
            let rawRows = rows.compactMap { row in
                let bundleID: String? = row["bundle_id"]
                let category: String? = row["category"]
                let inBytes: Int64 = row["in_"] ?? 0
                let outBytes: Int64 = row["out_"] ?? 0
                if let bundleID, !bundleID.isEmpty {
                    return RawTopRow(kind: .app(bundleID: bundleID), bytesIn: inBytes, bytesOut: outBytes)
                } else if let category, !category.isEmpty {
                    return RawTopRow(kind: .category(name: category), bytesIn: inBytes, bytesOut: outBytes)
                } else {
                    Log.store.warning("[store] row missing both bundle_id and category — skipping")
                    return nil
                }
            }

            let previousTotal: Int64 = try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(total_in + total_out), 0)
                FROM daily_aggregates
                WHERE date >= ? AND date <= ?
                """, arguments: [previousWindow.start, previousWindow.end]) ?? 0

            return RawUsageSnapshot(
                topRows: rawRows,
                previousCycleTotalBytes: previousTotal
            )
        }

        cancellable = observation.start(
            in: dbPool,
            scheduling: .immediate,
            onError: { error in
                Log.store.error("[store] observation error: \(String(describing: error), privacy: .public)")
            },
            onChange: { [unowned self] snapshot in
                self.handle(snapshot: snapshot)
            }
        )
    }

    /// Observe changes to `preferences.cycleStartDay` and restart the DB
    /// observation whenever it changes. Uses `withObservationTracking` in a loop.
    private func observeCycleStartDayChanges() {
        cycleObservationTask?.cancel()
        cycleObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    _ = withObservationTracking {
                        self.preferences.cycleStartDay
                    } onChange: {
                        continuation.resume()
                    }
                }
                
                if !Task.isCancelled {
                    Log.store.info("[store] cycleStartDay changed — restarting observation")
                    self.startObservation()
                }
            }
        }
    }

    private func handle(snapshot: RawUsageSnapshot) {
        let rawRows = snapshot.topRows
        var sumIn: Int64 = 0
        var sumOut: Int64 = 0
        for raw in rawRows {
            sumIn += raw.bytesIn
            sumOut += raw.bytesOut
        }

        monthToDateBytes = BytePair(bytesIn: sumIn, bytesOut: sumOut)
        previousCycleTotalBytes = snapshot.previousCycleTotalBytes

        if state == .collecting && !rawRows.isEmpty {
            state = .ready
            Log.store.info("[store] ready")
        }

        Log.store.debug("[store] recompute rows=\(rawRows.count, privacy: .public) total_in=\(sumIn, privacy: .public) total_out=\(sumOut, privacy: .public)")

        resolveTask?.cancel()
        let metadataService = self.metadataService
        let categorizer = self.categorizer
        resolveTask = Task { [weak self] in
            // 1. Categorize all raw rows and sum/aggregate their bytes
            var aggregated: [AppOrCategoryEntry: BytePair] = [:]
            for raw in rawRows {
                if Task.isCancelled { return }
                
                let bundleID: String?
                let category: String?
                switch raw.kind {
                case .app(let bid):
                    bundleID = bid
                    category = nil
                case .category(let cat):
                    bundleID = nil
                    category = cat
                }
                
                let entry = await categorizer.categorize(bundleID: bundleID, category: category)
                var current = aggregated[entry] ?? BytePair(bytesIn: 0, bytesOut: 0)
                current.bytesIn += raw.bytesIn
                current.bytesOut += raw.bytesOut
                aggregated[entry] = current
            }
            
            if Task.isCancelled { return }
            
            // 2. Sort by total bytes descending
            let sortedEntries = aggregated.map { (key, value) in
                (entry: key, bytes: value)
            }.sorted { 
                ($0.bytes.bytesIn + $0.bytes.bytesOut) > ($1.bytes.bytesIn + $1.bytes.bytesOut) 
            }
            
            let incomingKeys = sortedEntries.map { pair -> AppUsageEntry.Kind in
                switch pair.entry {
                case .app(let bid): return .app(bundleID: bid)
                case .category(let cat): return .category(name: cat)
                }
            }
            
            if Task.isCancelled { return }
            
            // 3. Resolve metadata and build AppUsageEntry array
            var resolved: [AppUsageEntry] = []
            resolved.reserveCapacity(sortedEntries.count)
            for pair in sortedEntries {
                if Task.isCancelled { return }
                let meta: AppMetadata
                let kind: AppUsageEntry.Kind
                switch pair.entry {
                case .app(let bundleID):
                    meta = await metadataService.metadata(forBundleID: bundleID)
                    kind = .app(bundleID: bundleID)
                case .category(let name):
                    meta = await metadataService.metadata(forCategory: name)
                    kind = .category(name: name)
                }
                if Task.isCancelled { return }
                resolved.append(AppUsageEntry(
                    kind: kind,
                    bytesIn: pair.bytes.bytesIn,
                    bytesOut: pair.bytes.bytesOut,
                    metadata: meta
                ))
            }
            
            guard let self else { return }
            if Task.isCancelled { return }
            self.topEntries = resolved
            self.lastResolvedKeys = incomingKeys
        }
    }

    // MARK: - Date Window Helpers

    /// Convert a `BillingCycle` to a (start, end) string pair for SQL queries.
    /// `start` is the cycle start date; `end` is the day before `cycle.end`
    /// (since `cycle.end` is exclusive).
    private static func dateWindow(from cycle: BillingCycle) -> (start: String, end: String) {
        let cal = Calendar.current
        // cycle.end is exclusive, so the last included day is end - 1 day
        let lastDay = cal.date(byAdding: .day, value: -1, to: cycle.end) ?? cycle.end
        return (dateFormatter.string(from: cycle.start),
                dateFormatter.string(from: lastDay))
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

private struct RawUsageSnapshot: Sendable {
    let topRows: [RawTopRow]
    let previousCycleTotalBytes: Int64
}

private struct RawTopRow: Sendable {
    let kind: AppUsageEntry.Kind
    let bytesIn: Int64
    let bytesOut: Int64
}
