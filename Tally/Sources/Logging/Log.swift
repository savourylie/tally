import Foundation
import os

enum Log {
    private static let subsystem = "app.tally"

    static let db        = Logger(subsystem: subsystem, category: "db")
    static let collector = Logger(subsystem: subsystem, category: "collector")
    static let agg       = Logger(subsystem: subsystem, category: "agg")
    static let store     = Logger(subsystem: subsystem, category: "store")
    static let ui        = Logger(subsystem: subsystem, category: "ui")
    static let notif     = Logger(subsystem: subsystem, category: "notif")
    static let ne        = Logger(subsystem: subsystem, category: "ne")
    static let meta      = Logger(subsystem: subsystem, category: "meta")
}
