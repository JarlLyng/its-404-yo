import Foundation

/// Conservative, opt-in file-name sanitization for SD-card import.
///
/// Rewrites a single path component (a file or folder name) to a safe subset:
/// diacritics are folded to ASCII (é → e), anything outside `[A-Za-z0-9 -_.()]` becomes `_`,
/// runs of `_`/space are collapsed, ends are trimmed, and an over-long base name is capped.
/// The extension is preserved. An empty result falls back to `sample`.
///
/// These rules are a defensive best-effort, **not** hardware-verified against the SP-404 MkII
/// importer yet (see issue #13). Keep them easy to tune once the real limits are confirmed.
enum FilenameSanitizer {

    /// Generous cap on the base-name length (extension excluded). Well under FAT limits.
    static let maxBaseLength = 100

    private static let allowed = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_.()"
    )
    private static let trimEnds = CharacterSet(charactersIn: " ._")

    /// Sanitize one path component. Safe to call on both file and folder names.
    static func sanitize(_ name: String) -> String {
        let ns = name as NSString
        let ext = ns.pathExtension
        let rawBase = ext.isEmpty ? name : ns.deletingPathExtension

        var base = clean(rawBase)
        if base.count > maxBaseLength {
            base = String(base.prefix(maxBaseLength))
                .trimmingCharacters(in: trimEnds)
        }
        if base.isEmpty { base = "sample" }

        let cleanExt = clean(ext)
        return cleanExt.isEmpty ? base : "\(base).\(cleanExt)"
    }

    private static func clean(_ s: String) -> String {
        let folded = s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
        var out = String(folded.map { allowed.contains($0) ? $0 : "_" })
        while out.contains("__") { out = out.replacingOccurrences(of: "__", with: "_") }
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.trimmingCharacters(in: trimEnds)
    }
}
