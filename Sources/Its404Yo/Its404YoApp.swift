import SwiftUI
import AppKit

@main
struct Its404YoApp: App {
    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Screenshot/demo hook — DEBUG only, inert without a `-Demo…` launch argument.
    // Scenes: -DemoMode / -DemoAnalysis (populated, default), -DemoEmpty (drop zone),
    //         -DemoDone (populated + conversion report). Appearance: -DemoLight (default dark).
    #if DEBUG
    private let demoMode = CommandLine.arguments.contains { $0.hasPrefix("-Demo") }
    private let demoEmpty = CommandLine.arguments.contains("-DemoEmpty")
    private let demoDone = CommandLine.arguments.contains("-DemoDone")
    private let demoLight = CommandLine.arguments.contains("-DemoLight")
    #else
    private let demoMode = false
    private let demoEmpty = false
    private let demoDone = false
    private let demoLight = false
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 640, minHeight: 480)
                .onAppear {
                    guard demoMode else { return }
                    if demoEmpty { return }              // leave items empty → DropZoneView
                    state.seedDemoData()
                    if demoDone { state.seedDemoReport() }
                }
                .background(WindowConfigurator(active: demoMode))
                .preferredColorScheme(demoMode ? (demoLight ? .light : .dark) : nil)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {} // single-window utility
        }
    }
}

/// Single-window utility: quit when the main window is closed, so there's no
/// windowless-but-running state. (App Store Guideline 4 — Design.) There is no
/// document/unsaved state to preserve; conversions write to disk as they run.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
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
