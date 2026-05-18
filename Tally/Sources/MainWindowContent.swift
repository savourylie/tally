import SwiftUI

struct MainWindowContent: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Tally")
                .font(.largeTitle)
            Text("Placeholder — see TICKET-012")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(width: 960, height: 640)
    }
}

#Preview {
    MainWindowContent()
}
