import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            Text("Tally")
                .font(.headline)
            Text("AppState ready")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("id: \(String(describing: ObjectIdentifier(appState)))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("Placeholder — see TICKET-010")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button("Open Main Window") {
                openWindow(id: "main")
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}

#Preview {
    MenuBarContent()
        .environment(AppState())
}
