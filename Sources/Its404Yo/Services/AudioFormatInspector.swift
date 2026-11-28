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
    /// The codec's name for a compressed file ("FLAC", "AAC", "ALAC", "MP3"); nil for linear PCM.
    var codec: String? = nil
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
        let ext = ext.lowercased()
        let rateOK = AudioFormat.safeSampleRates.contains(props.sampleRate)
        // Compatible files are copied with their own extension, so the container has to be one the
        // card reads, not just the decoded format (#68: a 16-bit CAF used to be copied as `.caf`).
        let pcmContainerOK = AudioFormat.pcmPassThroughExtensions.contains(ext)

        // An MP3 file is accepted by SD-card import as-is.
        if props.isMP3, AudioFormat.mp3PassThroughExtensions.contains(ext) { return .compatible }

        // 16-bit linear PCM in a WAV or AIFF file at 44.1/48 kHz is accepted as-is.
        if props.isLinearPCM, !props.isFloat, props.bitsPerChannel == 16, rateOK, pcmContainerOK {
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
        if !props.isLinearPCM || !pcmContainerOK {
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
            w.append("Over 16 min, may exceed the SP-404 limit")
        }
        if props.durationSeconds < minDuration {
            w.append("Very short (<0.1s), may fail to import")
        }
        // Estimated size of the 48 kHz/16-bit output.
        let estBytes = props.durationSeconds * 48000 * Double(max(1, props.channels)) * 2
        if estBytes > maxBytes {
            w.append("Over ~185 MB, may exceed the SP-404 limit")
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
        let isLinearPCM = asbd.mFormatID == kAudioFormatLinearPCM
        let isFloat = isLinearPCM && (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0

        return AudioProperties(
            sampleRate: asbd.mSampleRate,
            channels: asbd.mChannelsPerFrame,
            bitsPerChannel: bitsPerChannel(asbd),
            isFloat: isFloat,
            isLinearPCM: isLinearPCM,
            isMP3: asbd.mFormatID == kAudioFormatMPEGLayer3,
            durationSeconds: duration,
            codec: codecName(asbd.mFormatID)
        )
    }

    /// A compressed file's format carries no bit depth (`mBitsPerChannel` is 0), so the row used to
    /// read "0-bit". FLAC and Apple Lossless keep the source's depth in their format flags instead.
    static func bitsPerChannel(_ asbd: AudioStreamBasicDescription) -> UInt32 {
        if asbd.mBitsPerChannel > 0 { return asbd.mBitsPerChannel }
        guard asbd.mFormatID == kAudioFormatFLAC || asbd.mFormatID == kAudioFormatAppleLossless else { return 0 }
        switch asbd.mFormatFlags {
        case kAppleLosslessFormatFlag_16BitSourceData: return 16
        case kAppleLosslessFormatFlag_20BitSourceData: return 20
        case kAppleLosslessFormatFlag_24BitSourceData: return 24
        case kAppleLosslessFormatFlag_32BitSourceData: return 32
        default: return 0
        }
    }

    static func codecName(_ formatID: AudioFormatID) -> String? {
        switch formatID {
        case kAudioFormatLinearPCM: return nil
        case kAudioFormatMPEGLayer3: return "MP3"
        case kAudioFormatFLAC: return "FLAC"
        case kAudioFormatAppleLossless: return "ALAC"
        case kAudioFormatMPEG4AAC, kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2,
             kAudioFormatMPEG4AAC_LD, kAudioFormatMPEG4AAC_ELD:
            return "AAC"
        default:
            // Anything else a CAF can hold (IMA4, µ-law, …): its four-character code.
            let bytes = withUnsafeBytes(of: formatID.bigEndian) { Array($0) }
            let code = String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
            return code.isEmpty ? nil : code.uppercased()
        }
    }

    // MARK: - Formatting

    /// The row's detail line: "24-bit · 48 kHz · stereo", "32-bit float · 96 kHz · stereo",
    /// "FLAC · 24-bit · 48 kHz · stereo", "AAC · 44.1 kHz · stereo". A depth is shown only when the
    /// file has one, never "0-bit".
    static func detail(for p: AudioProperties) -> String {
        var parts: [String] = []
        if let codec = p.codec ?? (p.isMP3 ? "MP3" : nil) { parts.append(codec) }
        if p.bitsPerChannel > 0, !p.isMP3 {
            parts.append(p.isFloat ? "\(p.bitsPerChannel)-bit float" : "\(p.bitsPerChannel)-bit")
        }
        parts.append("\(formatKHz(p.sampleRate)) kHz")
        parts.append(p.channels == 1 ? "mono" : (p.channels == 2 ? "stereo" : "\(p.channels)ch"))
        return parts.joined(separator: " · ")
    }

    static func formatKHz(_ rate: Double) -> String {
        let khz = rate / 1000
        if khz == khz.rounded() {
            return String(Int(khz))
        }
        return String(format: "%.1f", khz)
    }
}
