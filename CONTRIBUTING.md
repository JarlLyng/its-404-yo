# Contributing

Thanks for your interest in _It's 404, yo!_

## Getting started

```sh
brew install xcodegen
make generate
make open      # or: make test
```

The Xcode project is generated from [`project.yml`](project.yml) and is **not** committed —
always run `make generate` after pulling or changing `project.yml`.

## Project layout

```
Sources/Its404Yo/
  Models/      App state and value types
  Services/    Core Audio engine (conversion, inspection, scanning)
  Views/       SwiftUI views
Tests/Its404YoTests/   Unit tests (logic + end-to-end conversion)
docs/          Build spec and architecture
```

## Guidelines

- Keep it **single-purpose**: this app makes sample packs SP-404 MkII-ready. New features should
  serve that job (or a clearly scoped device profile).
- **Style:** match the surrounding code. Use the design tokens from `IAMJARLDesignTokens` instead
  of hard-coded colors, spacing, or type sizes.
- **Tests:** add or update tests for any change to the conversion/inspection logic. Run `make test`
  before opening a PR — CI must be green.
- **No new runtime dependencies** without discussion.
- Conventional, descriptive commit messages are appreciated.

## Reporting bugs / requesting features

Open an issue using the templates in `.github/ISSUE_TEMPLATE`. For format/compatibility bugs,
please include the source file's format (bit depth, sample rate, channels, container).

## Security

See [SECURITY.md](SECURITY.md) — report vulnerabilities privately.
