import Foundation
import AudioToolbox

/// Errors thrown while converting an audio file to the SP-404 MkII-safe format.
enum ConversionError: Error, LocalizedError {
    case openFailed(OSStatus)
    case createOutputFailed(OSStatus)
    case propertyFailed(OSStatus)
    case readFailed(OSStatus)
    case writeFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .openFailed(let s): return "Could not open the source file (status \(s))."
        case .createOutputFailed(let s): return "Could not create the output file (status \(s))."
        case .propertyFailed(let s): return "Could not read/set an audio property (status \(s))."
        case .readFailed(let s): return "Could not read audio data (status \(s))."
        case .writeFailed(let s): return "Could not write audio data (status \(s))."
        }
    }
}

/// Converts any Core Audio-readable file (WAV/AIFF/MP3/M4A/AAC/ALAC/FLAC/CAF) into a
/// clean, canonical **16-bit linear PCM WAV** at 44.1 or 48 kHz, preserving the source
/// channel count.
///
/// This is the documented "safe target" for SP-404 MkII SD-card import and resolves the
/// overwhelming majority of "Unsupported File" errors (32-bit float, odd bit depths, odd
/// sample rates). Re-muxing to a fresh WAV also drops exotic / BWF / extra RIFF chunks.
enum AudioConverter {

    /// Convert `source` into a 16-bit PCM WAV at `targetSampleRate`, written to `destination`.
    /// - Parameters:
    ///   - source: any Core Audio-readable audio file.
    ///   - destination: output URL; should end in `.wav`. Overwritten if it exists.
    ///   - targetSampleRate: 44100 or 48000.
    static func convert(source: URL, destination: URL, targetSampleRate: Double) throws {
        // 1. Open the source file.
        var optSource: ExtAudioFileRef?
        var status = ExtAudioFileOpenURL(source as CFURL, &optSource)
        guard status == noErr, let sourceFile = optSource else {
            throw ConversionError.openFailed(status)
        }
        defer { ExtAudioFileDispose(sourceFile) }

        // 2. Read the source's on-disk format to learn the channel count.
        var sourceFormat = AudioStreamBasicDescription()
        var fmtSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &fmtSize, &sourceFormat)
        guard status == noErr else { throw ConversionError.propertyFailed(status) }

        let channels = max(1, sourceFormat.mChannelsPerFrame)

        // 3. Build the canonical 16-bit signed-integer interleaved PCM format.
        var pcm = AudioFormat.int16PCM(sampleRate: targetSampleRate, channels: channels)
        let asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        // 4. Tell the source to hand us frames already converted (sample-rate + bit-depth) to PCM.
        status = ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &pcm)
        guard status == noErr else { throw ConversionError.propertyFailed(status) }

        // 5. Create the destination WAV with the same 16-bit PCM format on disk.
        try? FileManager.default.removeItem(at: destination)
        var optOutput: ExtAudioFileRef?
        status = ExtAudioFileCreateWithURL(
            destination as CFURL,
            kAudioFileWAVEType,
            &pcm,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &optOutput
        )
        guard status == noErr, let outputFile = optOutput else {
            throw ConversionError.createOutputFailed(status)
        }
        defer { ExtAudioFileDispose(outputFile) }

        status = ExtAudioFileSetProperty(outputFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &pcm)
        guard status == noErr else { throw ConversionError.propertyFailed(status) }

        // 6. Stream frames source -> destination.
        let framesPerChunk: UInt32 = 8192
        let bufferByteSize = framesPerChunk * pcm.mBytesPerFrame
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(bufferByteSize),
            alignment: MemoryLayout<Int16>.alignment
        )
        defer { buffer.deallocate() }

        while true {
            var bufferList = AudioBufferList()
            bufferList.mNumberBuffers = 1
            bufferList.mBuffers.mNumberChannels = channels
            bufferList.mBuffers.mDataByteSize = bufferByteSize
            bufferList.mBuffers.mData = buffer

            var frameCount = framesPerChunk
            status = ExtAudioFileRead(sourceFile, &frameCount, &bufferList)
            guard status == noErr else { throw ConversionError.readFailed(status) }
            if frameCount == 0 { break } // EOF

            status = ExtAudioFileWrite(outputFile, frameCount, &bufferList)
            guard status == noErr else { throw ConversionError.writeFailed(status) }
        }
    }
}
