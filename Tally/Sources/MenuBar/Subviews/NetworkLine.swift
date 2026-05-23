import SwiftUI

struct NetworkLine: View {
    let connection: NetworkConnection

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: connection.symbolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(connection.isOffline ? Color.tally.fg3 : Color.tally.success)

            if connection.isOffline {
                Text("你現在離線")
                    .foregroundStyle(Color.tally.fg2)
                    .font(.tally.caption)
                    .tracking(Font.tallyTracking.caption)
            } else {
                HStack(spacing: 0) {
                    Text("你現在連在 ")
                        .foregroundStyle(Color.tally.fg2)
                    Text(connection.displayName)
                        .font(.tally.bodyEm)
                        .foregroundStyle(Color.tally.fg1)
                }
                .font(.tally.caption)
                .tracking(Font.tallyTracking.caption)
            }
        }
    }
}

#Preview {
    NetworkLine(connection: .wifi(name: "家裡的 Wi-Fi"))
        .padding()
        .frame(width: 320)
}
