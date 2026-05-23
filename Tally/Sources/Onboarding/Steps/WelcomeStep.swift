import SwiftUI

struct TallyArtwork: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.tally.brand50)
                .frame(width: 120, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.tally.brand200, lineWidth: 1.5)
                )
            
            Canvas { context, size in
                var path = Path()
                
                // Vertical lines at x: 32, 48, 64, 80
                // Y goes from 36 to 84
                // Diagonal from 24, 80 to 88, 40
                for x in [32.0, 48.0, 64.0, 80.0] {
                    path.move(to: CGPoint(x: x, y: 36))
                    path.addLine(to: CGPoint(x: x, y: 84))
                }
                
                path.move(to: CGPoint(x: 24, y: 80))
                path.addLine(to: CGPoint(x: 88, y: 40))
                
                context.stroke(
                    path,
                    with: .color(Color.tally.accent),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
            }
            .frame(width: 120, height: 120)
        }
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 0) {
            // Banner Art
            ZStack {
                Color.tally.brand50
                TallyArtwork()
            }
            .frame(height: 168)
            .overlay(
                Rectangle()
                    .fill(Color.tally.border)
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Content
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("第 1 步 / 共 3 步")
                    .font(.tally.micro)
                    .tracking(Font.tallyTracking.caps)
                    .foregroundStyle(Color.tally.fg3)
                
                Text("歡迎使用 Tally")
                    .font(.tally.title1)
                    .tracking(Font.tallyTracking.title1)
                    .foregroundStyle(Color.tally.fg1)
                
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("Tally 會追蹤你 Mac 的流量使用。")
                        .font(.tally.body)
                        .tracking(Font.tallyTracking.body)
                        .foregroundStyle(Color.tally.fg2)
                        .lineSpacing(4)
                    
                    Text("不會擋網、不上傳任何資料到雲端。")
                        .font(.tally.bodyEm)
                        .tracking(Font.tallyTracking.body)
                        .foregroundStyle(Color.tally.fg1)
                        .lineSpacing(4)
                    
                    Text("所有資料都留在你的 Mac 中。")
                        .font(.tally.body)
                        .tracking(Font.tallyTracking.body)
                        .foregroundStyle(Color.tally.fg2)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    WelcomeStep()
        .frame(width: 540, height: 460)
        .background(Color.tally.bgCard)
}
