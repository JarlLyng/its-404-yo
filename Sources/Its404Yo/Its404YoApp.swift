import SwiftUI

@main
struct Its404YoApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 640, minHeight: 480)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {} // single-window utility
        }
    }
}
