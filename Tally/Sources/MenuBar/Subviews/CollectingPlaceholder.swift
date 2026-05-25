import SwiftUI

struct CollectingPlaceholder: View {
    /// TICKET-033: defaults to the genuine "collecting" copy; `PopoverView` passes
    /// the honest non-live recovery message when collection is unavailable.
    var message: String = "資料正在收集中，幾分鐘後就能看到數據"

    var body: some View {
        VStack(spacing: Spacing.s3) {
            Spacer()
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 28))
                .foregroundStyle(Color.tally.brand300)

            Text(message)
                .font(.tally.body)
                .tracking(Font.tallyTracking.body)
                .foregroundStyle(Color.tally.fg2)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .padding(Spacing.s4)
        .background(Color.tally.bgCardAlt)
        .clipShape(RoundedRectangle(cornerRadius: Radius.r10))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.r10)
                .stroke(Color.tally.border, lineWidth: 1)
        )
    }
}

#Preview {
    CollectingPlaceholder()
        .padding()
        .frame(width: 320)
}
