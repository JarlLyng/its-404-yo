import Foundation

/// The SP-404 compatibility verdict for one file.
enum FileStatus: Equatable {
    /// Already accepted by SD-card import — will be copied unchanged.
    case compatible
    /// Will be converted; the strings explain what changes (in plain language).
    case needsConversion([String])
    /// Could not be read as audio.
    case unreadable(String)
}

/// One row in the analysis list.
struct AudioFileItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let relativePath: String
    let properties: AudioProperties?
    let status: FileStatus
    let warnings: [String]

    var willConvert: Bool {
        if case .needsConversion = status { return true }
        return false
    }

    var fileName: String { url.lastPathComponent }
}

/// Aggregate outcome shown after a conversion run.
struct ConversionReport: Equatable {
    var converted: Int
    var copied: Int
    var failed: Int
    var warnings: Int
    var renamed: Int = 0
    var outputDirectory: URL

    var total: Int { converted + copied + failed }
}
