import Foundation
import AudioToolbox

/// Helpers for building the canonical SP-404 MkII-safe audio stream format.
enum AudioFormat {

    /// Sample rates the SP-404 MkII accepts directly (44.1 kHz is resampled to 48 kHz on-device).
    static let safeSampleRates: Set<Double> = [44100, 48000]

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
