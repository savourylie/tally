import Foundation
import GRDB
import AppKit
import os

private let cycleIntervalSeconds: TimeInterval = 300       // 5 minutes
private let affectedWindowSeconds: TimeInterval = 86_400   // 24 hours
private let retentionSeconds: TimeInterval = 7 * 86_400    // 7 days

actor Aggregator {
    private let dbPool: DatabasePool
    private let helperResolver: HelperProcessResolver
    private var ioTask: Task<Void, Never>?
    private var categoryMap: [String: String]?
    private var terminationObserver: NSObjectProtocol?

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
        self.helperResolver = HelperProcessResolver()
    }

    func start() {
        guard ioTask == nil else { return }
        Log.agg.info("[agg] start")

        ioTask = Task.detached(priority: .utility) { [weak self] in
            // First cycle runs immediately to satisfy the "first aggregation within
            // 10s of collector startup" AC.
            await self?.runCycle()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(cycleIntervalSeconds))
                if Task.isCancelled { break }
                await self?.runCycle()
            }
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.stop() }
        }
    }

    func stop() {
        guard let task = ioTask else { return }
        Log.agg.info("[agg] stop")
        task.cancel()
        ioTask = nil
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
            terminationObserver = nil
        }
    }

    func runOnce() async {
        await runCycle()
    }

    private func runCycle() async {
        let startTime = Date()

        if categoryMap == nil {
            await loadCategoryMap()
        }
        let categories = categoryMap ?? [:]

        let preAggs: [PreAgg]
        do {
            preAggs = try await readPreAggregates()
        } catch {
            Log.agg.error("[agg] pre-agg read failed error=\(String(describing: error), privacy: .public)")
            return
        }

        let (buckets, affectedDates) = await rollUp(preAggs: preAggs, categories: categories)

        if !affectedDates.isEmpty {
            do {
                try await writeAggregates(buckets: buckets, affectedDates: affectedDates)
            } catch {
                Log.agg.error("[agg] aggregation write failed error=\(String(describing: error), privacy: .public)")
                return
            }
        }

        var deletedCount = 0
        do {
            deletedCount = try await runRetention()
        } catch {
            Log.agg.error("[agg] retention delete failed error=\(String(describing: error), privacy: .public)")
        }

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        Log.agg.info(
            "[agg] cycle done dates=\(affectedDates.count, privacy: .public) rows_in=\(preAggs.count, privacy: .public) rows_out=\(buckets.count, privacy: .public) duration_ms=\(durationMs, privacy: .public) retention_deleted=\(deletedCount, privacy: .public)"
        )
    }

    private func loadCategoryMap() async {
        do {
            let map: [String: String] = try await dbPool.read { db in
                var result: [String: String] = [:]
                let cursor = try Row.fetchCursor(
                    db,
                    sql: "SELECT process_identifier, category_name FROM process_categories"
                )
                while let row = try cursor.next() {
                    let pid: String = row["process_identifier"]
                    let cat: String = row["category_name"]
                    result[pid] = cat
                }
                return result
            }
            categoryMap = map
            Log.agg.info("[agg] category map loaded entries=\(map.count, privacy: .public)")
        } catch {
            Log.agg.error("[agg] category map load failed error=\(String(describing: error), privacy: .public)")
            categoryMap = [:]
        }
    }

    private func readPreAggregates() async throws -> [PreAgg] {
        let cutoff = Int64(Date().timeIntervalSince1970 - affectedWindowSeconds)
        return try await dbPool.read { db in
            var rows: [PreAgg] = []
            let cursor = try Row.fetchCursor(db, sql: """
                SELECT date(timestamp, 'unixepoch', 'localtime') AS d,
                       bundle_id,
                       executable_name,
                       network_id,
                       SUM(bytes_in)  AS total_in,
                       SUM(bytes_out) AS total_out
                FROM flow_samples
                WHERE timestamp >= ?
                GROUP BY d, bundle_id, executable_name, network_id
                """, arguments: [cutoff])
            while let row = try cursor.next() {
                let date: String = row["d"]
                let executableName: String = row["executable_name"]
                let bundleId: String? = row["bundle_id"]
                let networkId: Int64? = row["network_id"]
                let totalIn: Int64 = row["total_in"]
                let totalOut: Int64 = row["total_out"]
                rows.append(PreAgg(
                    date: date,
                    bundleId: bundleId,
                    executableName: executableName,
                    networkId: networkId,
                    totalIn: totalIn,
                    totalOut: totalOut
                ))
            }
            return rows
        }
    }

    private func rollUp(
        preAggs: [PreAgg],
        categories: [String: String]
    ) async -> (buckets: [AggKey: AggTotals], affectedDates: [String]) {
        var buckets: [AggKey: AggTotals] = [:]
        for row in preAggs {
            var attributedBundleId = row.bundleId
            if let bundleId = row.bundleId,
               let parent = await helperResolver.parentBundle(forHelper: bundleId) {
                attributedBundleId = parent
            }

            // Fallback: if bundleId is nil but executableName is Google Chrome or its helper, attribute to Google Chrome
            if attributedBundleId == nil {
                if row.executableName == "Google Chrome" || row.executableName == "Google Chrome Helper" {
                    attributedBundleId = "com.google.Chrome"
                }
            }

            var category: String? = nil
            if attributedBundleId == nil {
                category = categories[row.executableName] ?? "系統其他"
            }

            let key = AggKey(
                date: row.date,
                bundleId: attributedBundleId,
                category: category,
                networkId: row.networkId
            )
            var totals = buckets[key] ?? AggTotals(totalIn: 0, totalOut: 0)
            totals.totalIn += row.totalIn
            totals.totalOut += row.totalOut
            buckets[key] = totals
        }
        let affectedDates = Array(Set(buckets.keys.map(\.date))).sorted()
        return (buckets, affectedDates)
    }

    private func writeAggregates(
        buckets: [AggKey: AggTotals],
        affectedDates: [String]
    ) async throws {
        try await dbPool.write { db in
            let placeholders = affectedDates.map { _ in "?" }.joined(separator: ",")
            try db.execute(
                sql: "DELETE FROM daily_aggregates WHERE date IN (\(placeholders))",
                arguments: StatementArguments(affectedDates)
            )
            for (key, totals) in buckets {
                try db.execute(sql: """
                    INSERT INTO daily_aggregates
                      (date, bundle_id, category, network_id, total_in, total_out)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        key.date,
                        key.bundleId,
                        key.category,
                        key.networkId,
                        totals.totalIn,
                        totals.totalOut,
                    ])
            }
        }
    }

    private func runRetention() async throws -> Int {
        let cutoff = Int64(Date().timeIntervalSince1970 - retentionSeconds)
        return try await dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM flow_samples WHERE timestamp < ?",
                arguments: [cutoff]
            )
            return db.changesCount
        }
    }
}

private struct PreAgg: Sendable {
    let date: String
    let bundleId: String?
    let executableName: String
    let networkId: Int64?
    let totalIn: Int64
    let totalOut: Int64
}

private struct AggKey: Hashable, Sendable {
    let date: String
    let bundleId: String?
    let category: String?
    let networkId: Int64?
}

private struct AggTotals: Sendable {
    var totalIn: Int64
    var totalOut: Int64
}
