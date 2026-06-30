import XCTest
@testable import Its404Yo

final class AudioFormatInspectorTests: XCTestCase {

    func testSixteenBitWavAt48kIsCompatible() {
        let props = AudioProperties(
            sampleRate: 48000, channels: 2, bitsPerChannel: 16,
            isFloat: false, isLinearPCM: true, isMP3: false, durationSeconds: 1
        )
        XCTAssertEqual(AudioFormatInspector.classify(props, ext: "wav"), .compatible)
    }

    func testSixteenBitWavAt44kIsCompatible() {
        let props = AudioProperties(
            sampleRate: 44100, channels: 1, bitsPerChannel: 16,
            isFloat: false, isLinearPCM: true, isMP3: false, durationSeconds: 1
        )
        XCTAssertEqual(AudioFormatInspector.classify(props, ext: "wav"), .compatible)
    }

    func testThirtyTwoBitFloatNeedsConversion() {
        let props = AudioProperties(
            sampleRate: 96000, channels: 2, bitsPerChannel: 32,
            isFloat: true, isLinearPCM: true, isMP3: false, durationSeconds: 1
        )
        guard case let .needsConversion(reasons) = AudioFormatInspector.classify(props, ext: "wav") else {
            return XCTFail("Expected needsConversion")
        }
        XCTAssertTrue(reasons.contains { $0.contains("float") })
        XCTAssertTrue(reasons.contains { $0.contains("resampled") })
    }

    func testFlacNeedsConversion() {
        let props = AudioProperties(
            sampleRate: 44100, channels: 2, bitsPerChannel: 16,
            isFloat: false, isLinearPCM: false, isMP3: false, durationSeconds: 1
        )
        guard case let .needsConversion(reasons) = AudioFormatInspector.classify(props, ext: "flac") else {
            return XCTFail("Expected needsConversion")
        }
        XCTAssertTrue(reasons.contains { $0.contains("WAV") })
    }

    func testMP3IsCompatible() {
        let props = AudioProperties(
            sampleRate: 44100, channels: 2, bitsPerChannel: 0,
            isFloat: false, isLinearPCM: false, isMP3: true, durationSeconds: 1
        )
        XCTAssertEqual(AudioFormatInspector.classify(props, ext: "mp3"), .compatible)
    }

    func testLongFileWarns() {
        let props = AudioProperties(
            sampleRate: 48000, channels: 2, bitsPerChannel: 16,
            isFloat: false, isLinearPCM: true, isMP3: false, durationSeconds: 17 * 60
        )
        XCTAssertTrue(AudioFormatInspector.warnings(for: props).contains { $0.contains("16 min") })
    }

    func testKHzFormatting() {
        XCTAssertEqual(AudioFormatInspector.formatKHz(48000), "48")
        XCTAssertEqual(AudioFormatInspector.formatKHz(44100), "44.1")
    }
}
