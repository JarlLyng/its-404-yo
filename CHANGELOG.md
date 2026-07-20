# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Optional file-name sanitization for SD-card import (off by default): folds diacritics to
  ASCII, replaces characters outside a safe subset, de-duplicates any resulting collisions, and
  preserves folder structure. Report shows how many files were renamed.
- Ask for an App Store review at a natural moment (the 2nd and 5th successful conversion), never
  on launch or first use. Uses StoreKit's `requestReview`, which throttles the actual prompt.

## [1.0.0] - 2026-06-30

First public release — submitted to the Mac App Store.

### Added
- Native SwiftUI macOS app with a Core Audio conversion engine.
- Drag-and-drop analysis of sample packs with plain-language conversion reasons.
- Batch conversion to 16-bit linear PCM WAV at 48 kHz / 44.1 kHz, preserving folder structure
  and channel count.
- Edge-case warnings (>16 min, ~185 MB, <100 ms).
- Integration with the [IAMJARL design tokens](https://github.com/JarlLyng/iamjarl-design).
- Accessibility: VoiceOver labels for the file list, Reduce Motion support, and
  Dynamic Type-ready text scaling.
- Unit tests for the converter and format inspector; GitHub Actions CI.
- macOS app icon and a privacy manifest declaring no tracking / no data collection.
- App Store listing copy (`docs/app-store-listing.md`) and captioned screenshots
  (`docs/screenshots/`, generator in `make-overlays.py`).
- DEBUG-only `-DemoMode` launch hook for generating demo/screenshot data.
- Marketing site under `site/` (its404yo.iamjarl.com) with a privacy policy page and a
  GitHub Pages deploy workflow.
