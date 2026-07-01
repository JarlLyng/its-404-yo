# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue.

- Use [GitHub private vulnerability reporting](https://github.com/JarlLyng/its-404-yo/security/advisories/new), or
- Email the maintainer (see the GitHub profile for [@JarlLyng](https://github.com/JarlLyng)).

You can expect an initial response within a few days. Please include steps to reproduce and the
affected version.

## Security posture

_It's 404, yo!_ is a fully offline, sandboxed macOS utility:

- **No network access.** The app makes no network requests and collects no data.
- **App Sandbox** is enabled; the app only touches files the user explicitly drops or selects
  (`com.apple.security.files.user-selected.read-write`).
- **No third-party runtime services.** The only dependency is the
  [IAMJARL design tokens](https://github.com/JarlLyng/iamjarl-design) Swift package (compile-time, UI only).
- **No secrets** are stored in this repository. Signing assets are git-ignored.

## Supported versions

The latest released version (currently **1.0**) and the `main` branch are supported.
