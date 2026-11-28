# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue.

- Use [GitHub private vulnerability reporting](https://github.com/JarlLyng/its-404-yo/security/advisories/new), or
- Email the maintainer (see the GitHub profile for [@JarlLyng](https://github.com/JarlLyng)).

You can expect an initial response within a few days. Please include steps to reproduce and the
affected version.

## Security posture

_It's 404, yo!_ is a sandboxed macOS utility that converts samples on the Mac:

- **Network only for Sentry.** `com.apple.security.network.client` is there for anonymous crash
  reports and one count (see [`docs/SENTRY.md`](docs/SENTRY.md)). They carry no ID, no file name and
  no path, and no sample is ever uploaded. Nothing else in the app opens a connection.
- **App Sandbox** is enabled; the app only touches files the user explicitly drops or selects
  (`com.apple.security.files.user-selected.read-write`).
- **Two dependencies.** The [IAMJARL design tokens](https://github.com/JarlLyng/iamjarl-design)
  Swift package (compile-time, UI only) and [sentry-cocoa](https://github.com/getsentry/sentry-cocoa),
  pinned to an exact version.
- **The Sentry DSN** is a public client key that ships in the app; it is still kept out of git and
  comes from the Xcode Cloud environment. The dSYM upload token is a workflow secret.
- **No secrets** are stored in this repository. Signing assets are git-ignored.

## Supported versions

The latest version on the Mac App Store and the `main` branch are supported.
