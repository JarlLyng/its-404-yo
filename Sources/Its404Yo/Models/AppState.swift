import Foundation
import SwiftUI

/// Owns the app's working state: the analyzed files, settings, progress and the result report.
@MainActor
final class AppState: ObservableObject {
    @Published var items: [AudioFileItem] = []
    @Published var settings = ConversionSettings()
    @Published var outputDirectory: URL?
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
    var canConvert: Bool { !items.isEmpty && outputDirectory != nil && !isConverting && !isAnalyzing }

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
        let rate = self.settings.targetSampleRate.rawValue
        isConverting = true
        progress = 0

        Task.detached(priority: .userInitiated) {
            var converted = 0, copied = 0, failed = 0, warned = 0
            let total = max(1, items.count)

            for (index, item) in items.enumerated() {
                let destination = outDir.appendingPathComponent(item.relativePath)
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
                        let wavDestination = destination.deletingPathExtension().appendingPathExtension("wav")
                        try AudioConverter.convert(source: item.url, destination: wavDestination, targetSampleRate: rate)
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
                warnings: warned, outputDirectory: outDir
            )
            await MainActor.run {
                self.isConverting = false
                self.lastReport = report
                self.maybeRequestReview(report: report)
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

    /// Populate the list with representative mock data for screenshots/demos.
    /// Triggered by the `-DemoMode` launch argument; never used in normal operation.
    func seedDemoData() {
        func item(_ name: String, _ props: AudioProperties, _ status: FileStatus, _ warnings: [String] = []) -> AudioFileItem {
            AudioFileItem(
                url: URL(fileURLWithPath: "/Samples/DemoPack/\(name)"),
                relativePath: "DemoPack/\(name)",
                properties: props, status: status, warnings: warnings
            )
        }
        func p(_ sr: Double, _ ch: UInt32, _ bits: UInt32, float: Bool, pcm: Bool, mp3: Bool, _ dur: Double) -> AudioProperties {
            AudioProperties(sampleRate: sr, channels: ch, bitsPerChannel: bits,
                            isFloat: float, isLinearPCM: pcm, isMP3: mp3, durationSeconds: dur)
        }

        items = [
            item("Kick_01.wav",     p(44100, 2, 16, float: false, pcm: true,  mp3: false, 1.1), .compatible),
            item("Snare_punch.wav", p(96000, 2, 32, float: true,  pcm: true,  mp3: false, 0.8),
                 .needsConversion(["32-bit float → 16-bit", "96 kHz resampled"])),
            item("Vox_chop.flac",   p(48000, 2, 24, float: false, pcm: false, mp3: false, 2.4),
                 .needsConversion(["24-bit → 16-bit", "FLAC → WAV"])),
            item("Riser_fx.mp3",    p(44100, 2,  0, float: false, pcm: false, mp3: true,  3.0), .compatible),
            item("Texture_pad.wav", p(88200, 1, 32, float: true,  pcm: true,  mp3: false, 17 * 60 + 4),
                 .needsConversion(["32-bit float → 16-bit", "88.2 kHz resampled"]),
                 ["Over 16 min — exceeds SP-404 limit"]),
            item("Hat_closed.aif",  p(48000, 1, 16, float: false, pcm: true,  mp3: false, 0.3), .compatible)
        ]
        outputDirectory = URL(fileURLWithPath: "/Users/jarl/Desktop/SP-404 Ready")
    }

    /// Seed a finished-conversion report on top of the demo data (for the "done" screenshot).
    func seedDemoReport() {
        let dir = outputDirectory ?? URL(fileURLWithPath: "/Users/jarl/Desktop/SP-404 Ready")
        lastReport = ConversionReport(converted: 3, copied: 3, failed: 0, warnings: 1, outputDirectory: dir)
    }
}
