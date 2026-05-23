import SwiftUI

struct StatusLine: View {
    let connection: NetworkConnection

    var body: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: connection.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(connection.isOffline ? Color.tally.fg3 : Color.tally.success)

            if connection.isOffline {
                Text("你現在離線")
                    .font(.tally.body)
                    .tracking(Font.tallyTracking.body)
                    .foregroundStyle(Color.tally.fg2)
            } else {
                HStack(spacing: 0) {
                    Text("你現在連在 ")
                        .font(.tally.body)
                        .foregroundStyle(Color.tally.fg2)
                    Text(connection.displayName)
                        .font(.tally.body.bold())
                        .foregroundStyle(Color.tally.fg1)
                }
                .tracking(Font.tallyTracking.body)
            }
        }
    }
}

#Preview("Wi-Fi") {
    StatusLine(connection: .wifi(name: "家裡的 Wi-Fi"))
        .padding()
        .background(Color.tally.bgApp)
}

#Preview("Ethernet") {
    StatusLine(connection: .ethernet)
        .padding()
        .background(Color.tally.bgApp)
}

#Preview("Offline") {
    StatusLine(connection: .offline)
        .padding()
        .background(Color.tally.bgApp)
}
