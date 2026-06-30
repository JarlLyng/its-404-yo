# App Store listing — It's 404, yo!

Copy-paste fields for App Store Connect. Character limits noted in parentheses.

## App name (≤30)
```
It's 404, yo!
```
(13 chars)

## Subtitle (≤30)
```
SP-404 sample pack converter
```
(28 chars) — alternative: `Make sample packs SP-404 ready` (30)

## Promotional text (≤170, editable any time)
```
Drop a whole sample pack and get it back ready for your SP-404 MkII — no DAW, no Terminal, no "Unsupported File." Fixes 32-bit float, odd sample rates, FLAC and more.
```

## Keywords (≤100, comma-separated, no spaces between terms)
```
SP404,SP-404,sampler,sample pack,converter,WAV,16-bit,32-bit float,unsupported file,Roland,beatmaker
```
(99 chars — verify in Connect; trim "beatmaker" if over.)

## Description (≤4000)
```
Drop a sample pack. Get it back ready for your SP-404 MkII. No DAW, no Terminal, no cryptic "Unsupported File."

It's 404, yo! is a tiny, native macOS utility that batch-converts an entire sample pack into exactly the format the Roland SP-404 MkII accepts on SD-card import — and tells you, in plain language, what it changed.

WHY YOU NEED IT
Pro and Splice sample packs are usually 32-bit float WAVs (often 96 kHz, sometimes FLAC). The SP-404 MkII rejects them with "Unsupported File" and no explanation. Fixing them by hand in a DAW — one file at a time — is miserable across hundreds of samples.

WHAT IT DOES
• Drag in a folder (or files) — your whole pack at once
• See every file analyzed, with a clear reason for each change ("32-bit float → 16-bit", "96 kHz resampled", "FLAC → WAV")
• Convert to the SP-404-safe target: 16-bit linear PCM WAV at 48 kHz (or 44.1 kHz)
• Already-compatible files are copied untouched — no needless re-encoding
• Your folder structure is preserved in the output
• Warns about edge cases (over 16 min / ~185 MB, or under 100 ms)

SIMPLE BY DESIGN
One job, done well. No accounts, no subscriptions, no cloud. Everything runs offline on your Mac — your samples never leave your computer.

FROM THE MAKER OF "It's mono, yo!"
Built for the same hardware-sampler workflow by an indie developer who uses this gear.

Roland and SP-404 are trademarks of their respective owners. This app is independent and not affiliated with or endorsed by Roland.
```

## What's New (for v1.0.0)
```
First release. Drag in a sample pack, make it SP-404 MkII-ready in one click.
```

## Connect metadata
- **Category:** Music (primary). Secondary: Utilities (optional).
- **Price:** Paid, one-time (suggested Tier ~$4.99). No in-app purchases.
- **Age rating:** 4+ (no objectionable content).
- **Privacy:** "Data Not Collected" — matches `PrivacyInfo.xcprivacy`. No tracking.
- **Export compliance:** Uses no non-exempt encryption → answer **No**.
- **Support URL:** https://github.com/JarlLyng/its-404-yo/issues  (a real support/contact channel — Connect requires this, not just the marketing site)
- **Marketing URL (optional):** https://its404yo.iamjarl.com/
- **Privacy policy URL:** https://its404yo.iamjarl.com/privacy.html  (states the app collects no data; required even for no-data apps).
- **Copyright:** © 2026 IAMJARL

## Screenshots
macOS requires at least one screenshot at a supported size (1280×800, 1440×900, 2560×1600, or 2880×1800).
Provided in `docs/screenshots/`:
- `appstore-01-analysis-dark.png` (2560×1600) — hero, dark
- `appstore-02-analysis-light.png` (2560×1600) — light variant

Regenerate/extend with the DEBUG demo hook: build, then run
`Its404Yo.app/Contents/MacOS/Its404Yo -DemoMode` and capture the window.
