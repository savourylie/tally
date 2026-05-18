import SwiftUI

struct MenuBarContent: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Tally")
                .font(.headline)
            Text("Placeholder — see TICKET-010")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 280)
    }
}

#Preview {
    MenuBarContent()
}
