import Foundation

enum TallyAppGroup {
    static let identifier = "group.com.calvinku.Tally"
    static let flowEventsFilename = "flow-events.log"

    static func containerURL(
        fileManager: FileManager = .default,
        allowDevelopmentFallback: Bool = false
    ) throws -> URL {
        if let url = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
            return url
        }

        guard allowDevelopmentFallback else {
            throw AppGroupError.containerUnavailable(identifier)
        }

        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let fallback = appSupport
            .appendingPathComponent("Tally", isDirectory: true)
            .appendingPathComponent("AppGroupFallback", isDirectory: true)
        try fileManager.createDirectory(
            at: fallback,
            withIntermediateDirectories: true
        )
        return fallback
    }
}

enum AppGroupError: LocalizedError, Equatable {
    case containerUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .containerUnavailable(let identifier):
            return "App Group container unavailable: \(identifier)"
        }
    }
}
