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

    func testDemoReportMatchesTheItems() {
        let report = AppState.demoReport(for: AppState.demoItems(), outputDirectory: URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(report.converted, 3)
        XCTAssertEqual(report.copied, 3)
        XCTAssertEqual(report.failed, 0)
        XCTAssertEqual(report.warnings, 1)
    }
}
