import Foundation
import NetworkExtension
import os
import Darwin

final class FlowEventWriter {
    private let containerURL: URL
    private let logger = Logger(subsystem: "app.tally", category: "filter-extension")

    init(containerURL: URL? = nil) throws {
        self.containerURL = try containerURL ?? TallyAppGroup.containerURL()
    }

    func record(flow: NEFilterFlow, bytesIn: Int64, bytesOut: Int64) {
        guard bytesIn > 0 || bytesOut > 0 else { return }

        let event = FlowEvent(
            bundleId: flow.tallyAttribution.bundleId,
            executableName: flow.tallyAttribution.executableName,
            bytesIn: bytesIn,
            bytesOut: bytesOut
        )

        do {
            try FlowEventLog.append(event, to: containerURL)
        } catch {
            logger.error("[filter] event write failed error=\(String(describing: error), privacy: .public)")
        }
    }
}

private extension NEFilterFlow {
    var tallyAttribution: FlowAttribution {
        FlowAttribution.resolve(from: sourceAppAuditToken ?? sourceProcessAuditToken)
    }
}

private struct FlowAttribution {
    let bundleId: String?
    let executableName: String

    static func resolve(from auditTokenData: Data?) -> FlowAttribution {
        guard
            let token = auditToken(from: auditTokenData),
            let executablePath = executablePath(for: token)
        else {
            return FlowAttribution(bundleId: nil, executableName: "unknown")
        }

        let executableURL = URL(fileURLWithPath: executablePath)
        let executableName = executableURL.deletingPathExtension().lastPathComponent
        guard
            let appURL = enclosingAppBundleURL(for: executableURL),
            let bundleId = Bundle(url: appURL)?.bundleIdentifier
        else {
            return FlowAttribution(bundleId: nil, executableName: executableName)
        }

        return FlowAttribution(bundleId: bundleId, executableName: executableName)
    }

    private static func auditToken(from data: Data?) -> audit_token_t? {
        guard let data, data.count == MemoryLayout<audit_token_t>.size else {
            return nil
        }

        var token = audit_token_t()
        _ = withUnsafeMutableBytes(of: &token) { tokenBuffer in
            data.copyBytes(to: tokenBuffer)
        }
        return token
    }

    private static func executablePath(for token: audit_token_t) -> String? {
        var mutableToken = token
        let bufferSize = 4096
        var buffer = [CChar](repeating: 0, count: bufferSize)
        let result = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_pidpath_audittoken(
                &mutableToken,
                pointer.baseAddress,
                UInt32(bufferSize)
            )
        }

        guard result > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func enclosingAppBundleURL(for executableURL: URL) -> URL? {
        var current = executableURL
        while current.path != "/" {
            if current.pathExtension == "app" {
                return current
            }
            current.deleteLastPathComponent()
        }
        return nil
    }
}
