import Foundation

/// One day's network usage, backing the daily-trend bar chart (#029) and the
/// popover sparkline (#031). `date` is at local midnight so it aligns with the
/// `yyyy-MM-dd` keys stored in `daily_aggregates`.
struct DailyUsage: Identifiable, Equatable, Sendable {
    let date: Date
    let bytesIn: Int64
    let bytesOut: Int64

    var id: Date { date }
    var total: Int64 { bytesIn + bytesOut }
}
