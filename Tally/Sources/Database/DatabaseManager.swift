import Foundation
import GRDB

final class DatabaseManager: @unchecked Sendable {
    let dbPool: DatabasePool

    init() throws {
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
        Log.db.info("[db] opened path=\(databaseURL.path, privacy: .public)")

        try Migrations.makeMigrator().migrate(dbPool)
        Log.db.info("[db] migrations done")
    }
}
