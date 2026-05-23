import SwiftUI
import CoreWLAN

struct NetworkLine: View {
    let networkName: String

    private var activeSSID: String {
        #if targetEnvironment(simulator)
        return networkName
        #else
        if let interface = CWWiFiClient.shared().interface(),
           let ssid = interface.ssid(),
           !ssid.isEmpty {
            return ssid
        }
        return networkName
        #endif
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.tally.success)
            
            HStack(spacing: 0) {
                Text("你現在連在 ")
                    .foregroundStyle(Color.tally.fg2)
                Text(activeSSID)
                    .font(.tally.bodyEm)
                    .foregroundStyle(Color.tally.fg1)
            }
            .font(.tally.caption)
            .tracking(Font.tallyTracking.caption)
        }
    }
}

#Preview {
    NetworkLine(networkName: "家裡的 Wi-Fi")
        .padding()
        .frame(width: 320)
}
