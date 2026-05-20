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
    // TODO TICKET-019: real network detection. For now this is a fixed placeholder.
    private(set) var currentNetworkDisplay: String = "Wi-Fi"

    @ObservationIgnored private let dbPool: DatabasePool
    @ObservationIgnored private let metadataService: AppMetadataService
    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?
    @ObservationIgnored private var resolveTask: Task<Void, Never>?
    @ObservationIgnored private var lastResolvedKeys: [AppUsageEntry.Kind] = []

    init(dbPool: DatabasePool, metadataService: AppMetadataService) {
        self.dbPool = dbPool
        self.metadataService = metadataService
        Log.store.info("[store] init")
    }

    deinit {
        resolveTask?.cancel()
        cancellable?.cancel()
    }

    func start() {
        guard cancellable == nil else { return }
        let window = Self.currentCycleWindow()
        // TODO TICKET-019: refresh observation on NSCalendarDayChanged so the
        // cycle window advances at midnight without an app restart.
        Log.store.info("[store] start window=\(window.start, privacy: .public)..\(window.end, privacy: .public)")

        let observation = ValueObservation.tracking { db -> [RawTopRow] in
            let rows = try Row.fetchAll(db, sql: """
                SELECT bundle_id, category,
                       SUM(total_in)  AS in_,
                       SUM(total_out) AS out_
                FROM daily_aggregates
                WHERE date >= ? AND date <= ?
                GROUP BY bundle_id, category
                ORDER BY (in_ + out_) DESC
                """, arguments: [window.start, window.end])
            return rows.compactMap { row in
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
        }

        cancellable = observation.start(
            in: dbPool,
            scheduling: .immediate,
            onError: { error in
                Log.store.error("[store] observation error: \(String(describing: error), privacy: .public)")
            },
            onChange: { [unowned self] rawRows in
                self.handle(rawRows: rawRows)
            }
        )
    }

    func topApps(limit: Int) -> [AppUsageEntry] {
        Array(topEntries.prefix(limit))
    }

    private func handle(rawRows: [RawTopRow]) {
        var sumIn: Int64 = 0
        var sumOut: Int64 = 0
        for raw in rawRows {
            sumIn += raw.bytesIn
            sumOut += raw.bytesOut
        }

        monthToDateBytes = BytePair(bytesIn: sumIn, bytesOut: sumOut)

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

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

private struct RawTopRow: Sendable {
    let kind: AppUsageEntry.Kind
    let bytesIn: Int64
    let bytesOut: Int64
}
