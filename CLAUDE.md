# Project guidance for Claude / agents

**What this is:** _It's 404, yo!_ — a single-purpose native macOS utility that batch-converts
sample packs into SP-404 MkII-compatible audio (16-bit linear PCM WAV, 44.1/48 kHz). A sibling to
_It's mono, yo!_

## Build & test

```sh
make generate   # XcodeGen → Its404Yo.xcodeproj (git-ignored)
make build
make test
```

Do **not** commit `Its404Yo.xcodeproj` — it is generated from `project.yml`.

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

## Where things are

- `Sources/Its404Yo/Services` — `AudioConverter`, `AudioFormatInspector`, `AudioFormat`, `SampleScanner`
- `Sources/Its404Yo/Models` — `AppState`, `AudioFileItem`, `ConversionSettings`
- `Sources/Its404Yo/Views` — SwiftUI views
- `Tests/Its404YoTests` — unit + end-to-end conversion tests
- `docs/` — build spec, architecture
