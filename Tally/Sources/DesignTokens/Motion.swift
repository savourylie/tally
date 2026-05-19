import SwiftUI

enum Motion {
    static let durHover:   TimeInterval = 0.150
    static let durState:   TimeInterval = 0.200
    static let durPopover: TimeInterval = 0.280
    static let durView:    TimeInterval = 0.320

    static let hover:   Animation = .timingCurve(0.4,  0,    0.2, 1, duration: durHover)
    static let state:   Animation = .timingCurve(0.4,  0,    0.2, 1, duration: durState)
    static let popover: Animation = .timingCurve(0.32, 0.72, 0,   1, duration: durPopover)
    static let view:    Animation = .timingCurve(0.32, 0.72, 0,   1, duration: durView)
}
