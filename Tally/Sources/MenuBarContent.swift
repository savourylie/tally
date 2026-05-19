import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var appState

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
        }
        .padding(20)
        .frame(width: 280)
    }
}

#Preview {
    MenuBarContent()
        .environment(AppState())
}
