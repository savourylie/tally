import Foundation
import GRDB
import Observation
import AppKit
import os

private let sampleIntervalSeconds: Int = 10
private let flushIntervalSeconds: TimeInterval = 60
private let maxRestartAttempts: Int = 5
private let initialBackoffSeconds: Double = 1.0
private let maxBackoffSeconds: Double = 30.0
private let maxBufferedSamples: Int = 5_000

@MainActor
@Observable
final class NettopCollector: FlowCollector {
    private(set) var state: CollectorState = .idle

    private let dbPool: DatabasePool
    private let nettopPath: String

    @ObservationIgnored
    private let childPID = OSAllocatedUnfairLock<pid_t>(initialState: 0)

    private var ioTask: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    init(dbPool: DatabasePool, nettopPath: String = "/usr/bin/nettop") {
        self.dbPool = dbPool
        self.nettopPath = nettopPath
    }

    func start() {
        guard ioTask == nil else { return }
        state = .running
        Log.collector.info("[collector] start")

        let dbPool = self.dbPool
        let nettopPath = self.nettopPath
        let childPID = self.childPID
        let reportRunning: @Sendable () async -> Void = { [weak self] in
            await self?.markRunning()
        }
        let reportFailed: @Sendable (String) async -> Void = { [weak self] reason in
            await self?.markFailed(reason)
        }

        ioTask = Task.detached(priority: .utility) {
            await runNettopIOLoop(
                dbPool: dbPool,
                nettopPath: nettopPath,
                childPID: childPID,
                reportRunning: reportRunning,
                reportFailed: reportFailed
            )
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
        guard let task = ioTask else { return }
        Log.collector.info("[collector] stop")
        task.cancel()
        // Synchronously signal the child so its process group dies before our task gets the chance to
        // observe cancellation (which can be blocked up to ~10s on the next snapshot read).
        let pid = childPID.withLock { current in
            let value = current
            current = 0
            return value
        }
        if pid > 0 { kill(pid, SIGTERM) }
        ioTask = nil
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
            terminationObserver = nil
        }
        state = .idle
    }

    private func markRunning() { state = .running }

    private func markFailed(_ reason: String) {
        Log.collector.error("[collector] failed reason=\(reason, privacy: .public)")
        state = .failed(reason)
    }
}

private struct PendingFlowSample {
    let timestamp: Date
    let bundleID: String?
    let executableName: String
    let bytesIn: Int64
    let bytesOut: Int64

    func asRecord() -> FlowSample {
        FlowSample(
            id: nil,
            timestamp: Int64(timestamp.timeIntervalSince1970),
            bundleId: bundleID,
            executableName: executableName,
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            networkId: nil
        )
    }
}

private func runNettopIOLoop(
    dbPool: DatabasePool,
    nettopPath: String,
    childPID: OSAllocatedUnfairLock<pid_t>,
    reportRunning: @Sendable () async -> Void,
    reportFailed: @Sendable (String) async -> Void
) async {
    let parser = NettopParser()
    var buffer: [PendingFlowSample] = []
    var attempt = 0
    var nextFlushAt = Date().addingTimeInterval(flushIntervalSeconds)

    while !Task.isCancelled {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: nettopPath)
        process.arguments = [
            "-P", "-x",
            "-J", "bytes_in,bytes_out",
            "-l", "0",
            "-s", String(sampleIntervalSeconds),
        ]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            childPID.withLock { $0 = process.processIdentifier }
            Log.collector.info("[collector] nettop launched pid=\(process.processIdentifier, privacy: .public)")
        } catch {
            attempt += 1
            Log.collector.error("[collector] launch failed attempt=\(attempt, privacy: .public) error=\(String(describing: error), privacy: .public)")
            if attempt >= maxRestartAttempts {
                await reportFailed("nettop launch failed \(attempt) times: \(error.localizedDescription)")
                return
            }
            try? await Task.sleep(nanoseconds: backoffNanos(attempt: attempt))
            continue
        }

        parser.resetBaselines()
        var producedAny = false
        let handle = pipe.fileHandleForReading

        do {
            for try await rawLine in handle.bytes.lines {
                if Task.isCancelled { break }
                let now = Date()
                if let sample = parser.ingest(line: Substring(rawLine), wallClock: now) {
                    producedAny = true
                    let bundleId = NSRunningApplication(processIdentifier: sample.pid)?.bundleIdentifier
                    buffer.append(PendingFlowSample(
                        timestamp: sample.observedAt,
                        bundleID: bundleId,
                        executableName: sample.processName,
                        bytesIn: sample.bytesInDelta,
                        bytesOut: sample.bytesOutDelta
                    ))
                    if buffer.count >= maxBufferedSamples {
                        await flushBuffer(&buffer, dbPool: dbPool)
                        nextFlushAt = Date().addingTimeInterval(flushIntervalSeconds)
                    }
                }
                if now >= nextFlushAt {
                    await flushBuffer(&buffer, dbPool: dbPool)
                    nextFlushAt = Date().addingTimeInterval(flushIntervalSeconds)
                }
            }
        } catch is CancellationError {
            // Expected on stop()
        } catch {
            Log.collector.error("[collector] read error: \(String(describing: error), privacy: .public)")
        }

        if process.isRunning { process.terminate() }
        try? handle.close()
        childPID.withLock { $0 = 0 }

        if Task.isCancelled {
            await flushBuffer(&buffer, dbPool: dbPool)
            return
        }

        if producedAny {
            attempt = 0
            Log.collector.warning("[collector] nettop exited after producing samples; restarting")
            await reportRunning()
        } else {
            attempt += 1
            Log.collector.warning("[collector] nettop exited without samples; consecutive_failures=\(attempt, privacy: .public)/\(maxRestartAttempts, privacy: .public)")
            if attempt >= maxRestartAttempts {
                await flushBuffer(&buffer, dbPool: dbPool)
                await reportFailed("nettop exited \(attempt) times without producing samples")
                return
            }
        }
        try? await Task.sleep(nanoseconds: backoffNanos(attempt: max(attempt, 1)))
    }

    await flushBuffer(&buffer, dbPool: dbPool)
}

private func backoffNanos(attempt: Int) -> UInt64 {
    let exponent = max(0, attempt - 1)
    let secs = min(maxBackoffSeconds, initialBackoffSeconds * pow(2.0, Double(exponent)))
    return UInt64(secs * 1_000_000_000)
}

private func flushBuffer(_ buffer: inout [PendingFlowSample], dbPool: DatabasePool) async {
    guard !buffer.isEmpty else { return }
    let toWrite = buffer
    buffer.removeAll(keepingCapacity: true)
    // Run the write in a detached task so cancellation of the IO loop (during shutdown)
    // doesn't propagate into GRDB and drop the final batch.
    let outcome = await Task.detached(priority: .utility) { () -> Result<Void, Error> in
        do {
            try await dbPool.write { db in
                for sample in toWrite {
                    try sample.asRecord().insert(db)
                }
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }.value

    switch outcome {
    case .success:
        Log.collector.info("[collector] flushed rows=\(toWrite.count, privacy: .public)")
    case .failure(let error):
        Log.collector.error("[collector] flush failed rows=\(toWrite.count, privacy: .public) error=\(String(describing: error), privacy: .public)")
    }
}
