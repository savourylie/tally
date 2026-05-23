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

        WindowGroup("Tally", id: "main") {
            MainWindowContent()
                .environment(appState)
        }
        .windowResizability(.contentSize)
    }
}

