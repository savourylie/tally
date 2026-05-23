import SwiftUI

struct ProgressBar: View {
    private let value: Double
    private let isVisible: Bool
    private let showsTrack: Bool

    init(value: Double, showsTrack: Bool = true) {
        self.value = value
        self.isVisible = true
        self.showsTrack = showsTrack
    }

    init(monthToDateBytes: Int64, monthlyCapBytes: Int64?, showsTrack: Bool = true) {
        guard let monthlyCapBytes, monthlyCapBytes > 0 else {
            self.value = 0
            self.isVisible = false
            self.showsTrack = showsTrack
            return
        }

        self.value = Double(monthToDateBytes) / Double(monthlyCapBytes)
        self.isVisible = true
        self.showsTrack = showsTrack
    }

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        if isVisible {
            ZStack(alignment: .leading) {
                if showsTrack {
                    RoundedRectangle(cornerRadius: Radius.r6, style: .continuous)
                        .fill(Color.tally.divider)
                }

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: Radius.r6, style: .continuous)
                        .fill(Color.tally.brand400)
                        .frame(width: geo.size.width * CGFloat(clampedValue))
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: Radius.r6, style: .continuous))
            .animation(Motion.state, value: clampedValue)
        }
    }
}

#Preview("60%") {
    ProgressBar(value: 0.6)
        .padding()
        .frame(width: 320)
}

#Preview("100%") {
    ProgressBar(value: 1)
        .padding()
        .frame(width: 320)
}

#Preview("No Cap") {
    ProgressBar(monthToDateBytes: 12 * 1024 * 1024 * 1024, monthlyCapBytes: nil)
        .padding()
        .frame(width: 320)
}
