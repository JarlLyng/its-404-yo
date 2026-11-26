import AVFoundation
import AudioToolbox
import XCTest
@testable import Its404Yo

/// A compressed file's format has no bit depth (`mBitsPerChannel` is 0), and FLAC and Apple
/// Lossless keep the source depth in format flags whose low bit is the PCM "is float" flag. Read as
/// PCM, every real FLAC and ALAC file showed "0-bit float → 16-bit" and an AAC file "0-bit".
final class CompressedFormatTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String, format: AudioFormatID, bitDepth: Int? = nil) throws -> URL {
        let url = dir.appendingPathComponent(name)
        var settings: [String: Any] = [AVFormatIDKey: format, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2]
        if let bitDepth { settings[AVEncoderBitDepthHintKey] = bitDepth }
        let source = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: 4800)!
        buffer.frameLength = 4800
        for channel in 0..<2 {
            for i in 0..<4800 { buffer.floatChannelData![channel][i] = sin(Float(i) * 0.05) * 0.5 }
        }
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
        return url
    }

    func testFlacReadsItsSourceDepthAndIsNotFloat() throws {
        let url = try write("vox.flac", format: kAudioFormatFLAC, bitDepth: 24)
        let props = try XCTUnwrap(AudioFormatInspector.readProperties(url: url))

        XCTAssertEqual(props.codec, "FLAC")
        XCTAssertEqual(props.bitsPerChannel, 24)
        XCTAssertFalse(props.isFloat)
        XCTAssertEqual(AudioFormatInspector.classify(props, ext: "flac"), .needsConversion(["FLAC → WAV"]))
        XCTAssertEqual(AudioFormatInspector.detail(for: props), "FLAC · 24-bit · 48 kHz · stereo")
    }

    func testAppleLosslessReadsItsSourceDepthAndIsNotFloat() throws {
        let url = try write("pad.m4a", format: kAudioFormatAppleLossless, bitDepth: 24)
        let props = try XCTUnwrap(AudioFormatInspector.readProperties(url: url))

        XCTAssertEqual(props.codec, "ALAC")
        XCTAssertEqual(props.bitsPerChannel, 24)
        XCTAssertFalse(props.isFloat)
        XCTAssertEqual(AudioFormatInspector.classify(props, ext: "m4a"), .needsConversion(["M4A → WAV"]))
        XCTAssertEqual(AudioFormatInspector.detail(for: props), "ALAC · 24-bit · 48 kHz · stereo")
    }

    func testAACHasNoDepthInItsDetail() throws {
        let url = try write("loop.m4a", format: kAudioFormatMPEG4AAC)
        let props = try XCTUnwrap(AudioFormatInspector.readProperties(url: url))

        XCTAssertEqual(props.codec, "AAC")
        XCTAssertFalse(props.isFloat)
        XCTAssertEqual(AudioFormatInspector.classify(props, ext: "m4a"), .needsConversion(["M4A → WAV"]))
        XCTAssertEqual(AudioFormatInspector.detail(for: props), "AAC · 48 kHz · stereo")
    }

    func testDetailLineForPCMAndMP3IsUnchanged() {
        func p(_ bits: UInt32, float: Bool = false, mp3: Bool = false, codec: String? = nil, ch: UInt32 = 2) -> AudioProperties {
            AudioProperties(sampleRate: 44100, channels: ch, bitsPerChannel: bits, isFloat: float,
                            isLinearPCM: !mp3 && codec == nil, isMP3: mp3, durationSeconds: 1, codec: codec)
        }
        XCTAssertEqual(AudioFormatInspector.detail(for: p(16)), "16-bit · 44.1 kHz · stereo")
        XCTAssertEqual(AudioFormatInspector.detail(for: p(32, float: true, ch: 1)), "32-bit float · 44.1 kHz · mono")
        XCTAssertEqual(AudioFormatInspector.detail(for: p(0, mp3: true)), "MP3 · 44.1 kHz · stereo")
        XCTAssertEqual(AudioFormatInspector.detail(for: p(0, mp3: true, codec: "MP3")), "MP3 · 44.1 kHz · stereo")
        XCTAssertFalse(AudioFormatInspector.detail(for: p(0, codec: "AAC")).contains("0-bit"))
    }

    func testOtherCodecsAreNamedByTheirCode() {
        XCTAssertNil(AudioFormatInspector.codecName(kAudioFormatLinearPCM))
        XCTAssertEqual(AudioFormatInspector.codecName(kAudioFormatAppleIMA4), "IMA4")
        XCTAssertEqual(AudioFormatInspector.codecName(kAudioFormatULaw), "ULAW")
        XCTAssertEqual(AudioFormatInspector.codecName(kAudioFormatMPEG4AAC_HE), "AAC")
    }
}
