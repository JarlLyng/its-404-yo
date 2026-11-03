# Screenshots

One source, one output:

- **`raw/`** holds the window captures, made from the app's demo data (see "Demo mode and screenshots"
  in `docs/ARCHITECTURE.md`). The demo data goes through the real `AudioFormatInspector`, so every label
  in a capture is one the app produces for that file. The README hero and the site's tour use these.
- **`appstore-*.png`** are the App Store posters, 2560×1600, composed from `raw/` by the design hub's
  `tools/appstore_screenshots.py batch docs/screenshots/manifest.json`. To change a caption, edit
  `manifest.json` and re-run. There's no need to re-capture.

Captions are public copy: no em-dashes, no hype. New posters reach the store only with a new version,
because the default product page can't change on an approved version.
