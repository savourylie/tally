import SwiftUI

enum MainWindowLayout {
    static let windowWidth: CGFloat = 960
    static let windowHeight: CGFloat = 640
    static let sidebarWidth: CGFloat = 200
    static let contentWidth: CGFloat = windowWidth - sidebarWidth
}

struct MainWindowScene: View {
    @Environment(AppState.self) private var appState
    @State private var lifetimeProbe = MainWindowLifetimeProbe()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: appState.mainWindow.selection) { selection in
                withAnimation(Motion.view) {
                    appState.mainWindow.selection = selection
                }
            }

            content
        }
        .frame(width: MainWindowLayout.windowWidth, height: MainWindowLayout.windowHeight)
        .fixedSize()
        .background(Color.tally.bgApp)
        .onAppear {
            _ = lifetimeProbe
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            Color.tally.bgApp

            Text(appState.mainWindow.selection.placeholder)
                .font(.tally.title3)
                .tracking(Font.tallyTracking.title3)
                .foregroundStyle(Color.tally.fg2)
                .id(appState.mainWindow.selection)
                .transition(.opacity.animation(Motion.view))
        }
        .frame(width: MainWindowLayout.contentWidth, height: MainWindowLayout.windowHeight)
    }
}

@MainActor
private final class MainWindowLifetimeProbe {
    init() {
        Log.ui.debug("[main-window] init")
    }

    deinit {
        Log.ui.debug("[main-window] deinit")
    }
}

#Preview {
    MainWindowScene()
        .environment(AppState())
}
