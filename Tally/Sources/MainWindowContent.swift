import SwiftUI

struct MainWindowContent: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AppState id: \(String(describing: ObjectIdentifier(appState)))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                TokensPreviewGrid()
            }
        }
        .frame(width: 1120, height: 800)
    }
}

#Preview {
    MainWindowContent()
        .environment(AppState())
}
