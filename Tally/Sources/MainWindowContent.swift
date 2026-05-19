import SwiftUI

struct MainWindowContent: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Text("Tally")
                .font(.largeTitle)
            Text("AppState ready")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("id: \(String(describing: ObjectIdentifier(appState)))")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Text("Placeholder — see TICKET-012")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 960, height: 640)
    }
}

#Preview {
    MainWindowContent()
        .environment(AppState())
}
