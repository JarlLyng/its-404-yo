# Screenshots

One source, one output:

- **`raw/`** holds the window captures, made from the app's demo data (see "Demo mode and screenshots"
  in `docs/ARCHITECTURE.md`). The demo data goes through the real `AudioFormatInspector`, so every label
  in a capture is one the app produces for that file. The README hero and the site's tour use these.
- **`appstore-*.png`** are the App Store posters, 2560×1600, composed from `raw/` by the design hub's
  `tools/appstore_screenshots.py batch docs/screenshots/manifest.json`. To change a caption, edit
  `manifest.json` and re-run. There's no need to re-capture.

The posters use the light poster style the owner chose on 2026-11-26 (#80): a light ground with a soft
lime haze, a centred heavy headline with one phrase on a lime chip, a short subline, the whole app
window, and up to three tilted stickers. Each sticker is a label or fact the capture under it shows,
and sits at the window's edge, not over a row. The three are the whole message in order:
`raw-done-dark` (one click), `raw-pack-dark` (a whole pack, `-DemoPack`) and
`raw-analysis-compact-dark` (the analysis in an 800×560 window, `-DemoCompact`, so it reads as
zoomed in next to the first one at thumbnail size).

Captions are public copy: no em-dashes, no hype. New posters reach the store only with a new version,
because the default product page can't change on an approved version.
