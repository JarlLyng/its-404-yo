import Foundation
import Security
import Sentry

/// Anonymous crash reports, MetricKit diagnostics, crash-free sessions and one feature count, sent
/// to Sentry (#73, docs/SENTRY.md). Anonymous is a recipe, not Sentry's default: out of the box
/// sentry-cocoa sends a random installation ID as the user, as every session's `did` and on every
/// metric, plus a hash of the vendor ID on every event. Everything here exists so that no ID, no
/// sample, no file name and no folder path leaves the Mac.
enum Telemetry {

    /// The one user every install reports as.
    static let anonymousUser = "anonymous"

    /// The only attributes a metric may carry: the SDK's coarse facts (version, OS, device model)
    /// plus ours. Anything else, `user.id` included, is dropped.
    static let allowedMetricAttributes: Set<String> = [
        "sentry.sdk.name", "sentry.sdk.version", "sentry.environment", "sentry.release",
        "os.name", "os.version", "device.brand", "device.model", "device.family",
        "rate",
    ]

    /// What replaces free text (an exception reason, a breadcrumb) that might name a file.
    static let redactedText = "[removed: may contain a file name or path]"

    /// Starts Sentry if the build has a DSN. Not under XCTest, where the host app only adds noise.
    static func start() {
        let env = ProcessInfo.processInfo.environment
        guard env["XCTestConfigurationFilePath"] == nil,
              let dsn = dsn(environment: env, infoDictionary: Bundle.main.infoDictionary)
        else { return }

        let options = Options()
        options.dsn = dsn
        options.environment = environment
        options.sendDefaultPii = false
        // No performance tracing: crash reports, sessions, MetricKit and the count are what the
        // privacy policy names. File I/O spans would carry sample paths, so they stay off even if
        // tracing is turned on one day. (Screenshots and view hierarchy don't exist on macOS.)
        options.tracesSampleRate = nil
        options.enableFileIOTracing = false
        options.enableAutoSessionTracking = true
        options.enableMetricKit = true
        options.beforeSend = { anonymize($0) }
        options.beforeBreadcrumb = { scrub($0) }
        options.beforeSendMetric = { anonymize($0) }

        // Sessions can't be given a user: sentry-cocoa sets every session's `did` from the
        // INSTALLATION file in its cache directory, and creates that file with a random UUID when
        // it's missing. Writing the shared user into the file before the SDK starts makes every
        // install report the same `did`. Checked against the outgoing envelopes with sentry-cocoa
        // 9.32.0; check again after every SDK upgrade (docs/SENTRY.md).
        pinInstallationID(cacheDirectoryPath: options.cacheDirectoryPath)

        SentrySDK.start(options: options)
        // Before any event or metric, so nothing falls back to an installation ID.
        SentrySDK.setUser(User(userId: anonymousUser))

        // Lets the owner check a real build end to end: launch it with this argument and one
        // anonymous test event goes out (docs/SENTRY.md). Nothing happens without it.
        if CommandLine.arguments.contains("-SentryTestEvent") {
            SentrySDK.capture(message: "It's 404, yo! test event")
        }
    }

    /// The DSN, from `SENTRY_DSN` in the environment (Debug builds only, for a local test) or the
    /// `SentryDSN` Info.plist key that `Config/Sentry.xcconfig` fills at build time.
    static func dsn(environment env: [String: String], infoDictionary: [String: Any]?) -> String? {
        var candidates: [String?] = [infoDictionary?["SentryDSN"] as? String]
        #if DEBUG
        candidates.insert(env["SENTRY_DSN"], at: 0)
        #endif
        for candidate in candidates {
            let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // An unexpanded `$(SENTRY_DSN)` or a value cut at `//` by xcconfig isn't a DSN.
            if value.hasPrefix("https://") || value.hasPrefix("http://") { return value }
        }
        return nil
    }

    // MARK: - Feature count

    /// A conversion run that wrote at least one file. The only attribute is the target rate the
    /// user picked, from a fixed list: never a file, a folder, a count of files or a format.
    static func conversionFinished(rate: ConversionSettings.TargetSampleRate) {
        guard SentrySDK.isEnabled else { return }
        SentrySDK.metrics.count(
            "conversion.finished", value: 1,
            options: SentryMetricOptions(attributes: ["rate": rateAttribute(rate)])
        )
    }

    static func rateAttribute(_ rate: ConversionSettings.TargetSampleRate) -> String {
        switch rate {
        case .fortyEight: return "48k"
        case .fortyFourOne: return "44.1k"
        }
    }

    // MARK: - Environment

    /// `production` only for App Store builds, so debug, TestFlight and locally archived runs
    /// aren't read as real crashes. On macOS a TestFlight build has an ordinary `receipt` (unlike
    /// iOS's `sandboxReceipt`), so the receipt can't tell them apart; the signing certificate can.
    static var environment: String {
        #if DEBUG
        return "debug"
        #else
        if signature(satisfies: testFlightRequirement) { return "testflight" }
        if signature(satisfies: appStoreRequirement) { return "production" }
        return "development"
        #endif
    }

    /// Signed by Apple's TestFlight Beta Distribution certificate.
    static let testFlightRequirement = "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.25.1]"
    /// Signed by Apple for the Mac App Store.
    static let appStoreRequirement = "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.9]"

    /// Checks the running app's own signature, which the system has already validated, so it's quick.
    static func signature(satisfies requirementText: String) -> Bool {
        var code: SecCode?
        var requirement: SecRequirement?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess,
              let requirement
        else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }

    // MARK: - Anonymizing

    /// Covers errors, crashes and MetricKit diagnostics: one shared user, no device or vendor-ID
    /// hash, no account name in a binary's path, and no free text that might name a sample.
    static func anonymize(_ event: Event) -> Event {
        event.user = User(userId: anonymousUser)
        if var context = event.context {
            context["app"]?.removeValue(forKey: "device_app_hash")
            context["device"]?.removeValue(forKey: "id")
            event.context = context
        }
        if let message = event.message, !isSafeFreeText(message.formatted) || !isSafeFreeText(message.message) {
            event.message = SentryMessage(formatted: redactedText)
        }
        for exception in event.exceptions ?? [] {
            if !isSafeFreeText(exception.value) { exception.value = redactedText }
            exception.stacktrace?.frames.forEach { $0.package = $0.package.map(redactAccountName) }
        }
        for thread in event.threads ?? [] {
            thread.stacktrace?.frames.forEach { $0.package = $0.package.map(redactAccountName) }
        }
        event.debugMeta?.forEach { $0.codeFile = $0.codeFile.map(redactAccountName) }
        event.breadcrumbs = event.breadcrumbs?.compactMap { scrub($0) }
        return event
    }

    /// Keeps a breadcrumb's category and level; replaces its message, and drops each data value,
    /// that might name a file.
    static func scrub(_ crumb: Breadcrumb) -> Breadcrumb? {
        if !isSafeFreeText(crumb.message) { crumb.message = redactedText }
        for (key, value) in crumb.data ?? [:] where !isSafeFreeText((value as? String) ?? "\(value)") {
            crumb.setData(value: nil, key: key)
        }
        return crumb
    }

    static func anonymize(_ metric: SentryMetric) -> SentryMetric {
        var metric = metric
        metric.attributes = allowedAttributes(metric.attributes)
        return metric
    }

    static func allowedAttributes<Value>(_ attributes: [String: Value]) -> [String: Value] {
        attributes.filter { allowedMetricAttributes.contains($0.key) }
    }

    /// False for text that holds a path (`/Users/…/`, `~/…`, a `file://` URL) or a file name with
    /// an audio extension. Such text is replaced whole, because a sample's name can't be cut out of
    /// it reliably.
    static func isSafeFreeText(_ text: String?) -> Bool {
        guard let text, !text.isEmpty else { return true }
        let unsafe = [
            "file://",
            #"(^|[^A-Za-z0-9._-])(~|/[^/\s]+)/[^/\s]"#,
            #"\.(wav|wave|aif|aiff|aifc|mp3|m4a|aac|flac|caf)\b"#,
        ]
        return !unsafe.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    /// `/Users/<name>/Applications/It's 404, yo!.app/…` becomes `/Users/<user>/…`: an app moved out
    /// of /Applications runs from the home folder, and the account name is not ours to send.
    static func redactAccountName(_ path: String) -> String {
        path.replacingOccurrences(of: #"^/Users/[^/]+"#, with: "/Users/<user>", options: .regularExpression)
    }

    static func pinInstallationID(cacheDirectoryPath: String) {
        let directory = URL(fileURLWithPath: cacheDirectoryPath)
        let url = directory.appendingPathComponent("INSTALLATION")
        let pinned = Data(anonymousUser.utf8)
        guard (try? Data(contentsOf: url)) != pinned else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? pinned.write(to: url, options: .atomic)
    }
}
