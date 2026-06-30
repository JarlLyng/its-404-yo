import Foundation

/// A file discovered on disk, with its path relative to the dropped root (so the
/// output mirrors the input folder structure).
struct ScannedFile: Equatable {
    let url: URL
    let relativePath: String
}

/// Recursively collects audio files from dropped files and folders, preserving the
/// relative folder structure for output.
enum SampleScanner {

    /// Audio extensions Core Audio can read and that make sense to feed an SP-404.
    static let supportedExtensions: Set<String> = [
        "wav", "wave", "aif", "aiff", "aifc", "mp3", "m4a", "aac", "flac", "caf"
    ]

    /// Scan dropped URLs (files and/or directories) into a flat, de-duplicated list.
    static func scan(_ urls: [URL]) -> [ScannedFile] {
        var results: [ScannedFile] = []
        var seen = Set<String>()

        for url in urls {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                let root = url.standardizedFileURL
                let rootName = root.lastPathComponent
                if let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator where isSupported(fileURL) {
                        // Relative path includes the dropped folder's own name as the top level.
                        let relative = rootName + "/" + relativePath(of: fileURL, under: root)
                        appendUnique(fileURL, relative: relative, into: &results, seen: &seen)
                    }
                }
            } else if isSupported(url) {
                appendUnique(url, relative: url.lastPathComponent, into: &results, seen: &seen)
            }
        }

        return results.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static func relativePath(of fileURL: URL, under root: URL) -> String {
        let rootComponents = root.standardizedFileURL.pathComponents
        let fileComponents = fileURL.standardizedFileURL.pathComponents
        if fileComponents.count > rootComponents.count,
           Array(fileComponents.prefix(rootComponents.count)) == rootComponents {
            return fileComponents.suffix(from: rootComponents.count).joined(separator: "/")
        }
        return fileURL.lastPathComponent
    }

    private static func appendUnique(
        _ url: URL,
        relative: String,
        into results: inout [ScannedFile],
        seen: inout Set<String>
    ) {
        let key = url.standardizedFileURL.path
        guard !seen.contains(key) else { return }
        seen.insert(key)
        results.append(ScannedFile(url: url, relativePath: relative))
    }
}
