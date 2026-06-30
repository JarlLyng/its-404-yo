# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project scaffold: SwiftUI macOS app + Core Audio conversion engine.
- Drag-and-drop analysis of sample packs with plain-language conversion reasons.
- Batch conversion to 16-bit linear PCM WAV at 48 kHz / 44.1 kHz, preserving folder structure
  and channel count.
- Edge-case warnings (>16 min, ~185 MB, <100 ms).
- Integration with the [IAMJARL design tokens](https://github.com/JarlLyng/iamjarl-design).
- Unit tests for the converter and format inspector; GitHub Actions CI.
- macOS app icon (dark artwork) and a privacy manifest declaring no tracking / no data collection.
- App Store listing copy (`docs/app-store-listing.md`) and framed screenshots (`docs/screenshots/`).
- DEBUG-only `-DemoMode` launch hook for generating demo/screenshot data.
