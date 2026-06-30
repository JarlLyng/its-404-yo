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
            }
        }
    }

    func reset() {
        items = []
        lastReport = nil
        progress = 0
    }
}
