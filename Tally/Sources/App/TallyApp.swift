import SwiftUI

@main
struct TallyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Tally", image: "MenuBarIcon") {
            PopoverView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Window("Tally", id: "main") {
            MainWindowScene()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        .defaultSize(
            width: MainWindowLayout.windowWidth,
            height: MainWindowLayout.windowHeight
        )
        .windowToolbarStyle(.unifiedCompact)
    }
}
