# Sentry: anonymous crash reports and one count

From 1.3.0 the app sends anonymous crash reports, MetricKit diagnostics, crash-free sessions and
one feature count to Sentry (project `its404yo` in the `iamjarl` organisation, EU region). The
code is `Sources/Its404Yo/Telemetry/Telemetry.swift`; the decision is #73 and the portfolio's
privacy standard. Converting samples still works offline: Sentry keeps what it couldn't send and
tries again later.

## What is sent, and what isn't

Anonymous is a recipe, not Sentry's default. Out of the box sentry-cocoa sends a random
installation ID as the user, as every session's `did` and on every metric, plus
`device_app_hash` (a hash of the vendor ID) on every event. `Telemetry.swift` stops all of it:

- **One shared user, `anonymous`,** set right after `SentrySDK.start` and again on every event in
  `beforeSend` (crashes, errors and MetricKit diagnostics all pass through it).
- **No device IDs:** `beforeSend` drops `contexts.app.device_app_hash` and `contexts.device.id`.
- **Sessions without an ID:** sentry-cocoa sets a session's `did` from the `INSTALLATION` file in
  its cache directory and has no option to change it. The app writes `anonymous` into that file
  before the SDK starts, so every install reports the same `did`. This relies on SDK internals,
  so the SDK is pinned exactly (`project.yml`) and **the envelope check below is repeated after
  every sentry-cocoa upgrade**. `TelemetryTests.testInstallationIDIsPinnedToTheSharedUser` reads
  the file back through the SDK's own reader and fails if an upgrade moves it.
- **No sample, file name or folder path:** free text that holds a path, a `file://` URL or an
  audio file name (an exception reason, a crash message, a breadcrumb) is replaced whole, because
  a sample's name can't be cut out of it reliably. Binary paths keep the app bundle but lose the
  account name (`/Users/<user>/Applications/…`).
- **One count:** `conversion.finished`, once per conversion that wrote at least one file, with one
  attribute, `rate` (`48k` or `44.1k`). `beforeSendMetric` keeps only that and the SDK's coarse
  facts (SDK, release, environment, OS, device model) and drops everything else, `user.id`
  included.
- **Off:** `sendDefaultPii`, performance tracing, file I/O spans (they would carry sample paths).
  Screenshots, view hierarchy and session replay don't exist in sentry-cocoa on macOS.
- **Nothing stored to measure:** the only file the app adds is the `INSTALLATION` pin, which says
  `anonymous`. The review prompt's counter predates this and isn't sent anywhere.
- **Environment:** `debug` for Debug builds; in Release, `testflight` or `production` from the
  signing certificate, and `development` for anything else (a local archive, a Developer ID
  build). On macOS a TestFlight build's receipt is called `receipt` like an App Store build's
  (iOS uses `sandboxReceipt`), so the receipt can't tell them apart. The certificate can: Apple
  signs TestFlight builds with "TestFlight Beta Distribution" (leaf OID
  `1.2.840.113635.100.6.1.25.1`) and App Store builds for the Mac App Store (`…6.1.9`).

The `iamjarl` organisation also strips `user.id`, `contexts.device.id` and
`contexts.app.device_app_hash` server-side and stores no IP addresses, as a safety net. The SDK
sends `infer_ip: never`.

The privacy policy (`site/privacy.html`), `PrivacyInfo.xcprivacy` and the App Store label name
the same three kinds of data, all not linked to the user and not used for tracking: Crash Data and
Performance Data (Diagnostics), and Product Interaction (Usage Data).

## Checking the envelopes (after every sentry-cocoa upgrade)

Point a Debug build at a local stand-in for Sentry and read what it sends.

1. Run a small HTTP server on a free local port that saves each POST body (gunzip it if
   `Content-Encoding: gzip`) and answers 200. Check the port is free first; other sessions on the
   same Mac may be running the same test.
2. Build Debug **signed** (so the sandbox applies and the cache directory is the app's container),
   and launch the binary with
   `SENTRY_DSN="http://0123456789abcdef0123456789abcdef@127.0.0.1:<port>/1"`. Debug builds read
   `SENTRY_DSN` from the environment.
3. The container's cache can't be reached from a shell, so seed `INSTALLATION` with a fake old ID
   from inside the app (a temporary probe, not committed) before `pinInstallationID` runs. A probe
   also fires the count plus one with an extra attribute and a `user.id`, adds a breadcrumb and a
   message that name a sample, and on a second run calls `fatalError` with a path in its message.
   The third launch sends the crash.
4. Sessions start only when the app becomes active, so the probe calls
   `NSApp.activate(ignoringOtherApps:)` and quits with `NSApp.terminate` to end the session.

Pass when the `session` items' `did` is `anonymous` at init and exit; the `event` items' `user` is
`{"id": "anonymous"}` with no `device_app_hash` and no `device.id`; `trace_metric` items carry only
the allowed attributes; the crash message, the probe message and the breadcrumb read
`[removed: may contain a file name or path]`; binary paths read `/Users/<user>/…`; and the fake ID,
the account name, the computer name and the sample name appear nowhere.

**Last checked with sentry-cocoa 9.32.0 on 2026-11-15: passed.** A signed Release build launched
with `-SentryTestEvent` sent the test event as `environment: development`, user `anonymous`.

## The DSN

The app reads the DSN from the `SentryDSN` Info.plist key, which `Sources/Its404Yo/Info.plist`
fills from the `SENTRY_DSN` build setting. Debug builds also accept `SENTRY_DSN` from the
environment, for a local test. With no DSN the app sends nothing.

The build setting comes from `Config/Its404Yo.xcconfig`, which includes the gitignored
`Config/Sentry.xcconfig` when it exists. **In an xcconfig `//` starts a comment**, so a DSN
written as `https://…` is cut to `https:` and the app ships silent. Write the slashes as
`https:/$()/…` (`$()` expands to nothing); `Config/Sentry.xcconfig.example` shows the form.

**Xcode Cloud:** add `SENTRY_DSN` (secret) to the workflow's environment.
`ci_scripts/ci_post_clone.sh` writes it to `Config/Sentry.xcconfig` with the slashes escaped.

**An archive without a DSN stops.** The "Check Sentry DSN on archive" build phase
(`project.yml`) fails any archive whose DSN is missing or doesn't look like `https://…@…/…`, with
an error that names the fix. Builds and tests run without one.

**Locally:** copy `Config/Sentry.xcconfig.example` to `Config/Sentry.xcconfig` and fill in the
DSN (Sentry, Settings, Projects, `its404yo`, Client Keys), or set `SENTRY_DSN` in the scheme's
Run environment for a Debug run.

## dSYMs (readable crashes)

`ci_scripts/ci_post_xcodebuild.sh` uploads the archive's dSYMs after every Xcode Cloud archive,
with sentry-cli 3.8.2 downloaded from its GitHub release and checked against the SHA-256 GitHub
publishes for that asset. It needs a second secret on the workflow, `SENTRY_AUTH_TOKEN` (an
organisation auth token that can upload debug files). `SENTRY_ORG` and `SENTRY_PROJECT` default
to `iamjarl` and `its404yo`. Without the token, or if the upload fails, the build goes on with a
warning: the release is fine, only its stack traces are unreadable.

## Checking a real build

Launch an installed build with `-SentryTestEvent` and one anonymous test event goes out:

```sh
"/Applications/Its404Yo.app/Contents/MacOS/Its404Yo" -SentryTestEvent
```

In Sentry it should show user `anonymous`, no `device_app_hash`, no file paths, and environment
`testflight` for a TestFlight build or `production` for the App Store build.
