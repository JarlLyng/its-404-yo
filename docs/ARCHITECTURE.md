# Architecture

_It's 404, yo!_ is a small SwiftUI macOS app over a pure Core Audio conversion engine. There is no
backend and no persistence — it transforms files the user drops and writes results to a folder they
choose.

## Layers

```
Views (SwiftUI)              ContentView, DropZoneView, FileListView
        │  observes
Models                       AppState (ObservableObject), AudioFileItem, ConversionSettings
        │  calls
Services (pure, testable)    SampleScanner → AudioFormatInspector → AudioConverter
        │  uses
Core Audio (AudioToolbox)    ExtAudioFile + AudioStreamBasicDescription
```

### Services (the engine)

- **`SampleScanner`** — recursively collects supported audio files from dropped files/folders and
  records each file's path relative to the dropped root (so output mirrors input structure).
- **`AudioFormatInspector`** — reads a file's `AudioStreamBasicDescription` via `ExtAudioFile`,
  derives `AudioProperties` (sample rate, channels, bit depth, float/PCM/MP3, duration), and
  `classify(...)`s it as `compatible` / `needsConversion([reasons])` / `unreadable`. Also computes
  edge-case warnings.
- **`AudioFormat`** — builds the canonical 16-bit signed-integer interleaved PCM
  `AudioStreamBasicDescription` and holds the set of SP-404-safe sample rates.
- **`AudioConverter`** — the conversion itself: open source with `ExtAudioFile`, set the client
  data format to 16-bit PCM at the target rate (so reads are decoded + resampled + bit-reduced),
  create a `kAudioFileWAVEType` output, and stream frames across. Re-muxing to a fresh WAV drops
  exotic / BWF / extra RIFF chunks for free.

The Services layer has no UI or app dependencies, which is why the unit tests exercise it directly
(including a real float-96k → int16-48k round trip).

### Models

- **`AppState`** (`@MainActor`, `ObservableObject`) orchestrates: it runs scanning/analysis and the
  conversion loop on detached tasks and publishes progress and the final `ConversionReport` back to
  the main actor.
- **`AudioFileItem`** is the per-row display model; **`ConversionSettings`** holds the target rate.

### Views

Plain SwiftUI. All colors, spacing, radius, and type sizes come from the
[`IAMJARLDesignTokens`](https://github.com/JarlLyng/iamjarl-design) Swift package via
`DesignTokens.*`, so the app stays on-brand and theme-aware (light/dark).

## Build system

The Xcode project is generated from [`project.yml`](../project.yml) with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and is git-ignored. This keeps the repo free of
`.pbxproj` churn and makes the build reproducible (`make generate`).

## Why these format choices

See [`build-spec.md`](build-spec.md) for the full, source-cited rationale behind 16-bit / 44.1–48 kHz
linear PCM WAV as the SP-404 MkII-safe target.
