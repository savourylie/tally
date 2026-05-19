import Foundation
import GRDB

enum Migrations {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "networks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ssid", .text)
                t.column("interface_type", .text).notNull()
                t.column("is_hotspot", .integer).notNull().defaults(to: 0)
                t.column("monthly_limit_gb", .double)
            }

            try db.create(table: "flow_samples") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("bundle_id", .text)
                t.column("executable_name", .text)
                t.column("bytes_in", .integer).notNull()
                t.column("bytes_out", .integer).notNull()
                t.column("network_id", .integer).references("networks", column: "id")
            }
            try db.create(
                index: "idx_flow_samples_timestamp",
                on: "flow_samples",
                columns: ["timestamp"]
            )

            try db.create(table: "daily_aggregates") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull()
                t.column("bundle_id", .text)
                t.column("category", .text)
                t.column("network_id", .integer).references("networks", column: "id")
                t.column("total_in", .integer).notNull()
                t.column("total_out", .integer).notNull()
                t.uniqueKey(["date", "bundle_id", "category", "network_id"])
            }
            try db.create(
                index: "idx_daily_aggregates_date_bundle",
                on: "daily_aggregates",
                columns: ["date", "bundle_id"]
            )

            try db.create(table: "process_categories") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("process_identifier", .text).notNull().unique()
                t.column("category_name", .text).notNull()
                t.column("icon_name", .text).notNull()
                t.column("display_name", .text).notNull()
            }
            try db.create(
                index: "idx_process_categories_identifier",
                on: "process_categories",
                columns: ["process_identifier"]
            )

            for seed in processCategorySeed {
                try db.execute(
                    sql: """
                        INSERT INTO process_categories
                          (process_identifier, category_name, icon_name, display_name)
                        VALUES (?, ?, ?, ?)
                        """,
                    arguments: [
                        seed.processIdentifier,
                        seed.categoryName,
                        seed.iconName,
                        seed.displayName,
                    ]
                )
            }
        }

        return migrator
    }
}

private struct ProcessCategorySeed {
    let processIdentifier: String
    let categoryName: String
    let iconName: String
    let displayName: String
}

private let processCategorySeed: [ProcessCategorySeed] = [
    // iCloud
    .init(processIdentifier: "bird",            categoryName: "iCloud",            iconName: "icloud.fill",                            displayName: "iCloud"),
    .init(processIdentifier: "cloudd",          categoryName: "iCloud",            iconName: "icloud.fill",                            displayName: "iCloud"),
    .init(processIdentifier: "cloudphotod",     categoryName: "iCloud",            iconName: "icloud.fill",                            displayName: "iCloud"),
    .init(processIdentifier: "CloudKit",        categoryName: "iCloud",            iconName: "icloud.fill",                            displayName: "iCloud"),
    .init(processIdentifier: "apsd",            categoryName: "iCloud",            iconName: "icloud.fill",                            displayName: "iCloud"),

    // Time Machine 備份
    .init(processIdentifier: "backupd",         categoryName: "Time Machine 備份", iconName: "externaldrive.fill.badge.timemachine",   displayName: "Time Machine 備份"),
    .init(processIdentifier: "backupd-helper",  categoryName: "Time Machine 備份", iconName: "externaldrive.fill.badge.timemachine",   displayName: "Time Machine 備份"),

    // 軟體更新
    .init(processIdentifier: "softwareupdated",   categoryName: "軟體更新", iconName: "arrow.down.circle.fill", displayName: "軟體更新"),
    .init(processIdentifier: "osinstallersetupd", categoryName: "軟體更新", iconName: "arrow.down.circle.fill", displayName: "軟體更新"),

    // Spotlight 搜尋
    .init(processIdentifier: "mds",             categoryName: "Spotlight 搜尋", iconName: "magnifyingglass", displayName: "Spotlight 搜尋"),
    .init(processIdentifier: "mdworker_shared", categoryName: "Spotlight 搜尋", iconName: "magnifyingglass", displayName: "Spotlight 搜尋"),
    .init(processIdentifier: "mds_stores",      categoryName: "Spotlight 搜尋", iconName: "magnifyingglass", displayName: "Spotlight 搜尋"),

    // 系統其他
    .init(processIdentifier: "mDNSResponder",   categoryName: "系統其他", iconName: "gearshape.fill", displayName: "系統其他"),
    .init(processIdentifier: "trustd",          categoryName: "系統其他", iconName: "gearshape.fill", displayName: "系統其他"),
    .init(processIdentifier: "nsurlsessiond",   categoryName: "系統其他", iconName: "gearshape.fill", displayName: "系統其他"),
]
