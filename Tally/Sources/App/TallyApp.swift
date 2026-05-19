import SwiftUI

@main
struct TallyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Tally", image: "MenuBarIcon") {
            MenuBarContent()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Window("Tally", id: "main") {
            MainWindowContent()
                .environment(appState)
        }
        .windowResizability(.contentSize)
    }
}
