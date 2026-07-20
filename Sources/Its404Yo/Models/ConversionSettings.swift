import Foundation

/// User-adjustable conversion options.
struct ConversionSettings: Equatable {

    /// Output sample rate. 48 kHz matches the SP-404 MkII's internal rate (zero on-device
    /// resampling); 44.1 kHz is also accepted and resampled on-device.
    enum TargetSampleRate: Double, CaseIterable, Identifiable {
        case fortyEight = 48000
        case fortyFourOne = 44100

        var id: Double { rawValue }

        var label: String {
            switch self {
            case .fortyEight: return "48 kHz (recommended)"
            case .fortyFourOne: return "44.1 kHz"
            }
        }
    }

    var targetSampleRate: TargetSampleRate = .fortyEight

    /// Rewrite output file names to a safe subset for SD-card import (off by default).
    /// See `FilenameSanitizer`.
    var sanitizeFilenames: Bool = false
}
