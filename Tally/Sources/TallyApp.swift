import SwiftUI

@main
struct TallyApp: App {
    init() {
        _ = DatabaseManager.shared
    }

    var body: some Scene {
        MenuBarExtra("Tally", image: "MenuBarIcon") {
            MenuBarContent()
        }
        .menuBarExtraStyle(.window)

        Window("Tally", id: "main") {
            MainWindowContent()
        }
        .windowResizability(.contentSize)
    }
}
