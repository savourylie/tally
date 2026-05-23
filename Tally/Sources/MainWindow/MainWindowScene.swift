import SwiftUI

enum MainWindowLayout {
    static let windowWidth: CGFloat = 960
    static let windowHeight: CGFloat = 640
    static let sidebarWidth: CGFloat = 200
    static let contentWidth: CGFloat = windowWidth - sidebarWidth
}

struct MainWindowScene: View {
    @Environment(AppState.self) private var appState
    @Environment(Preferences.self) private var preferences
    @State private var lifetimeProbe = MainWindowLifetimeProbe()

    var body: some View {
        ZStack {
            if !preferences.onboardingComplete {
                OnboardingFlow()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                HStack(spacing: 0) {
                    Sidebar(selection: appState.mainWindow.selection) { selection in
                        withAnimation(Motion.view) {
                            appState.mainWindow.selection = selection
                        }
                    }

                    content
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
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
        ZStack(alignment: .topLeading) {
            Color.tally.bgApp

            selectedContent
                .id(appState.mainWindow.selection)
                .transition(.opacity.animation(Motion.view))
        }
        .frame(width: MainWindowLayout.contentWidth, height: MainWindowLayout.windowHeight)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch appState.mainWindow.selection {
        case .overview:
            OverviewScreen()
        case .settings:
            SettingsView()
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.tally.title3)
            .tracking(Font.tallyTracking.title3)
            .foregroundStyle(Color.tally.fg2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
