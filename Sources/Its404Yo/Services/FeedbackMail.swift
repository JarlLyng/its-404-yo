import Foundation

/// Builds the "Send Feedback…" email. Pure, so the encoding is testable without opening Mail.
///
/// Nothing is sent by the app. The URL opens a draft in the user's mail client with the address,
/// subject and a short footer filled in; the user sees all of it, edits it, and sends it or not.
enum FeedbackMail {

    static let address = "support@iamjarl.com"

    static func subject(appVersion: String) -> String {
        "It's 404, yo! \(appVersion) feedback"
    }

    /// Space to write first, then the two facts that make a report actionable.
    static func body(appVersion: String, build: String, osVersion: String) -> String {
        "\n\n\n--\nIt's 404, yo! \(appVersion) (\(build))\nmacOS \(osVersion)\n"
    }

    static func url(appVersion: String, build: String, osVersion: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        // Encode everything outside the unreserved set ourselves. `queryItems` leaves `&`, `=`
        // and `+` alone, which a value containing them would silently break.
        components.percentEncodedQueryItems = [
            URLQueryItem(name: "subject", value: encode(subject(appVersion: appVersion))),
            URLQueryItem(name: "body", value: encode(body(appVersion: appVersion, build: build, osVersion: osVersion))),
        ]
        guard let url = components.url else {
            // Only reachable if the address itself were malformed; it is a constant.
            preconditionFailure("could not build feedback mailto URL")
        }
        return url
    }

    /// The running app's own version strings, for the menu item.
    static func current(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> URL {
        let info = bundle.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let os = processInfo.operatingSystemVersion
        let osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        return url(appVersion: version, build: build, osVersion: osVersion)
    }

    private static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s
    }
}
