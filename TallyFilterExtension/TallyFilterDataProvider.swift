import Foundation
import NetworkExtension
import os

final class TallyFilterDataProvider: NEFilterDataProvider {
    private let logger = Logger(subsystem: "app.tally", category: "filter-extension")
    private var writer: FlowEventWriter?
    private var flowTotalsByIdentifier: [UUID: FlowByteTotals] = [:]

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        do {
            writer = try FlowEventWriter()
            logger.info("[filter] started")
            completionHandler(nil)
        } catch {
            logger.error("[filter] start failed error=\(String(describing: error), privacy: .public)")
            completionHandler(error)
        }
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        logger.info("[filter] stopped reason=\(reason.rawValue, privacy: .public)")
        writer = nil
        flowTotalsByIdentifier.removeAll()
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let verdict = NEFilterNewFlowVerdict.allow()
        verdict.shouldReport = true
        verdict.statisticsReportFrequency = .low
        return verdict
    }

    override func handleInboundData(
        from flow: NEFilterFlow,
        readBytesStartOffset offset: Int,
        readBytes: Data
    ) -> NEFilterDataVerdict {
        writer?.record(flow: flow, bytesIn: Int64(readBytes.count), bytesOut: 0)
        return NEFilterDataVerdict(passBytes: readBytes.count, peekBytes: 1)
    }

    override func handleOutboundData(
        from flow: NEFilterFlow,
        readBytesStartOffset offset: Int,
        readBytes: Data
    ) -> NEFilterDataVerdict {
        writer?.record(flow: flow, bytesIn: 0, bytesOut: Int64(readBytes.count))
        return NEFilterDataVerdict(passBytes: readBytes.count, peekBytes: 1)
    }

    override func handle(_ report: NEFilterReport) {
        guard let flow = report.flow else { return }

        let current = FlowByteTotals(
            bytesIn: Int64(clamping: report.bytesInboundCount),
            bytesOut: Int64(clamping: report.bytesOutboundCount)
        )
        let previous = flowTotalsByIdentifier[flow.identifier] ?? .zero
        writer?.record(
            flow: flow,
            bytesIn: max(0, current.bytesIn - previous.bytesIn),
            bytesOut: max(0, current.bytesOut - previous.bytesOut)
        )

        if report.event == .flowClosed {
            flowTotalsByIdentifier[flow.identifier] = nil
        } else {
            flowTotalsByIdentifier[flow.identifier] = current
        }
    }
}

private struct FlowByteTotals {
    static let zero = FlowByteTotals(bytesIn: 0, bytesOut: 0)

    let bytesIn: Int64
    let bytesOut: Int64
}
