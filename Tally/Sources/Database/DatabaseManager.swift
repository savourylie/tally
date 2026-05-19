import Foundation
import GRDB

final class DatabaseManager: @unchecked Sendable {
    static let shared: DatabaseManager = {
        do {
            return try DatabaseManager()
        } catch {
            fatalError("Failed to initialize DatabaseManager: \(error)")
        }
    }()

    let dbPool: DatabasePool

    private init() throws {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let tallyDirectory = appSupport.appendingPathComponent("Tally", isDirectory: true)
        try fileManager.createDirectory(
            at: tallyDirectory,
            withIntermediateDirectories: true
        )

        let databaseURL = tallyDirectory.appendingPathComponent("tally.sqlite")
        dbPool = try DatabasePool(path: databaseURL.path)

        try Migrations.makeMigrator().migrate(dbPool)
    }
}
