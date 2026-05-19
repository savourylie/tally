import SwiftUI

extension Font {
    enum tally {
        static let mega    = Font.system(size: 64, weight: .semibold, design: .default).monospacedDigit()
        static let display = Font.system(size: 34, weight: .semibold, design: .default).monospacedDigit()
        static let title1  = Font.system(size: 22, weight: .semibold, design: .default)
        static let title2  = Font.system(size: 17, weight: .semibold, design: .default)
        static let title3  = Font.system(size: 15, weight: .semibold, design: .default)
        static let body    = Font.system(size: 13, weight: .regular,  design: .default)
        static let bodyEm  = Font.system(size: 13, weight: .semibold, design: .default)
        static let callout = Font.system(size: 12, weight: .regular,  design: .default)
        static let caption = Font.system(size: 11, weight: .regular,  design: .default)
        static let micro   = Font.system(size: 10, weight: .semibold, design: .default)
        static let mono    = Font.system(size: 13, weight: .regular,  design: .monospaced).monospacedDigit()
    }

    enum tallyTracking {
        static let mega:    CGFloat = -1.41   // -0.022em × 64
        static let display: CGFloat = -0.41   // -0.012em × 34
        static let title1:  CGFloat = -0.26   // -0.012em × 22
        static let title2:  CGFloat = -0.09   // -0.005em × 17
        static let title3:  CGFloat = -0.08   // -0.005em × 15
        static let body:    CGFloat = -0.07   // -0.005em × 13
        static let callout: CGFloat = -0.06   // -0.005em × 12
        static let caption: CGFloat = -0.06   // -0.005em × 11
        static let mono:    CGFloat = -0.07   // -0.005em × 13
        static let caps:    CGFloat =  0.60   //  0.060em × 10
    }
}
