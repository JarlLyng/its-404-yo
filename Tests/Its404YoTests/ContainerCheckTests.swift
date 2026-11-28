import XCTest
import AVFoundation
@testable import Its404Yo

/// #68: "compatible" means copied with its own extension, so the container matters, not just the
/// decoded format. Only WAV/AIFF (for PCM) and .mp3 (for MP3) pass through untouched.
final class ContainerCheckTests: XCTestCase {

    private func pcm16(_ rate: Double = 48000) -> AudioProperties {
        AudioProperties(sampleRate: rate, channels: 2, bitsPerChannel: 16,
                        isFloat: false, isLinearPCM: true, isMP3: false, durationSeconds: 1)
    }

    func testSixteenBitPCMInWavOrAiffPassesThrough() {
        for ext in ["wav", "wave", "aif", "aiff", "WAV", "Aiff"] {
            XCTAssertEqual(AudioFormatInspector.classify(pcm16(), ext: ext), .compatible, ext)
        }
    }

    func testSixteenBitPCMInOtherContainersIsConverted() {
        XCTAssertEqual(AudioFormatInspector.classify(pcm16(), ext: "caf"), .needsConversion(["CAF → WAV"]))
        XCTAssertEqual(AudioFormatInspector.classify(pcm16(44100), ext: "aifc"), .needsConversion(["AIFC → WAV"]))
    }

    func testOtherReasonsStillShowAlongsideTheContainer() {
        let float96 = AudioProperties(sampleRate: 96000, channels: 2, bitsPerChannel: 32,
                                      isFloat: true, isLinearPCM: true, isMP3: false, durationSeconds: 1)
        XCTAssertEqual(AudioFormatInspector.classify(float96, ext: "caf"),
                       .needsConversion(["32-bit float → 16-bit", "96 kHz resampled", "CAF → WAV"]))
        // Unchanged: a float WAV gets no container reason.
        XCTAssertEqual(AudioFormatInspector.classify(float96, ext: "wav"),
                       .needsConversion(["32-bit float → 16-bit", "96 kHz resampled"]))
    }

    func testMP3PassesThroughOnlyAsAnMP3File() {
        let mp3 = AudioProperties(sampleRate: 44100, channels: 2, bitsPerChannel: 0,
                                  isFloat: false, isLinearPCM: false, isMP3: true, durationSeconds: 1)
        XCTAssertEqual(AudioFormatInspector.classify(mp3, ext: "mp3"), .compatible)
        XCTAssertEqual(AudioFormatInspector.classify(mp3, ext: "MP3"), .compatible)
        XCTAssertEqual(AudioFormatInspector.classify(mp3, ext: "caf"), .needsConversion(["CAF → WAV"]))
    }

    /// The reported case, end to end: a real 16-bit 48 kHz CAF is analysed as needing conversion,
    /// and converting it gives a 16-bit WAV.
    func testRealSixteenBitCAFIsConvertedNotCopied() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("its404yo-caf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let caf = dir.appendingPathComponent("hit.caf")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(forWriting: caf, settings: settings)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4800))
        buffer.frameLength = 4800
        try file.write(from: buffer)

        let props = try XCTUnwrap(AudioFormatInspector.readProperties(url: caf))
        XCTAssertTrue(props.isLinearPCM)
        XCTAssertEqual(props.bitsPerChannel, 16)   // the shape that used to be copied as .caf

        let item = AudioFormatInspector.analyze(file: ScannedFile(url: caf, relativePath: "hit.caf"))
        XCTAssertEqual(item.status, .needsConversion(["CAF → WAV"]))

        let out = dir.appendingPathComponent("hit.wav")
        try AudioConverter.convert(source: caf, destination: out, targetSampleRate: 48000)
        let converted = try XCTUnwrap(AudioFormatInspector.readProperties(url: out))
        XCTAssertEqual(converted.bitsPerChannel, 16)
        XCTAssertEqual(converted.sampleRate, 48000, accuracy: 0.5)
    }
}
