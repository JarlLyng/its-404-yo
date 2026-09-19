# AGENTS.md — It's 404, yo!

Quick-start context for developers and AI assistants. Detailed specs in `docs/`.

## What is It's 404, yo!?

A single-purpose native macOS utility that batch-converts whole sample packs into the format the
Roland SP-404 MkII accepts on SD-card import (16-bit linear PCM WAV at 48 or 44.1 kHz), and tells
you in plain language why each file would otherwise have failed. It exists because the device
rejects most downloaded packs with a bare "Unsupported File" and no explanation. Everything runs
offline and sandboxed: no account, no network, no cloud, and samples never leave the Mac. Sibling
to _It's mono, yo!_

- **Developer:** [IAMJARL](https://iamjarl.com) (Jarl). The full personal name is never used in copy or docs; see `BRAND_LEGAL.md` in the hub.
- **Website:** [its404yo.iamjarl.com](https://its404yo.iamjarl.com)
- **License:** [MIT](LICENSE) — open source.
- **Price:** $0.99 USD one-time (no in-app purchases, no subscription, no ads)
- **Status:** Launched on the Mac App Store, [app id 6785918261](https://apps.apple.com/app/id6785918261). Current release 1.1.0.
- **Sister app:** [It's mono, yo!](https://itsmonoyo.iamjarl.com)

## Strategy lives in the private hub

Target audience, positioning, pricing reasoning, SEO/ASO playbooks, analytics readouts and
competitor analysis are **not** in this public repo. They live in the private
[iamjarl-strategy](https://github.com/JarlLyng/iamjarl-strategy) hub, folder `Its404Yo/`. Before
any audience, positioning, pricing or marketing-planning work, read that repo's `CONVENTIONS.md`
and write results there, not here. `BOOTSTRAP_PROMPT.md` in that repo has the full brief.

### Read these hub files before the task they govern

- **`VOICE.md`** before writing *any* public copy: App Store text, site copy, release notes,
  community posts, replies. Hard rules: no em-dashes, no bullet lists in copy, minimal emojis,
  always pay-once framing (never "free" for a paid app).
- **`BRAND_LEGAL.md`** before anything naming the maker, copyright or a third-party product.
  The public identity is IAMJARL; a human name is the first name only. Roland and SP-404 are
  other people's trademarks, and this app is independent and unaffiliated: say so where it matters.
- **`DESIGN.md`** before App Store screenshots or any visual that carries the brand.
- **`ASO_GUIDANCE.md`** before touching App Store metadata; **`SEO_GUIDANCE.md`** before site SEO;
  **`DATA_ACCESS.md`** to pull GSC, Umami or App Store numbers.
- **Public issues carry findings, never measured numbers.** No download, sales, revenue,
  rating-count or traffic figures in this repo or its issues. State the finding, drop the number.

### Keep this file current

When the app ships a version, changes price or OS floor, or gains or loses a feature, update the
lines in this file in the same change. A stale AGENTS.md is worse than none: an assistant will
build on what it says.

## App features (be precise — do not invent features that don't exist)

- Drag in folders or individual files; the scanner walks directories recursively and de-duplicates.
- Reads `wav`, `wave`, `aif`, `aiff`, `aifc`, `mp3`, `m4a`, `aac`, `flac`, `caf`.
- Analyses every file and gives a plain-language reason per file ("32-bit float → 16-bit",
  "96 kHz resampled", "FLAC → WAV").
- Converts to 16-bit linear PCM WAV at **48 kHz** (default) or **44.1 kHz**.
- Files that already import cleanly are **copied untouched**, never re-encoded.
- Output mirrors the input folder structure.
- Warns (without blocking) on edge cases: over 16 minutes, estimated output over ~185 MB, or
  under 0.1 s. Files with warnings are still converted; only unreadable files are skipped.
- **Optional** file-name sanitization, off by default: folds diacritics to ASCII, replaces
  characters outside a safe subset, and de-duplicates collisions it creates.
- Remembers the last output folder (security-scoped bookmark) and target sample rate across launches.
- Asks for an App Store review after the 2nd and 5th fully successful conversion, never at launch.

### Features that do NOT exist (common hallucination targets)

These are open issues or deliberate exclusions, not shipped behaviour. Do not describe them as working.

- **Does not split files** that exceed the SP-404's length or size limit. It only warns (issue #6).
- **No level normalization or gain adjustment** of any kind (issue #18).
- **No device profiles other than the SP-404 MkII.** No MPC, Blackbox or Digitakt targets (issue #15).
- **No in-app text-size control** (issue #9).
- **Does not talk to the device.** No USB connection, no writing to the SD card, no reading the
  SP-404's project format. It writes converted files to a folder you choose; moving them to the
  card is manual.
- **No network, no backend, no cloud, no accounts, and no telemetry or analytics in the app.**
- **macOS only.** No iOS, iPadOS or command-line build.

## Requirements

- macOS 13.0 or later (Apple silicon and Intel).

## Build & run

```sh
make generate   # XcodeGen → Its404Yo.xcodeproj (git-ignored)
make build
make test
```

Do **not** commit `Its404Yo.xcodeproj` — it is generated from `project.yml`.

Xcode Cloud builds from the `release` branch. `ci_scripts/ci_post_clone.sh` regenerates the
project and copies `ci_scripts/Package.resolved.baseline` into place, because Xcode Cloud has
automatic package resolution disabled and needs a committed resolve. **When a dependency version
changes, refresh that baseline in the same commit** or the cloud build silently keeps the old one.

## Conventions

- **Single purpose.** Keep the app focused on making sample packs SP-404-ready. Discuss scope
  before adding unrelated features.
- **Design tokens.** Use `DesignTokens.*` from the `IAMJARLDesignTokens` SPM package for all
  colors, spacing, radius, and type sizes — never hard-code them.
- **Engine is pure & tested.** Conversion/inspection logic lives in `Sources/Its404Yo/Services` and
  must stay free of UI dependencies so the tests can call it directly. Add tests for logic changes.
- **No backend, no network, no new runtime dependencies.** The app is offline and sandboxed.
- **Format facts are documented.** Any change to accepted/target formats must stay consistent with
  `docs/build-spec.md` (source-cited).
- **One agent file.** This repo keeps `AGENTS.md` and no tool-specific AI config; see `.gitignore`.

## Where things are

- `Sources/Its404Yo/Services` — `AudioConverter`, `AudioFormatInspector`, `AudioFormat`, `SampleScanner`, `FilenameSanitizer`
- `Sources/Its404Yo/Models` — `AppState`, `AudioFileItem`, `ConversionSettings`
- `Sources/Its404Yo/Views` — SwiftUI views
- `Tests/Its404YoTests` — unit + end-to-end conversion tests
- `site/` — the marketing site source, deployed to GitHub Pages
- `docs/` — build spec, architecture, App Store listing copy
