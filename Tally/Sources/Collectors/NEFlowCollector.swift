import Foundation
import GRDB
import Observation
import AppKit

private let defaultNEPollIntervalSeconds: TimeInterval = 5

@MainActor
@Observable
final class NEFlowCollector: FlowCollector {
    private(set) var state: CollectorState = .idle

    @ObservationIgnored private let dbPool: DatabasePool
    @ObservationIgnored private let appGroupURL: URL?
    @ObservationIgnored private let allowDevelopmentFallback: Bool
    @ObservationIgnored private let pollIntervalSeconds: TimeInterval
    @ObservationIgnored private let didFlush: (@Sendable () async -> Void)?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    init(
        dbPool: DatabasePool,
        appGroupURL: URL? = nil,
        allowDevelopmentFallback: Bool = false,
        pollIntervalSeconds: TimeInterval = defaultNEPollIntervalSeconds,
        didFlush: (@Sendable () async -> Void)? = nil
    ) {
        self.dbPool = dbPool
        self.appGroupURL = appGroupURL
        self.allowDevelopmentFallback = allowDevelopmentFallback
        self.pollIntervalSeconds = pollIntervalSeconds
        self.didFlush = didFlush
    }

    func start() {
        guard pollTask == nil else { return }

        let containerURL: URL
        do {
            containerURL = try appGroupURL ?? TallyAppGroup.containerURL(
                allowDevelopmentFallback: allowDevelopmentFallback
            )
        } catch {
            markFailed("目前看不到網路使用情況，請確認 Tally 已在系統設定中獲准。")
            return
        }

        state = .running
        Log.collector.info("[collector] NE start app_group=\(containerURL.path, privacy: .public)")

        let dbPool = self.dbPool
        let didFlush = self.didFlush
        let pollIntervalSeconds = self.pollIntervalSeconds
        let reportRunning: @Sendable () async -> Void = { [weak self] in
            await self?.markRunning()
        }
        let reportFailed: @Sendable (String) async -> Void = { [weak self] reason in
            await self?.markFailed(reason)
        }

        pollTask = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                do {
                    let inserted = try await Self.drainAndInsertEvents(
                        dbPool: dbPool,
                        containerURL: containerURL
                    )
                    if inserted > 0 {
                        Log.collector.info("[collector] NE flushed rows=\(inserted, privacy: .public)")
                        await didFlush?()
                    }
                    await reportRunning()
                } catch {
                    Log.collector.error("[collector] NE drain failed error=\(String(describing: error), privacy: .public)")
                    await reportFailed("目前看不到網路使用情況，請到系統設定批准 Tally。")
                }

                let nanos = UInt64(max(0.5, pollIntervalSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }
    }

    func stop() {
        guard let task = pollTask else { return }
        Log.collector.info("[collector] NE stop")
        task.cancel()
        pollTask = nil
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
            terminationObserver = nil
        }
        state = .idle
    }

    /// TICKET-033: called by `AppState` instead of `start()` when the content
    /// filter is confirmed unhealthy, so the collector reports `.failed(reason)`
    /// rather than silently idling on stale data. Tears down any poll task that
    /// somehow started, then leaves the failed state in place (so it is not reset
    /// to `.idle` by `stop()`).
    func markUnavailable(_ reason: String) {
        stop()
        state = .failed(reason)
        Log.collector.error("[collector] NE unavailable reason=\(reason, privacy: .public)")
    }

    @discardableResult
    func consumePendingEventsOnce() async throws -> Int {
        let containerURL = try appGroupURL ?? TallyAppGroup.containerURL(
            allowDevelopmentFallback: allowDevelopmentFallback
        )
        let inserted = try await Self.drainAndInsertEvents(
            dbPool: dbPool,
            containerURL: containerURL
        )
        if inserted > 0 {
            await didFlush?()
        }
        return inserted
    }

    private func markRunning() {
        if state != .running {
            state = .running
        }
    }

    private func markFailed(_ reason: String) {
        state = .failed(reason)
    }

    private static func drainAndInsertEvents(
        dbPool: DatabasePool,
        containerURL: URL
    ) async throws -> Int {
        let events = try FlowEventLog.drain(from: containerURL)
        guard !events.isEmpty else { return 0 }

        try await dbPool.write { db in
            for event in events {
                try event.asFlowSample().insert(db)
            }
        }
        return events.count
    }
}

private extension FlowEvent {
    func asFlowSample() -> FlowSample {
        FlowSample(
            id: nil,
            timestamp: timestamp,
            bundleId: bundleId,
            executableName: executableName,
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            networkId: nil
        )
    }
}
