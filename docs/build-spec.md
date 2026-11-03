# Format spec: It's 404, yo!

What the SP-404 MkII accepts on SD-card import, what this app converts to, and why. This file is the
source of truth for accepted and target formats (see `AGENTS.md`): a change to either in the code has
to stay consistent with it. Code structure is in [`ARCHITECTURE.md`](ARCHITECTURE.md).

## 1. What the device accepts

From Roland's own documentation (sources at the end):

- **Two import routes with different rules.**
  - **SD card**: Roland states the rule as **16-bit linear WAV, AIFF or MP3**.
  - **SP-404MK2 App** (Roland's desktop software): also takes **FLAC and M4A**, and converts on its own.
- **Every import is converted to 48 kHz / 16-bit** on the device.
- **Files under 100 ms may not import.**
- **Limits per sample:** about 16 minutes, or about 185 MB.
- The on-screen error is **"Unsupported FILE"**, with no reason given.

### What is well-founded and what is not

- **32-bit float WAV** is the well-founded cause of "Unsupported FILE". It's the default render format
  of many pro and Splice packs, and 32-bit appears in none of Roland's lists.
- **FLAC and M4A** are outside the SD-card rule. They import through the App, not from the card.
- **24-bit, and 16-bit at high rates (88.2, 96 kHz and up), are unproven either way.** They are outside
  the stated SD-card rule. But Roland's table of *verified* formats lists WAV/AIFF/FLAC at 16 and 24-bit,
  16 to 192 kHz, without saying whether that table covers the card or only the App. Don't claim they fail.

The app therefore converts to the format the stated rule guarantees, and treats everything else as
"convert to be safe", not as "this fails".

## 2. Target: what the app writes

| Aspect | Rule |
|---|---|
| **Container / codec** | Linear PCM WAV (RIFF). Float PCM, compressed and other containers (AIFF, FLAC, MP3, M4A, AAC, CAF) are converted. |
| **Bit depth** | **16-bit integer, always.** No pass-through of 24-bit or 32-bit, integer or float. |
| **Sample rate** | **48 kHz** by default, the device's internal rate, so nothing is resampled on the device. 44.1 kHz as an option. Any other rate is resampled. |
| **Channels** | **Kept as the source** (mono stays mono, stereo stays stereo). Roland documents no channel restriction. |
| **Metadata** | A clean, canonical WAV, which drops BWF/broadcast chunks, extra RIFF chunks and cue points. |

**Copied untouched, not re-encoded:** 16-bit linear PCM WAV or AIFF at 44.1 or 48 kHz, and MP3. These
already match the stated SD-card rule (`AudioFormatInspector.classify`). Known gap: `classify` doesn't
check the container yet, so a 16-bit CAF at those rates is copied as `.caf` too
([#68](https://github.com/JarlLyng/its-404-yo/issues/68)).

**Warnings, never blocking:** over 16 minutes, estimated output over about 185 MB, or under 0.1 s.
A file with a warning is still converted. Only unreadable files are skipped.

**Optional file-name cleanup** (off by default, shipped in 1.1.0): folds diacritics to ASCII, replaces
characters outside a safe subset, caps the base name at 100 characters and de-duplicates any collisions
it creates (`FilenameSanitizer`). Whether the card has its own name-length limit is open, see §3.

## 3. Open questions (need a hardware test)

The maintainer has no SP-404 to test on, so these stay open until someone with one can check:

1. Does SD-card import accept 32-bit **integer** PCM, or only 16-bit? The app converts either way. ([#11](https://github.com/JarlLyng/its-404-yo/issues/11))
2. The exact minimum length that fails, and whether it applies to the card or only the App. ([#12](https://github.com/JarlLyng/its-404-yo/issues/12))
3. File-name and path limits on SD-card import: double-byte characters, length, folder depth. ([#13](https://github.com/JarlLyng/its-404-yo/issues/13), and [#44](https://github.com/JarlLyng/its-404-yo/issues/44) on whether the limit is 60 characters)
4. Do 24-bit files, or 16-bit files at high rates, import from the card? See §1.

## Sources

- Roland Support, *What audio file formats can be imported into the SP-404MK2?*
  ([4408190553883](https://support.roland.com/hc/en-us/articles/4408190553883-SP-404MK2-What-audio-file-formats-can-be-imported-into-the-SP-404MK2)):
  the SD-card rule, the App's extra formats, the verified-format table, the 48 kHz/16-bit conversion and the 100 ms note.
  It sits behind a browser check, so command-line fetches get a 403.
- SP-404MK2 Reference Manual v5.50:
  [error messages](https://static.roland.com/manuals/sp-404mk2_reference_v550/en-US/8008769178590859.html) ("Unsupported FILE"),
  [importing samples](https://static.roland.com/manuals/sp-404mk2_reference_v550/en-US/7958977178537867.html),
  [main specifications](https://static.roland.com/manuals/sp-404mk2_reference_v550/en-US/8010023578592395.html) (16 minutes, about 185 MB).
- Community converters that target 16-bit PCM and name 32-bit float as the usual cause:
  [pkMinhas/SP404WavConvertor](https://github.com/pkMinhas/SP404WavConvertor),
  [seb-patron/SP404mk2-wav-converter](https://github.com/seb-patron/SP404mk2-wav-converter).
