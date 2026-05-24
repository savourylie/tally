import Foundation

/// Single source of truth for turning an `Int64` byte count into a display
/// string or a chart-axis value. Mirrors the inline logic currently duplicated
/// across `AppRow`, `HeroCard`, `EstimateSentence`, `TopAppRow`, and
/// `HeroNumber` so a future migration of those call sites is a visual no-op.
///
/// Pure value logic — no SwiftUI, no `@MainActor` — to stay trivially testable.
enum ByteFormat {
    private static let bytesPerGigabyte = EstimateCalculator.bytesPerGigabyte // 1_073_741_824
    private static let bytesPerMegabyte: Double = 1_048_576

    /// `"12.4 GB"` — matches `HeroCard` / `HeroNumber` / `EstimateSentence`.
    static func gigabytes(_ bytes: Int64, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f GB", Double(bytes) / bytesPerGigabyte)
    }

    /// `"%.2f GB"` when the value is ≥ 0.01 GB, otherwise `"%.1f MB"` —
    /// byte-for-byte identical to the `AppRow` / `TopAppRow` behaviour.
    static func adaptive(_ bytes: Int64) -> String {
        let gb = Double(bytes) / bytesPerGigabyte
        if gb >= 0.01 {
            return String(format: "%.2f GB", gb)
        } else {
            return String(format: "%.1f MB", Double(bytes) / bytesPerMegabyte)
        }
    }

    /// GB as a `Double`, for use as a Swift Charts Y value.
    static func gigabytesValue(_ bytes: Int64) -> Double {
        Double(bytes) / bytesPerGigabyte
    }
}
