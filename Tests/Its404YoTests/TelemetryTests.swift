import XCTest
@_spi(Private) import Sentry
@testable import Its404Yo

/// The anonymous recipe (#73): no ID, no sample, no file name and no folder path leaves the Mac.
final class TelemetryTests: XCTestCase {

    func testEventGetsTheSharedUserAndLosesDeviceIDs() {
        let event = Event()
        event.user = User(userId: "3F2504E0-4F89-11D3-9A0C-0305E82C3301")
        event.context = [
            "app": ["device_app_hash": "abc123", "app_version": "1.3.0"],
            "device": ["id": "device-id", "model": "Mac14,2"],
        ]

        let out = Telemetry.anonymize(event)

        XCTAssertEqual(out.user?.userId, "anonymous")
        XCTAssertNil(out.context?["app"]?["device_app_hash"])
        XCTAssertNil(out.context?["device"]?["id"])
        XCTAssertEqual(out.context?["app"]?["app_version"] as? String, "1.3.0")
        XCTAssertEqual(out.context?["device"]?["model"] as? String, "Mac14,2")
    }

    func testFreeTextThatMightNameASampleIsReplacedWhole() {
        let event = Event()
        event.message = SentryMessage(formatted: "could not open /Users/jarl/Samples/Drums/Kick 01.wav")
        let pathException = Exception(value: "file:///Volumes/SD/ROLAND/IMPORT/snare.wav", type: "NSException")
        let plainException = Exception(value: "Index out of range", type: "EXC_BREAKPOINT")
        event.exceptions = [pathException, plainException]

        let out = Telemetry.anonymize(event)

        XCTAssertEqual(out.message?.formatted, Telemetry.redactedText)
        XCTAssertEqual(out.exceptions?[0].value, Telemetry.redactedText)
        XCTAssertEqual(out.exceptions?[1].value, "Index out of range")
    }

    func testAccountNameIsCutFromBinaryPaths() {
        let event = Event()
        let image = DebugMeta()
        image.codeFile = "/Users/jarl/Applications/It's 404, yo!.app/Contents/MacOS/Its404Yo"
        let system = DebugMeta()
        system.codeFile = "/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit"
        event.debugMeta = [image, system]
        let frame = Frame()
        frame.package = "/Users/jarl/Applications/It's 404, yo!.app/Contents/MacOS/Its404Yo"
        let thread = SentryThread(threadId: 0)
        thread.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        event.threads = [thread]

        let out = Telemetry.anonymize(event)

        XCTAssertEqual(out.debugMeta?[0].codeFile, "/Users/<user>/Applications/It's 404, yo!.app/Contents/MacOS/Its404Yo")
        XCTAssertEqual(out.debugMeta?[1].codeFile, "/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit")
        XCTAssertEqual(out.threads?[0].stacktrace?.frames[0].package, "/Users/<user>/Applications/It's 404, yo!.app/Contents/MacOS/Its404Yo")
    }

    func testBreadcrumbKeepsItsCategoryButNotAPath() {
        let crumb = Breadcrumb(level: .info, category: "ui.lifecycle")
        crumb.message = "opened ~/Music/Packs"
        crumb.setData(value: "/Users/jarl/Music/Packs/hat.aif", key: "path")
        crumb.setData(value: "foreground", key: "state")

        let out = Telemetry.scrub(crumb)

        XCTAssertEqual(out?.category, "ui.lifecycle")
        XCTAssertEqual(out?.message, Telemetry.redactedText)
        XCTAssertNil(out?.data?["path"])
        XCTAssertEqual(out?.data?["state"] as? String, "foreground")
    }

    func testSafeFreeText() {
        for text in ["Index out of range", "Fatal error: file Its404Yo/AppState.swift, line 42",
                     "16-bit / 48 kHz", "and/or", "N/A", nil, ""] {
            XCTAssertTrue(Telemetry.isSafeFreeText(text), "\(text ?? "nil") should pass")
        }
        for text in ["/Users/jarl/x", "see ~/Music/x", "\"/Volumes/SD/x\"", "file:///tmp/x",
                     "Kick 01.WAV", "loop.flac failed", "pad.aiff"] {
            XCTAssertFalse(Telemetry.isSafeFreeText(text), "\(text) should be removed")
        }
    }

    func testMetricKeepsOnlyAllowedAttributes() {
        let attributes = [
            "rate": "48k", "user.id": "3F2504E0", "user.email": "x@y.z", "os.version": "15.1",
            "sentry.release": "com.iamjarl.its404yo@1.3.0", "sentry.replay_id": "r", "probe": "p",
        ]

        let out = Telemetry.allowedAttributes(attributes)

        XCTAssertEqual(Set(out.keys), ["rate", "os.version", "sentry.release"])
    }

    func testRateAttributeIsAFixedValue() {
        XCTAssertEqual(Telemetry.rateAttribute(.fortyEight), "48k")
        XCTAssertEqual(Telemetry.rateAttribute(.fortyFourOne), "44.1k")
    }

    func testDSNMustBeAWholeURL() {
        let dsn = "https://0123456789abcdef@o1.ingest.de.sentry.io/2"
        XCTAssertEqual(Telemetry.dsn(environment: [:], infoDictionary: ["SentryDSN": dsn]), dsn)
        XCTAssertEqual(Telemetry.dsn(environment: [:], infoDictionary: ["SentryDSN": " \(dsn)\n"]), dsn)
        // Unset, unexpanded, or cut at `//` by an xcconfig that wasn't escaped: no Sentry.
        XCTAssertNil(Telemetry.dsn(environment: [:], infoDictionary: ["SentryDSN": ""]))
        XCTAssertNil(Telemetry.dsn(environment: [:], infoDictionary: ["SentryDSN": "$(SENTRY_DSN)"]))
        XCTAssertNil(Telemetry.dsn(environment: [:], infoDictionary: ["SentryDSN": "https:"]))
        XCTAssertNil(Telemetry.dsn(environment: [:], infoDictionary: nil))
    }

    /// Relies on sentry-cocoa's internals: if an upgrade moves the installation ID, this fails.
    func testInstallationIDIsPinnedToTheSharedUser() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("OLD-INSTALLATION-ID".utf8).write(to: directory.appendingPathComponent("INSTALLATION"))

        Telemetry.pinInstallationID(cacheDirectoryPath: directory.path)

        XCTAssertEqual(SentryInstallation.idNonCached(withCacheDirectoryPath: directory.path), "anonymous")
    }

    func testSigningRequirementsCompileAndDontMatchATestBuild() {
        for text in [Telemetry.testFlightRequirement, Telemetry.appStoreRequirement] {
            var requirement: SecRequirement?
            XCTAssertEqual(SecRequirementCreateWithString(text as CFString, [], &requirement), errSecSuccess)
            XCTAssertFalse(Telemetry.signature(satisfies: text))
        }
    }
}
