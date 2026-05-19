import SwiftUI
import AppKit

extension Color {
    enum tally {
        // MARK: - Brand ramp (warm amber, mode-invariant)

        static let brand50  = Color(srgb: 0xFDF6E8)
        static let brand100 = Color(srgb: 0xFAE9C5)
        static let brand200 = Color(srgb: 0xF4D38C)
        static let brand300 = Color(srgb: 0xEEBC52)
        static let brand400 = Color(srgb: 0xE89B2F)
        static let brand500 = Color(srgb: 0xD4811B)
        static let brand600 = Color(srgb: 0xB0660E)
        static let brand700 = Color(srgb: 0x864C07)

        // MARK: - Accent (semantic)

        static let accent      = brand400
        static let accentHover = brand500
        static let accentPress = brand600
        static let accentSoft  = dynamic(
            lightHex: 0xFDF6E8,
            darkRGBA: (232.0 / 255, 155.0 / 255, 47.0 / 255, 0.16)
        )
        static let accentOn = Color(srgb: 0xFFFFFF)

        // MARK: - Status

        static let successSoft = dynamic(
            lightHex: 0xE6F4EA,
            darkRGBA: (46.0 / 255, 139.0 / 255, 87.0 / 255, 0.18)
        )
        static let success       = Color(srgb: 0x2E8B57)
        static let successStrong = Color(srgb: 0x1E5E3A)

        static let warningSoft = dynamic(
            lightHex: 0xFDF1D6,
            darkRGBA: (212.0 / 255, 132.0 / 255, 23.0 / 255, 0.18)
        )
        static let warning       = Color(srgb: 0xD48417)
        static let warningStrong = Color(srgb: 0x8A530A)

        static let dangerSoft = dynamic(
            lightHex: 0xFBEAEA,
            darkRGBA: (200.0 / 255, 54.0 / 255, 43.0 / 255, 0.18)
        )
        static let danger       = Color(srgb: 0xC8362B)
        static let dangerStrong = Color(srgb: 0x8B221A)

        // MARK: - Warm-neutral ramp (mode-invariant)

        static let n0   = Color(srgb: 0xFFFFFF)
        static let n25  = Color(srgb: 0xFCFBF8)
        static let n50  = Color(srgb: 0xFAF9F7)
        static let n100 = Color(srgb: 0xF4F2EC)
        static let n150 = Color(srgb: 0xEDEAE3)
        static let n200 = Color(srgb: 0xE8E5DE)
        static let n300 = Color(srgb: 0xD8D3C8)
        static let n400 = Color(srgb: 0xBAB3A4)
        static let n500 = Color(srgb: 0x8E8779)
        static let n600 = Color(srgb: 0x6B6557)
        static let n700 = Color(srgb: 0x4A453A)
        static let n800 = Color(srgb: 0x2E2A22)
        static let n900 = Color(srgb: 0x1F1C16)
        static let n950 = Color(srgb: 0x15130F)

        // MARK: - Surfaces

        static let bgApp      = dynamic(lightHex: 0xFAF9F7, darkHex: 0x1B1814)
        static let bgSidebar  = dynamic(lightHex: 0xF4F2EC, darkHex: 0x221E18)
        static let bgCard     = dynamic(lightHex: 0xFFFFFF, darkHex: 0x26221B)
        static let bgCardAlt  = dynamic(lightHex: 0xFCFBF8, darkHex: 0x2A261F)
        static let bgPopover  = dynamicRGBA(
            lightRGBA: (252.0 / 255, 251.0 / 255, 248.0 / 255, 0.92),
            darkRGBA:  (38.0 / 255, 34.0 / 255, 27.0 / 255, 0.92)
        )
        static let bgHover    = dynamicRGBA(
            lightRGBA: (0, 0, 0, 0.04),
            darkRGBA:  (1, 1, 1, 0.05)
        )
        static let bgPress    = dynamicRGBA(
            lightRGBA: (0, 0, 0, 0.07),
            darkRGBA:  (1, 1, 1, 0.08)
        )
        static let bgSelected = dynamic(
            lightHex: 0xFDF6E8,
            darkRGBA: (232.0 / 255, 155.0 / 255, 47.0 / 255, 0.16)
        )

        // MARK: - Foregrounds

        static let fg1   = dynamic(lightHex: 0x1F1C16, darkHex: 0xF2EFE8)
        static let fg2   = dynamic(lightHex: 0x4A453A, darkHex: 0xBDB6A6)
        static let fg3   = Color(srgb: 0x8E8779)   // CSS: identical in light + dark (n-500)
        static let fg4   = dynamic(lightHex: 0xBAB3A4, darkHex: 0x6B6557)
        static let fgInv = dynamic(lightHex: 0xFFFFFF, darkHex: 0x1B1814)

        // MARK: - Borders & dividers

        static let border       = dynamic(lightHex: 0xE8E5DE, darkHex: 0x34302A)
        static let borderStrong = dynamic(lightHex: 0xD8D3C8, darkHex: 0x45403A)
        static let divider      = dynamic(lightHex: 0xEDEAE3, darkHex: 0x2D2922)

        // MARK: - Focus / selection

        static let focusRing = brand400
    }
}

// MARK: - Helpers (file-private)

private extension Color {
    init(srgb hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

private extension NSColor {
    convenience init(srgbHex hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8)  & 0xFF) / 255
        let b = CGFloat( hex        & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

private func dynamic(lightHex: UInt32, darkHex: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbHex: darkHex)
            : NSColor(srgbHex: lightHex)
    })
}

private func dynamic(
    lightHex: UInt32,
    darkRGBA: (Double, Double, Double, Double)
) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.isDark {
            return NSColor(
                srgbRed: CGFloat(darkRGBA.0),
                green:   CGFloat(darkRGBA.1),
                blue:    CGFloat(darkRGBA.2),
                alpha:   CGFloat(darkRGBA.3)
            )
        }
        return NSColor(srgbHex: lightHex)
    })
}

private func dynamicRGBA(
    lightRGBA: (Double, Double, Double, Double),
    darkRGBA:  (Double, Double, Double, Double)
) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let c = appearance.isDark ? darkRGBA : lightRGBA
        return NSColor(
            srgbRed: CGFloat(c.0),
            green:   CGFloat(c.1),
            blue:    CGFloat(c.2),
            alpha:   CGFloat(c.3)
        )
    })
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
