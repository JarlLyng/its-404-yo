import XCTest
@testable import Its404Yo

/// Screenshots come from the demo data, so the demo must show only what the app really shows (#65).
final class DemoDataTests: XCTestCase {

    func testEveryDemoLabelIsWhatTheInspectorProduces() {
        for item in AppState.demoItems() {
            guard let props = item.properties else { return XCTFail("\(item.fileName) has no format") }
            XCTAssertEqual(item.status, AudioFormatInspector.classify(props, ext: item.url.pathExtension), item.fileName)
            XCTAssertEqual(item.warnings, AudioFormatInspector.warnings(for: props), item.fileName)
        }
    }

    /// The two labels the old hand-written demo got wrong.
    func testFlacRowAndLongFileWarning() {
        let items = Dictionary(uniqueKeysWithValues: AppState.demoItems().map { ($0.fileName, $0) })
        XCTAssertEqual(items["Vox_chop.flac"]?.status, .needsConversion(["FLAC → WAV"]))
        // What the row reads for a real 24-bit FLAC file (CompressedFormatTests), not "0-bit float".
        XCTAssertEqual(items["Vox_chop.flac"]?.properties.map(AudioFormatInspector.detail(for:)),
                       "FLAC · 24-bit · 48 kHz · stereo")
        let pad = items["Texture_pad.wav"]?.warnings ?? []
        XCTAssertEqual(pad, ["Over 16 min, may exceed the SP-404 limit"])
        XCTAssertFalse(pad.joined().contains("—"))
    }

    /// The demo should show every kind of row: copied, converted, and one with a warning.
    func testDemoCoversEachRowKind() {
        let items = AppState.demoItems()
        XCTAssertTrue(items.contains { $0.status == .compatible })
        XCTAssertTrue(items.contains { $0.willConvert })
        XCTAssertTrue(items.contains { !$0.warnings.isEmpty })
    }

    func testEveryDemoPackLabelIsWhatTheInspectorProduces() {
        let pack = AppState.demoPackItems()
        XCTAssertEqual(pack.count, 18)
        for item in pack {
            guard let props = item.properties else { return XCTFail("\(item.fileName) has no format") }
            XCTAssertEqual(item.status, AudioFormatInspector.classify(props, ext: item.url.pathExtension), item.fileName)
            XCTAssertEqual(item.warnings, AudioFormatInspector.warnings(for: props), item.fileName)
            XCTAssertFalse(AudioFormatInspector.detail(for: props).contains("0-bit"), item.fileName)
        }
        let byName = Dictionary(uniqueKeysWithValues: pack.map { ($0.fileName, $0) })
        XCTAssertEqual(byName["Shaker_loop.caf"]?.status, .needsConversion(["CAF → WAV"]))
        XCTAssertEqual(byName["Keys_85bpm.m4a"]?.status, .needsConversion(["M4A → WAV"]))
        XCTAssertEqual(byName["Vox_hook.mp3"]?.status, .compatible)
    }

    func testDemoWindowSize() {
        XCTAssertEqual(DemoWindow.size(from: ["-DemoMode"]), DemoWindow.defaultSize)
        XCTAssertEqual(DemoWindow.size(from: ["-DemoMode", "-DemoCompact"]), NSSize(width: 800, height: 560))
        // Within the window's minimum, 640×480.
        XCTAssertGreaterThanOrEqual(DemoWindow.compactSize.width, 640)
        XCTAssertGreaterThanOrEqual(DemoWindow.compactSize.height, 480)
    }

    func testDemoReportMatchesTheItems() {
        let report = AppState.demoReport(for: AppState.demoItems(), outputDirectory: URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(report.converted, 3)
        XCTAssertEqual(report.copied, 3)
        XCTAssertEqual(report.failed, 0)
        XCTAssertEqual(report.warnings, 1)
    }
}
