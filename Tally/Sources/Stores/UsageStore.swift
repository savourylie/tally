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
    var currentNetworkDisplay: String {
        currentNetwork.displayName
    }
    // TODO TICKET-019: replace this placeholder with persisted user preferences.
    var monthlyCapBytes: Int64? = 20 * 1024 * 1024 * 1024


    @ObservationIgnored private let dbPool: DatabasePool
    @ObservationIgnored private let metadataService: AppMetadataService
    @ObservationIgnored private var networkMonitor: NetworkStatusMonitor?
    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?
    @ObservationIgnored private var resolveTask: Task<Void, Never>?
    @ObservationIgnored private var lastResolvedKeys: [AppUsageEntry.Kind] = []

    init(dbPool: DatabasePool, metadataService: AppMetadataService) {
        self.dbPool = dbPool
        self.metadataService = metadataService
        self.networkMonitor = NetworkStatusMonitor { [weak self] connection in
            self?.currentNetwork = connection
        }
        Log.store.info("[store] init")
    }

    deinit {
        networkMonitor?.cancel()
        resolveTask?.cancel()
        cancellable?.cancel()
    }

    func start() {
        networkMonitor?.start()
        guard cancellable == nil else { return }
        let window = Self.currentCycleWindow()
        let previousWindow = Self.previousCalendarMonthWindow()
        // TODO TICKET-019: refresh observation on NSCalendarDayChanged so the
        // cycle window advances at midnight without an app restart.
        Log.store.info("[store] start window=\(window.start, privacy: .public)..\(window.end, privacy: .public)")

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

    func topApps(limit: Int) -> [AppUsageEntry] {
        Array(topEntries.prefix(limit))
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

        let incomingKeys = rawRows.map(\.kind)
        if incomingKeys == lastResolvedKeys {
            patchExistingEntries(with: rawRows)
            return
        }

        resolveTask?.cancel()
        let metadataService = self.metadataService
        let pendingKeys = incomingKeys
        resolveTask = Task { [weak self] in
            var resolved: [AppUsageEntry] = []
            resolved.reserveCapacity(rawRows.count)
            for raw in rawRows {
                if Task.isCancelled { return }
                let meta: AppMetadata
                switch raw.kind {
                case .app(let bundleID):
                    meta = await metadataService.metadata(forBundleID: bundleID)
                case .category(let name):
                    meta = await metadataService.metadata(forCategory: name)
                }
                if Task.isCancelled { return }
                resolved.append(AppUsageEntry(
                    kind: raw.kind,
                    bytesIn: raw.bytesIn,
                    bytesOut: raw.bytesOut,
                    metadata: meta
                ))
            }
            guard let self else { return }
            if Task.isCancelled { return }
            self.topEntries = resolved
            self.lastResolvedKeys = pendingKeys
        }
    }

    private func patchExistingEntries(with rawRows: [RawTopRow]) {
        guard rawRows.count == topEntries.count else { return }
        var patched: [AppUsageEntry] = []
        patched.reserveCapacity(rawRows.count)
        for (i, raw) in rawRows.enumerated() {
            let existing = topEntries[i]
            patched.append(AppUsageEntry(
                kind: raw.kind,
                bytesIn: raw.bytesIn,
                bytesOut: raw.bytesOut,
                metadata: existing.metadata
            ))
        }
        topEntries = patched
    }

    // MARK: - Cycle window placeholder (TICKET-019 replaces this)

    private static func currentCycleWindow(now: Date = .now) -> (start: String, end: String) {
        let cal = Calendar.current
        let startDate = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return (dateFormatter.string(from: startDate),
                dateFormatter.string(from: now))
    }

    private static func previousCalendarMonthWindow(now: Date = .now) -> (start: String, end: String) {
        let cal = Calendar.current
        let currentStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let previousStart = cal.date(byAdding: .month, value: -1, to: currentStart) ?? currentStart
        let previousEnd = cal.date(byAdding: .day, value: -1, to: currentStart) ?? previousStart
        return (dateFormatter.string(from: previousStart),
                dateFormatter.string(from: previousEnd))
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
