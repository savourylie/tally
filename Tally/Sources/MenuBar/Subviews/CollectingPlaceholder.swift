import SwiftUI

struct CollectingPlaceholder: View {
    var body: some View {
        VStack(spacing: Spacing.s3) {
            Spacer()
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 28))
                .foregroundStyle(Color.tally.brand300)
            
            Text("資料正在收集中，幾分鐘後就能看到數據")
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
