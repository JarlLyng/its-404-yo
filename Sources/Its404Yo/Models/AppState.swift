import Foundation
import SwiftUI

/// Owns the app's working state: the analyzed files, settings, progress and the result report.
@MainActor
final class AppState: ObservableObject {
    @Published var items: [AudioFileItem] = []
    @Published var settings = ConversionSettings() {
        didSet { if !isRestoring { persistSettings() } }
    }
    @Published var outputDirectory: URL? {
        didSet { if !isRestoring { persistOutputBookmark() } }
    }
    @Published var isAnalyzing = false
    @Published var isConverting = false
    @Published var progress: Double = 0
    @Published var lastReport: ConversionReport?

    /// Bumped at natural milestones to ask the view to show the App Store review prompt.
    @Published var requestReviewTrigger = 0

    // Derived counts for the summary header.
    var convertCount: Int { items.filter { $0.willConvert }.count }
    var compatibleCount: Int { items.filter { $0.status == .compatible }.count }
    var unreadableCount: Int {
        items.filter { if case .unreadable = $0.status { return true }; return false }.count
    }
    var hasWarnings: Bool { items.contains { !$0.warnings.isEmpty } }
    var canConvert: Bool { !items.isEmpty && outputDirectory != nil && !isConverting && !isAnalyzing }

    // MARK: - Persistence (remember settings + output folder across launches)

    private static let rateKey = "settings.targetSampleRate"
    private static let sanitizeKey = "settings.sanitizeFilenames"
    private static let bookmarkKey = "outputDirectoryBookmark"
    private var isRestoring = false

    init() {
        isRestoring = true
        defer { isRestoring = false }
        let defaults = UserDefaults.standard
        if let raw = defaults.object(forKey: Self.rateKey) as? Double,
           let rate = ConversionSettings.TargetSampleRate(rawValue: raw) {
            settings.targetSampleRate = rate
        }
        settings.sanitizeFilenames = defaults.bool(forKey: Self.sanitizeKey)
        if let data = defaults.data(forKey: Self.bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                  relativeTo: nil, bookmarkDataIsStale: &stale),
               url.startAccessingSecurityScopedResource() {
                outputDirectory = url
            }
        }
    }

    private func persistSettings() {
        let defaults = UserDefaults.standard
        defaults.set(settings.targetSampleRate.rawValue, forKey: Self.rateKey)
        defaults.set(settings.sanitizeFilenames, forKey: Self.sanitizeKey)
    }

    /// Save a security-scoped bookmark so the chosen folder is remembered next launch.
    /// Fails silently for non-real paths (e.g. demo data).
    private func persistOutputBookmark() {
        guard let url = outputDirectory,
              let data = try? url.bookmarkData(options: [.withSecurityScope],
                                               includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
    }

    /// Analyze dropped files/folders off the main thread.
    func handleDrop(urls: [URL]) {
        guard !urls.isEmpty else { return }
        isAnalyzing = true
        lastReport = nil
        Task.detached(priority: .userInitiated) {
            let scanned = SampleScanner.scan(urls)
            let analyzed = scanned.map { AudioFormatInspector.analyze(file: $0) }
            await MainActor.run {
                self.items = analyzed
                self.isAnalyzing = false
            }
        }
    }

    /// Convert (or copy) every item into `outputDirectory`, mirroring folder structure.
    func convert() {
        guard let outDir = outputDirectory else { return }
        let items = self.items
        let targetRate = self.settings.targetSampleRate
        let rate = targetRate.rawValue
        let sanitize = self.settings.sanitizeFilenames
        isConverting = true
        progress = 0

        Task.detached(priority: .userInitiated) {
            var converted = 0, copied = 0, failed = 0, warned = 0, renamed = 0
            var usedPaths = Set<String>()
            let total = max(1, items.count)

            for (index, item) in items.enumerated() {
                // Build the output path. When sanitizing, clean each path component and resolve
                // any collisions the cleaning introduces (case-insensitive, like the SD card).
                let relativePath = sanitize
                    ? item.relativePath.split(separator: "/").map { FilenameSanitizer.sanitize(String($0)) }.joined(separator: "/")
                    : item.relativePath
                var destination = outDir.appendingPathComponent(relativePath)
                if case .needsConversion = item.status {
                    destination = destination.deletingPathExtension().appendingPathExtension("wav")
                }
                if sanitize {
                    var original = outDir.appendingPathComponent(item.relativePath)
                    if case .needsConversion = item.status {
                        original = original.deletingPathExtension().appendingPathExtension("wav")
                    }
                    destination = Self.uniqueDestination(destination, used: &usedPaths)
                    if destination.lastPathComponent != original.lastPathComponent { renamed += 1 }
                }
                do {
                    try FileManager.default.createDirectory(
                        at: destination.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    switch item.status {
                    case .compatible:
                        try? FileManager.default.removeItem(at: destination)
                        try FileManager.default.copyItem(at: item.url, to: destination)
                        copied += 1
                    case .needsConversion:
                        try AudioConverter.convert(source: item.url, destination: destination, targetSampleRate: rate)
                        converted += 1
                    case .unreadable:
                        failed += 1
                    }
                    if !item.warnings.isEmpty { warned += 1 }
                } catch {
                    failed += 1
                }

                let value = Double(index + 1) / Double(total)
                await MainActor.run { self.progress = value }
            }

            let report = ConversionReport(
                converted: converted, copied: copied, failed: failed,
                warnings: warned, renamed: renamed, outputDirectory: outDir
            )
            await MainActor.run {
                self.isConverting = false
                self.lastReport = report
                self.maybeRequestReview(report: report)
                if report.converted + report.copied > 0 {
                    Telemetry.conversionFinished(rate: targetRate)
                }
            }
        }
    }

    func reset() {
        items = []
        lastReport = nil
        progress = 0
    }

    // MARK: - Review prompt

    private static let successfulConversionsKey = "successfulConversionCount"

    /// Ask at a couple of natural, well-spaced moments, never on the first success or at launch.
    /// StoreKit throttles further (about three times a year, and never if already reviewed).
    nonisolated static func shouldAskForReview(afterSuccessfulCount count: Int) -> Bool {
        count == 2 || count == 5
    }

    /// After a clean conversion, tick the success counter and trigger the review prompt at a milestone.
    private func maybeRequestReview(report: ConversionReport) {
        guard report.failed == 0, report.converted + report.copied > 0 else { return }
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: Self.successfulConversionsKey) + 1
        defaults.set(count, forKey: Self.successfulConversionsKey)
        if Self.shouldAskForReview(afterSuccessfulCount: count) {
            requestReviewTrigger += 1
        }
    }

    /// Return a destination that doesn't collide with one already used this run, appending
    /// " (2)", " (3)", … Comparison is case-insensitive to match the SD card's filesystem.
    private nonisolated static func uniqueDestination(_ url: URL, used: inout Set<String>) -> URL {
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var candidate = url
        var n = 2
        while used.contains(candidate.path.lowercased()) {
            let name = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            candidate = dir.appendingPathComponent(name)
            n += 1
        }
        used.insert(candidate.path.lowercased())
        return candidate
    }

    /// Populate the list with representative mock data for screenshots/demos.
    /// Triggered by the `-DemoMode` launch argument; never used in normal operation.
    func seedDemoData() {
        items = Self.demoItems()
        outputDirectory = URL(fileURLWithPath: "/Users/jarl/Desktop/SP-404 Ready")
    }

    /// The report a real conversion of `items` would produce (no renames, nothing failing).
    nonisolated static func demoReport(for items: [AudioFileItem], outputDirectory: URL) -> ConversionReport {
        ConversionReport(
            converted: items.filter(\.willConvert).count,
            copied: items.filter { $0.status == .compatible }.count,
            failed: items.filter { if case .unreadable = $0.status { return true }; return false }.count,
            warnings: items.filter { !$0.warnings.isEmpty }.count,
            outputDirectory: outputDirectory
        )
    }

    /// The demo pack used for screenshots. Each file is described by its decoded format only; its
    /// status and warnings come from the real `AudioFormatInspector`, so every label in a screenshot
    /// is one the app actually produces for that file (#65). Hand-written labels drifted before.
    nonisolated static func demoItems() -> [AudioFileItem] {
        func p(_ sr: Double, _ ch: UInt32, _ bits: UInt32, float: Bool, pcm: Bool, mp3: Bool, _ dur: Double,
               codec: String? = nil) -> AudioProperties {
            AudioProperties(sampleRate: sr, channels: ch, bitsPerChannel: bits,
                            isFloat: float, isLinearPCM: pcm, isMP3: mp3, durationSeconds: dur, codec: codec)
        }
        let files: [(String, AudioProperties)] = [
            ("Kick_01.wav",     p(44100, 2, 16, float: false, pcm: true,  mp3: false, 1.1)),
            ("Snare_punch.wav", p(96000, 2, 32, float: true,  pcm: true,  mp3: false, 0.8)),
            ("Vox_chop.flac",   p(48000, 2, 24, float: false, pcm: false, mp3: false, 2.4, codec: "FLAC")),
            ("Riser_fx.mp3",    p(44100, 2,  0, float: false, pcm: false, mp3: true,  3.0, codec: "MP3")),
            ("Texture_pad.wav", p(88200, 1, 32, float: true,  pcm: true,  mp3: false, 17 * 60 + 4)),
            ("Hat_closed.aif",  p(48000, 1, 16, float: false, pcm: true,  mp3: false, 0.3)),
        ]
        return files.map { name, props in
            let url = URL(fileURLWithPath: "/Samples/DemoPack/\(name)")
            return AudioFileItem(
                url: url,
                relativePath: "DemoPack/\(name)",
                properties: props,
                status: AudioFormatInspector.classify(props, ext: url.pathExtension),
                warnings: AudioFormatInspector.warnings(for: props)
            )
        }
    }

    /// A whole pack for the "drop the whole pack" screenshot: 18 files in the formats a pack really
    /// arrives in, labelled by the real `AudioFormatInspector` like `demoItems()`.
    func seedDemoPack() {
        items = Self.demoPackItems()
        outputDirectory = URL(fileURLWithPath: "/Users/jarl/Desktop/SP-404 Ready")
    }

    nonisolated static func demoPackItems() -> [AudioFileItem] {
        func p(_ sr: Double, _ ch: UInt32, _ bits: UInt32, float: Bool = false, pcm: Bool = true,
               codec: String? = nil, _ dur: Double) -> AudioProperties {
            AudioProperties(sampleRate: sr, channels: ch, bitsPerChannel: bits, isFloat: float,
                            isLinearPCM: pcm, isMP3: codec == "MP3", durationSeconds: dur, codec: codec)
        }
        let files: [(String, AudioProperties)] = [
            ("Drums/Kick_boom.wav",       p(44100, 2, 24, 1.2)),
            ("Drums/Kick_tight.wav",      p(44100, 1, 16, 0.6)),
            ("Drums/Snare_crack.wav",     p(48000, 2, 32, float: true, 0.9)),
            ("Drums/Snare_rim.aif",       p(48000, 1, 16, 0.4)),
            ("Drums/Hat_open.wav",        p(96000, 2, 24, 1.0)),
            ("Drums/Clap_room.flac",      p(44100, 2, 16, pcm: false, codec: "FLAC", 1.1)),
            ("Drums/Shaker_loop.caf",     p(48000, 2, 16, 4.0)),
            ("Loops/Keys_85bpm.m4a",      p(44100, 2, 0, pcm: false, codec: "AAC", 11.3)),
            ("Loops/Chop_soul_01.wav",    p(48000, 2, 16, 5.6)),
            ("Loops/Pad_warm.aiff",       p(88200, 2, 24, 9.4)),
            ("Loops/Bass_sub_C.wav",      p(44100, 1, 32, float: true, 2.1)),
            ("Loops/Chop_soul_02.wav",    p(48000, 2, 16, 4.8)),
            ("Vox/Vox_hook.mp3",          p(44100, 2, 0, pcm: false, codec: "MP3", 3.2)),
            ("Vox/Vox_adlib.wav",         p(48000, 1, 24, 1.6)),
            ("FX/Tape_stop.wav",          p(96000, 2, 32, float: true, 1.8)),
            ("FX/Riser_long.wav",         p(44100, 2, 16, 6.0)),
            ("FX/Vinyl_noise.wav",        p(44100, 2, 16, 12.0)),
            ("FX/Impact_low.wav",         p(48000, 2, 24, 2.2)),
        ]
        return files.map { relative, props in
            let url = URL(fileURLWithPath: "/Samples/Dusty Keys Kit/\(relative)")
            return AudioFileItem(
                url: url,
                relativePath: "Dusty Keys Kit/\(relative)",
                properties: props,
                status: AudioFormatInspector.classify(props, ext: url.pathExtension),
                warnings: AudioFormatInspector.warnings(for: props)
            )
        }
    }

    /// Seed a finished-conversion report on top of the demo data (for the "done" screenshot).
    func seedDemoReport() {
        let dir = outputDirectory ?? URL(fileURLWithPath: "/Users/jarl/Desktop/SP-404 Ready")
        lastReport = Self.demoReport(for: items, outputDirectory: dir)
    }
}
