import SwiftUI

struct ProgressBar: View {
    let monthToDateBytes: Int64
    let monthlyCapBytes: Int64?

    private var percentage: Double {
        guard let cap = monthlyCapBytes, cap > 0 else { return 0 }
        return min(Double(monthToDateBytes) / Double(cap), 1.0)
    }

    var body: some View {
        if let cap = monthlyCapBytes, cap > 0 {
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.tally.border)
                    .frame(height: 6)
                
                // Fill
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.tally.brand400)
                        .frame(width: geo.size.width * CGFloat(percentage), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

#Preview("Cap Set - 60%") {
    ProgressBar(monthToDateBytes: 12 * 1024 * 1024 * 1024, monthlyCapBytes: 20 * 1024 * 1024 * 1024)
        .padding()
        .frame(width: 320)
}

#Preview("Cap Set - 100%") {
    ProgressBar(monthToDateBytes: 20 * 1024 * 1024 * 1024, monthlyCapBytes: 20 * 1024 * 1024 * 1024)
        .padding()
        .frame(width: 320)
}

#Preview("No Cap") {
    ProgressBar(monthToDateBytes: 12 * 1024 * 1024 * 1024, monthlyCapBytes: nil)
        .padding()
        .frame(width: 320)
}
