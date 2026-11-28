import Foundation
import AudioToolbox

/// Helpers for building the canonical SP-404 MkII-safe audio stream format.
enum AudioFormat {

    /// Sample rates the SP-404 MkII accepts directly (44.1 kHz is resampled to 48 kHz on-device).
    static let safeSampleRates: Set<Double> = [44100, 48000]

    /// Containers SD-card import takes for linear PCM: WAV and AIFF, as Roland states the rule
    /// ("16-bit linear, WAV/AIFF/MP3"). 16-bit PCM in any other container (CAF, AIFF-C) is converted,
    /// because a file is copied with its own extension and the card would see e.g. a `.caf`.
    static let pcmPassThroughExtensions: Set<String> = ["wav", "wave", "aif", "aiff"]

    /// An MP3 stream is only copied as-is when it is an `.mp3` file.
    static let mp3PassThroughExtensions: Set<String> = ["mp3"]

    /// Canonical 16-bit signed-integer, packed, interleaved linear PCM.
    static func int16PCM(sampleRate: Double, channels: UInt32) -> AudioStreamBasicDescription {
        let bytesPerSample = UInt32(MemoryLayout<Int16>.size)
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = sampleRate
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        asbd.mBitsPerChannel = 16
        asbd.mChannelsPerFrame = channels
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerFrame = bytesPerSample * channels
        asbd.mBytesPerPacket = bytesPerSample * channels
        return asbd
    }
}
