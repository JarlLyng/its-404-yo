import SwiftUI
import AppKit

@main
struct Its404YoApp: App {
    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // As early as possible, so a crash during launch is reported too. Anonymous (Telemetry).
        Telemetry.start()
    }

    // Screenshot/demo hook — DEBUG only, inert without a `-Demo…` launch argument.
    // Scenes: -DemoMode / -DemoAnalysis (populated, default), -DemoEmpty (drop zone),
    //         -DemoDone (populated + conversion report), -DemoPack (a whole pack, 18 files).
    // Appearance: -DemoLight (default dark). Window: -DemoCompact (800×560 instead of 1120×740 points).
    #if DEBUG
    private let demoMode = CommandLine.arguments.contains { $0.hasPrefix("-Demo") }
    private let demoEmpty = CommandLine.arguments.contains("-DemoEmpty")
    private let demoDone = CommandLine.arguments.contains("-DemoDone")
    private let demoPack = CommandLine.arguments.contains("-DemoPack")
    private let demoLight = CommandLine.arguments.contains("-DemoLight")
    private let demoSize = DemoWindow.size(from: CommandLine.arguments)
    #else
    private let demoMode = false
    private let demoEmpty = false
    private let demoDone = false
    private let demoPack = false
    private let demoLight = false
    private let demoSize = DemoWindow.defaultSize
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 640, minHeight: 480)
                .onAppear {
                    guard demoMode else { return }
                    if demoEmpty { return }              // leave items empty → DropZoneView
                    if demoPack { state.seedDemoPack(); return }
                    state.seedDemoData()
                    if demoDone { state.seedDemoReport() }
                }
                .background(WindowConfigurator(active: demoMode, size: demoSize))
                .preferredColorScheme(demoMode ? (demoLight ? .light : .dark) : nil)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {} // single-window utility
            // Replaces the default "It's 404, yo! Help" item, which only says help isn't available.
            // Beyond anonymous crash reports and one count, the app learns nothing about its use, so
            // what users choose to say is how we learn; this gives an unhappy user somewhere to go
            // other than a review.
            CommandGroup(replacing: .help) {
                Button("Send Feedback\u{2026}") {
                    NSWorkspace.shared.open(FeedbackMail.current())
                }
            }
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
    let size: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        guard active else { return view }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let window = view.window else { return }
            window.setContentSize(size)
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

/// The demo window's content size in points. `-DemoCompact` shows the same screen in a smaller window,
/// so its text is larger in a screenshot that reads as zoomed in without cropping anything. A flag
/// rather than `-DemoSize 800x560`: AppKit takes a bare argument like `800x560` as a file to open,
/// and SwiftUI then opens no window.
enum DemoWindow {
    static let defaultSize = NSSize(width: 1120, height: 740)
    static let compactSize = NSSize(width: 800, height: 560)

    static func size(from arguments: [String]) -> NSSize {
        arguments.contains("-DemoCompact") ? compactSize : defaultSize
    }
}
