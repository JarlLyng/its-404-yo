import XCTest
import AVFoundation
import AudioToolbox
@testable import Its404Yo

final class AudioConverterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("its404yo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// A 32-bit float, 96 kHz WAV (the classic "Unsupported File" case) must come out
    /// as 16-bit linear PCM at the requested rate, with channels preserved.
    func testConvertsFloat96kToInt16At48k() throws {
        let source = try makeFloat32WAV(sampleRate: 96000, channels: 1, seconds: 0.5)
        let destination = tempDir.appendingPathComponent("out.wav")

        try AudioConverter.convert(source: source, destination: destination, targetSampleRate: 48000)

        let props = try XCTUnwrap(AudioFormatInspector.readProperties(url: destination))
        XCTAssertEqual(props.sampleRate, 48000, accuracy: 0.5)
        XCTAssertEqual(props.bitsPerChannel, 16)
        XCTAssertFalse(props.isFloat)
        XCTAssertTrue(props.isLinearPCM)
        XCTAssertEqual(props.channels, 1)
    }

    /// Stereo channel count must be preserved through conversion.
    func testPreservesStereoChannels() throws {
        let source = try makeFloat32WAV(sampleRate: 44100, channels: 2, seconds: 0.25)
        let destination = tempDir.appendingPathComponent("stereo.wav")

        try AudioConverter.convert(source: source, destination: destination, targetSampleRate: 44100)

        let props = try XCTUnwrap(AudioFormatInspector.readProperties(url: destination))
        XCTAssertEqual(props.channels, 2)
        XCTAssertEqual(props.bitsPerChannel, 16)
    }

    // MARK: - Helpers

    /// Write a short sine tone as a 32-bit float WAV (off-spec for the SP-404).
    private func makeFloat32WAV(sampleRate: Double, channels: AVAudioChannelCount, seconds: Double) throws -> URL {
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ))
        let url = tempDir.appendingPathComponent("src-\(Int(sampleRate))-\(channels).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frames = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames

        for channel in 0..<Int(channels) {
            let samples = buffer.floatChannelData![channel]
            for frame in 0..<Int(frames) {
                samples[frame] = sinf(2.0 * .pi * 440.0 * Float(frame) / Float(sampleRate)) * 0.5
            }
        }
        try file.write(from: buffer)
        return url
    }
}
