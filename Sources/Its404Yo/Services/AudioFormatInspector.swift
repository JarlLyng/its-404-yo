import Foundation
import AudioToolbox

/// The decoded format facts about a single audio file.
struct AudioProperties: Equatable {
    var sampleRate: Double
    var channels: UInt32
    var bitsPerChannel: UInt32
    var isFloat: Bool
    var isLinearPCM: Bool
    var isMP3: Bool
    var durationSeconds: Double
}

/// Reads an audio file's format and decides whether it is already SP-404 MkII-compatible
/// or needs conversion, producing human-readable reasons and warnings.
enum AudioFormatInspector {

    private static let maxDuration: Double = 16 * 60      // 16 minutes
    private static let maxBytes: Double = 185 * 1_000_000 // ~185 MB per sample
    private static let minDuration: Double = 0.1          // 100 ms

    /// Analyze a scanned file into a display item.
    static func analyze(file: ScannedFile) -> AudioFileItem {
        guard let props = readProperties(url: file.url) else {
            return AudioFileItem(
                url: file.url,
                relativePath: file.relativePath,
                properties: nil,
                status: .unreadable("Not a readable audio file"),
                warnings: []
            )
        }

        let status = classify(props, ext: file.url.pathExtension)
        let warnings = warnings(for: props)

        return AudioFileItem(
            url: file.url,
            relativePath: file.relativePath,
            properties: props,
            status: status,
            warnings: warnings
        )
    }

    // MARK: - Classification

    static func classify(_ props: AudioProperties, ext: String) -> FileStatus {
        let rateOK = AudioFormat.safeSampleRates.contains(props.sampleRate)

        // MP3 is accepted by SD-card import as-is.
        if props.isMP3 { return .compatible }

        // 16-bit linear PCM (WAV or AIFF) at 44.1/48 kHz is accepted as-is.
        if props.isLinearPCM, !props.isFloat, props.bitsPerChannel == 16, rateOK {
            return .compatible
        }

        // Otherwise: build the list of what will change.
        var reasons: [String] = []
        if props.isFloat {
            reasons.append("\(props.bitsPerChannel)-bit float → 16-bit")
        } else if props.isLinearPCM, props.bitsPerChannel != 16 {
            reasons.append("\(props.bitsPerChannel)-bit → 16-bit")
        }
        if !rateOK {
            reasons.append("\(formatKHz(props.sampleRate)) kHz resampled")
        }
        if !props.isLinearPCM {
            reasons.append("\(ext.uppercased()) → WAV")
        }
        if reasons.isEmpty {
            reasons.append("→ 16-bit WAV")
        }
        return .needsConversion(reasons)
    }

    static func warnings(for props: AudioProperties) -> [String] {
        var w: [String] = []
        if props.durationSeconds > maxDuration {
            w.append("Over 16 min — exceeds SP-404 limit")
        }
        if props.durationSeconds < minDuration {
            w.append("Very short (<0.1s) — may fail to import")
        }
        // Estimated size of the 48 kHz/16-bit output.
        let estBytes = props.durationSeconds * 48000 * Double(max(1, props.channels)) * 2
        if estBytes > maxBytes {
            w.append("Over ~185 MB — exceeds SP-404 limit")
        }
        return w
    }

    // MARK: - Reading the format

    static func readProperties(url: URL) -> AudioProperties? {
        var optFile: ExtAudioFileRef?
        guard ExtAudioFileOpenURL(url as CFURL, &optFile) == noErr, let file = optFile else {
            return nil
        }
        defer { ExtAudioFileDispose(file) }

        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &asbd) == noErr else {
            return nil
        }

        var frames: Int64 = 0
        var framesSize = UInt32(MemoryLayout<Int64>.size)
        _ = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &framesSize, &frames)

        let duration = asbd.mSampleRate > 0 ? Double(frames) / asbd.mSampleRate : 0
        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0

        return AudioProperties(
            sampleRate: asbd.mSampleRate,
            channels: asbd.mChannelsPerFrame,
            bitsPerChannel: asbd.mBitsPerChannel,
            isFloat: isFloat,
            isLinearPCM: asbd.mFormatID == kAudioFormatLinearPCM,
            isMP3: asbd.mFormatID == kAudioFormatMPEGLayer3,
            durationSeconds: duration
        )
    }

    // MARK: - Formatting

    static func formatKHz(_ rate: Double) -> String {
        let khz = rate / 1000
        if khz == khz.rounded() {
            return String(Int(khz))
        }
        return String(format: "%.1f", khz)
    }
}
