import SwiftUI
import AppKit

@main
struct Its404YoApp: App {
    @StateObject private var state = AppState()

    // Screenshot/demo hook — DEBUG only, inert without the `-DemoMode` launch argument.
    #if DEBUG
    private let demoMode = CommandLine.arguments.contains("-DemoMode")
    #else
    private let demoMode = false
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 640, minHeight: 480)
                .onAppear { if demoMode { state.seedDemoData() } }
                .background(WindowConfigurator(active: demoMode))
                .preferredColorScheme(demoMode ? .dark : nil)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {} // single-window utility
        }
    }
}

/// In demo mode, size + center the window and print its window number to stdout
/// so a screenshot script can capture it. No effect in normal operation.
private struct WindowConfigurator: NSViewRepresentable {
    let active: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        guard active else { return view }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let window = view.window else { return }
            window.setContentSize(NSSize(width: 1120, height: 740))
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("ITS404_WINDOW=\(window.windowNumber)")
            fflush(stdout)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
