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

    /// Selectable window for the daily-trend series. Drives #029's picker
    /// (`CaseIterable`) and, on change, restarts the viz observation.
    enum TrendWindow: Sendable, Equatable, Hashable, CaseIterable {
        case currentCycle
        case last30Days
    }

    private(set) var state: State = .collecting
    /// TICKET-033: gates the `.collecting → .ready` promotion. While false (set by
    /// `AppState` when the production NE content filter is not confirmed healthy),
    /// historical `daily_aggregates` must not make the UI look live. Defaults true
    /// so the nettop/dev paths and direct test construction are unaffected.
    private(set) var collectionHealthy: Bool
    /// Chinese, technical-id-free recovery copy shown in the non-live placeholder
    /// when collection is unavailable; nil when healthy.
    private(set) var collectionUnavailableReason: String? = nil
    private(set) var monthToDateBytes: BytePair = .zero
    /// Live "today" total read directly from `flow_samples` (not the 5-minute
    /// `daily_aggregates` roll-up), so it climbs in near-real-time. Never sum
    /// this with `monthToDateBytes` — aggregates are derived from samples, so
    /// adding them double-counts.
    private(set) var todayBytes: BytePair = .zero
    /// Freshness signal: `MAX(flow_samples.timestamp)` among today's samples.
    /// `nil` when no samples have landed today (fresh install or no traffic yet).
    private(set) var lastSampleTimestamp: Int64? = nil
    /// Total over the last 7 days (`today-6d … today`), summed from
    /// `daily_aggregates`. "month" is not duplicated here — use `monthToDateBytes`.
    private(set) var weekBytes: BytePair = .zero
    /// Per-day series for the trend chart, zero-filled across `trendWindow` so
    /// bars are continuous. Today's entry is the live `todayBytes` (see
    /// `buildTrend`), so it matches the TodayCard rather than the lagging roll-up.
    private(set) var dailyTrend: [DailyUsage] = []
    /// Window backing `dailyTrend`. Settable by #029's picker; changing it
    /// restarts the viz observation via `observeTrendWindowChanges()`.
    var trendWindow: TrendWindow = .currentCycle
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
    @ObservationIgnored private var vizCancellable: AnyDatabaseCancellable?
    @ObservationIgnored private var resolveTask: Task<Void, Never>?
    @ObservationIgnored private var lastResolvedKeys: [AppUsageEntry.Kind] = []
    /// TICKET-033: whether the latest top-apps snapshot had any aggregate rows.
    /// Lets `markCollectionHealthy()` promote to `.ready` immediately when data
    /// already exists, instead of waiting for the next DB write.
    @ObservationIgnored private var latestHasRows: Bool = false
    @ObservationIgnored private var cycleObservationTask: Task<Void, Never>?
    @ObservationIgnored private var trendWindowObservationTask: Task<Void, Never>?

    init(
        dbPool: DatabasePool,
        metadataService: AppMetadataService,
        categorizer: ProcessCategorizer,
        preferences: Preferences,
        collectionHealthy: Bool = true
    ) {
        self.dbPool = dbPool
        self.metadataService = metadataService
        self.categorizer = categorizer
        self.preferences = preferences
        self.collectionHealthy = collectionHealthy
        self.networkMonitor = NetworkStatusMonitor { [weak self] connection in
            self?.currentNetwork = connection
        }
        Log.store.info("[store] init")
    }

    deinit {
        networkMonitor?.cancel()
        resolveTask?.cancel()
        cancellable?.cancel()
        vizCancellable?.cancel()
        cycleObservationTask?.cancel()
        trendWindowObservationTask?.cancel()
    }

    func start() {
        networkMonitor?.start()
        startObservation()
        startVizObservation()
        observeCycleStartDayChanges()
        observeTrendWindowChanges()
    }

    func topApps(limit: Int) -> [AppUsageEntry] {
        Array(topEntries.prefix(limit))
    }

    // MARK: - Collection Health (TICKET-033)

    /// Pure readiness rule: only promote `.collecting → .ready` when there is data
    /// AND collection is confirmed healthy. Gating on `collectionHealthy` is what
    /// stops historical `daily_aggregates` from rendering as live when the NE
    /// content filter is down (the #032 bug). `nonisolated static` so it is
    /// unit-testable without constructing the `@MainActor` store.
    nonisolated static func shouldBecomeReady(
        currentState: State,
        hasRows: Bool,
        collectionHealthy: Bool
    ) -> Bool {
        currentState == .collecting && hasRows && collectionHealthy
    }

    /// Called by `AppState` when the production content filter is not confirmed
    /// healthy. Keeps the UI in a non-live state and supplies the Chinese recovery
    /// copy. If we had already promoted to `.ready` on stale data with no live
    /// samples today, demote back so we never present stale data as live (AC5).
    func markCollectionUnavailable(_ reason: String) {
        collectionHealthy = false
        collectionUnavailableReason = reason
        if state == .ready, lastSampleTimestamp == nil {
            state = .collecting
        }
        Log.store.info("[store] collection unavailable")
    }

    /// Called by `AppState` once the content filter is confirmed healthy. Clears
    /// the non-live reason and promotes to `.ready` if data already exists.
    func markCollectionHealthy() {
        collectionHealthy = true
        collectionUnavailableReason = nil
        if Self.shouldBecomeReady(currentState: state, hasRows: latestHasRows, collectionHealthy: true) {
            state = .ready
            Log.store.info("[store] ready")
        }
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

    // MARK: - Viz Observation (live "today" + week + daily trend)

    /// Starts an observation that surfaces all visualization state in one
    /// coherent snapshot: the near-live "today" total + freshness from
    /// `flow_samples`, plus the week total and per-day trend from
    /// `daily_aggregates`. GRDB tracks every table the closure reads, so a write
    /// to *either* table republishes all three together.
    ///
    /// This is deliberately kept separate from `startObservation()`'s top-apps
    /// query, and the two data sources are never merged — `daily_aggregates`
    /// derives from `flow_samples`, so summing them would double-count. For the
    /// same reason `buildTrend` *substitutes* today's bar with the live
    /// `todayBytes` (it never adds it), keeping the chart consistent with the
    /// TodayCard while `daily_aggregates` for today still lags up to 5 minutes.
    ///
    /// The today bound is recomputed inside the tracking closure on every change,
    /// so it rolls over at local midnight without a timer. The week/trend bounds
    /// depend on `@MainActor` state (`trendWindow` + `preferences.cycleStartDay`),
    /// so they're captured here; a window change restarts the observation via the
    /// `observe…Changes()` loops, mirroring `startObservation()`.
    private func startVizObservation() {
        vizCancellable?.cancel()
        vizCancellable = nil

        let weekBounds = Self.weekWindowBounds()
        let trend = Self.trendBounds(window: trendWindow, cycleStartDay: preferences.cycleStartDay)
        let trendStart = Self.dateString(trend.start)
        let trendEnd = Self.dateString(trend.end)

        let observation = ValueObservation.tracking { db -> VizSnapshot in
            let today = try Self.fetchTodaySnapshot(db, startOfToday: Self.startOfTodayTimestamp())
            let week = try Self.fetchRangeTotal(db, start: weekBounds.start, end: weekBounds.end)
            let trendRows = try Self.fetchDailyTrend(db, start: trendStart, end: trendEnd)
            return VizSnapshot(today: today, week: week, trendRows: trendRows)
        }

        vizCancellable = observation.start(
            in: dbPool,
            scheduling: .immediate,
            onError: { error in
                Log.store.error("[store] viz observation error: \(String(describing: error), privacy: .public)")
            },
            onChange: { [unowned self] snapshot in
                let todayPair = BytePair(bytesIn: snapshot.today.bytesIn, bytesOut: snapshot.today.bytesOut)
                self.todayBytes = todayPair
                self.lastSampleTimestamp = snapshot.today.lastSampleTimestamp
                self.weekBytes = snapshot.week
                self.dailyTrend = Self.buildTrend(
                    rows: snapshot.trendRows,
                    start: trend.start,
                    end: trend.end,
                    todayBytes: todayPair
                )
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
                    withObservationTracking {
                        _ = self.preferences.cycleStartDay
                    } onChange: {
                        continuation.resume()
                    }
                }
                
                if !Task.isCancelled {
                    Log.store.info("[store] cycleStartDay changed — restarting observations")
                    self.startObservation()
                    // `.currentCycle` trend bounds depend on cycleStartDay; harmless
                    // to restart when `.last30Days` (recomputes the same bounds).
                    self.startVizObservation()
                }
            }
        }
    }

    /// Observe changes to `trendWindow` and restart the viz observation whenever
    /// it changes, so `dailyTrend` re-windows. Mirrors `observeCycleStartDayChanges()`.
    private func observeTrendWindowChanges() {
        trendWindowObservationTask?.cancel()
        trendWindowObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = self.trendWindow
                    } onChange: {
                        continuation.resume()
                    }
                }

                if !Task.isCancelled {
                    Log.store.info("[store] trendWindow changed — restarting viz observation")
                    self.startVizObservation()
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

        latestHasRows = !rawRows.isEmpty
        if Self.shouldBecomeReady(currentState: state, hasRows: latestHasRows, collectionHealthy: collectionHealthy) {
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

    // MARK: - Today Query (nonisolated, testable)

    /// Unix-epoch seconds for the start of today in the current calendar/timezone.
    /// Matches the Aggregator's `unixepoch,'localtime'` convention (no UTC).
    /// `nonisolated` so it can be called from the off-main observation closure.
    nonisolated static func startOfTodayTimestamp(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int64 {
        Int64(calendar.startOfDay(for: now).timeIntervalSince1970)
    }

    /// Sums today's `flow_samples` bytes and finds the freshest sample timestamp.
    ///
    /// `SUM`/`MAX` over an empty filtered set return a single all-`NULL` row:
    /// the sums coalesce to `0`, and `MAX(timestamp)` reads back as `nil` — so a
    /// fresh install (or no traffic yet today) yields `(0, 0, nil)`, never `0`.
    ///
    /// Factored out of the store as a `nonisolated static` so tests can call it
    /// via `dbPool.read { … }` without constructing the `@MainActor` store.
    nonisolated static func fetchTodaySnapshot(
        _ db: Database,
        startOfToday: Int64
    ) throws -> TodaySnapshot {
        let row = try Row.fetchOne(db, sql: """
            SELECT SUM(bytes_in)  AS in_,
                   SUM(bytes_out) AS out_,
                   MAX(timestamp) AS last_ts
            FROM flow_samples
            WHERE timestamp >= ?
            """, arguments: [startOfToday])
        return TodaySnapshot(
            bytesIn: row?["in_"] ?? 0,
            bytesOut: row?["out_"] ?? 0,
            lastSampleTimestamp: row?["last_ts"]
        )
    }

    // MARK: - Week & Trend Queries (nonisolated, testable)

    /// Sums `daily_aggregates` over the inclusive `[start, end]` date range.
    /// Backs `weekBytes`. `COALESCE(…, 0)` makes an empty range read back as zero.
    nonisolated static func fetchRangeTotal(
        _ db: Database,
        start: String,
        end: String
    ) throws -> BytePair {
        let row = try Row.fetchOne(db, sql: """
            SELECT COALESCE(SUM(total_in), 0)  AS in_,
                   COALESCE(SUM(total_out), 0) AS out_
            FROM daily_aggregates
            WHERE date >= ? AND date <= ?
            """, arguments: [start, end])
        let bytesIn: Int64 = row?["in_"] ?? 0
        let bytesOut: Int64 = row?["out_"] ?? 0
        return BytePair(bytesIn: bytesIn, bytesOut: bytesOut)
    }

    /// Per-day totals from `daily_aggregates` over `[start, end]`, one row per
    /// day that has data, ascending. Missing days are zero-filled later in
    /// `buildTrend`; this stays a pure query for straightforward testing.
    nonisolated static func fetchDailyTrend(
        _ db: Database,
        start: String,
        end: String
    ) throws -> [DailyTrendRow] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT date AS d,
                   SUM(total_in)  AS in_,
                   SUM(total_out) AS out_
            FROM daily_aggregates
            WHERE date >= ? AND date <= ?
            GROUP BY date
            ORDER BY date ASC
            """, arguments: [start, end])
        return rows.map { row in
            DailyTrendRow(
                date: row["d"],
                bytesIn: row["in_"] ?? 0,
                bytesOut: row["out_"] ?? 0
            )
        }
    }

    /// Build the chart-ready trend: zero-fill every day in `[start, end]` so bars
    /// are continuous, then **substitute** today's entry with the live `todayBytes`
    /// (replace, never add — `daily_aggregates` derives from `flow_samples`).
    /// `nonisolated` + injectable `now`/`calendar` for deterministic tests.
    nonisolated static func buildTrend(
        rows: [DailyTrendRow],
        start: Date,
        end: Date,
        todayBytes: BytePair,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyUsage] {
        let formatter = makeDateFormatter()
        var byDate: [String: DailyTrendRow] = [:]
        for row in rows { byDate[row.date] = row }
        let todayKey = formatter.string(from: calendar.startOfDay(for: now))

        var result: [DailyUsage] = []
        var day = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: end)
        while day <= lastDay {
            let key = formatter.string(from: day)
            if key == todayKey {
                result.append(DailyUsage(date: day, bytesIn: todayBytes.bytesIn, bytesOut: todayBytes.bytesOut))
            } else if let row = byDate[key] {
                result.append(DailyUsage(date: day, bytesIn: row.bytesIn, bytesOut: row.bytesOut))
            } else {
                result.append(DailyUsage(date: day, bytesIn: 0, bytesOut: 0))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
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

    /// SQL bounds for the "this week" total: the 7 days `today-6d … today`,
    /// inclusive, as `yyyy-MM-dd` strings. `nonisolated` for direct test access.
    nonisolated static func weekWindowBounds(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (start: String, end: String) {
        let formatter = makeDateFormatter()
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        return (formatter.string(from: start), formatter.string(from: today))
    }

    /// Inclusive `Date` bounds for the daily-trend series, by window.
    /// `.currentCycle` matches `dateWindow(from:)`'s convention (whole cycle,
    /// `cycle.end` exclusive → last day is `end - 1`); `.last30Days` is
    /// `today-29d … today`. `nonisolated` for direct test access.
    nonisolated static func trendBounds(
        window: TrendWindow,
        cycleStartDay: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        switch window {
        case .currentCycle:
            let cycle = BillingCycle.current(forStartDay: cycleStartDay, on: now, calendar: calendar)
            let lastDay = calendar.date(byAdding: .day, value: -1, to: cycle.end) ?? cycle.end
            return (calendar.startOfDay(for: cycle.start), calendar.startOfDay(for: lastDay))
        case .last30Days:
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return (start, today)
        }
    }

    /// Format a `Date` as a `yyyy-MM-dd` string matching the `daily_aggregates.date`
    /// column. `nonisolated` so it's usable from the off-main observation closure.
    nonisolated static func dateString(_ date: Date) -> String {
        makeDateFormatter().string(from: date)
    }

    /// Factory for the shared `yyyy-MM-dd` formatter config. Used both by the
    /// cached `dateFormatter` (main-actor reads) and by `nonisolated` helpers,
    /// which create their own instance to stay race-free off the main actor.
    nonisolated static func makeDateFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }

    private static let dateFormatter: DateFormatter = makeDateFormatter()
}

/// Result of `UsageStore.fetchTodaySnapshot`. Internal (not `private`) so
/// `UsageStoreQueryTests` can read its fields via `@testable import`.
struct TodaySnapshot: Sendable, Equatable {
    var bytesIn: Int64
    var bytesOut: Int64
    var lastSampleTimestamp: Int64?
}

/// One day's totals from `daily_aggregates`, before zero-fill/substitution.
/// Internal (not `private`) so `UsageStoreQueryTests` can read its fields.
struct DailyTrendRow: Sendable, Equatable {
    let date: String   // `yyyy-MM-dd`
    let bytesIn: Int64
    let bytesOut: Int64
}

/// One coherent snapshot of all viz state, republished together by the viz
/// observation in `startVizObservation()`.
private struct VizSnapshot: Sendable {
    let today: TodaySnapshot
    let week: UsageStore.BytePair
    let trendRows: [DailyTrendRow]
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
