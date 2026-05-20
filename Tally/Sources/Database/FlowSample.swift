import Foundation
import GRDB

struct FlowSample: Codable, FetchableRecord, PersistableRecord, Sendable {
    var id: Int64?
    var timestamp: Int64
    var bundleId: String?
    var executableName: String
    var bytesIn: Int64
    var bytesOut: Int64
    var networkId: Int64?

    static let databaseTableName = "flow_samples"

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case bundleId = "bundle_id"
        case executableName = "executable_name"
        case bytesIn = "bytes_in"
        case bytesOut = "bytes_out"
        case networkId = "network_id"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
