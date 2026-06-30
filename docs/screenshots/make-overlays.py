#!/usr/bin/env python3
"""Generate App Store screenshots from the raw window captures in `raw/`.

Writes two sets at 2560x1600:
  - ./appstore-NN-*.png        captioned (headline + subtitle, app-theme accent)
  - ./plain/appstore-NN-*.png  un-captioned (window centered on a solid canvas)

Raws are produced by the DEBUG demo hook (see ../app-store-listing.md). To change
the wording, edit CAPTIONS below and re-run — no need to re-capture the app.

    python3 docs/screenshots/make-overlays.py
"""
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ROOT, "raw")
PLAIN = os.path.join(ROOT, "plain")
os.makedirs(PLAIN, exist_ok=True)

CW, CH = 2560, 1600

# (canvas bg, headline color, accent color, subtitle color)
DARK  = ((0, 0, 0),       (255, 255, 255), (208, 255, 0),  (165, 165, 165))   # lime accent
LIGHT = ((242, 242, 242), (17, 17, 17),    (164, 53, 210), (96, 96, 96))      # purple accent

# scene -> (headline_plain, headline_accent, subtitle)
CAPTIONS = {
    "empty":    ("Drop the ",       "whole pack",     "Folders or files — your entire library at once"),
    "analysis": ("See every fix, ", "explained",      "32-bit float, odd rates, FLAC — in plain language"),
    "done":     ("One click. ",     "SP-404 ready.",  "16-bit WAV at 48 / 44.1 kHz, ready for the SD card"),
}

SHOTS = [
    ("01", "empty",    "dark",  DARK),
    ("02", "analysis", "dark",  DARK),
    ("03", "done",     "dark",  DARK),
    ("04", "empty",    "light", LIGHT),
    ("05", "analysis", "light", LIGHT),
    ("06", "done",     "light", LIGHT),
]


def load_font(size, bold):
    try:
        f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
        try:
            f.set_variation_by_name("Bold" if bold else "Regular")
        except Exception:
            pass
        return f
    except Exception:
        pass
    if bold and os.path.exists("/System/Library/Fonts/Supplemental/Arial Bold.ttf"):
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", size)
    return ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)


HEAD = load_font(96, bold=True)
SUB = load_font(42, bold=False)


def plain_composite(raw, bg):
    src = Image.open(os.path.join(RAW, f"raw-{raw}.png")).convert("RGBA")
    canvas = Image.new("RGB", (CW, CH), bg)
    canvas.paste(src, ((CW - src.width) // 2, (CH - src.height) // 2), src)
    return canvas


def overlay_composite(scene, raw, theme):
    bg, head_c, acc_c, sub_c = theme
    canvas = Image.new("RGB", (CW, CH), bg)
    d = ImageDraw.Draw(canvas)
    plain, accent, sub = CAPTIONS[scene]

    wp = d.textlength(plain, font=HEAD)
    wa = d.textlength(accent, font=HEAD)
    hx = (CW - (wp + wa)) / 2
    d.text((hx, 92), plain, font=HEAD, fill=head_c, anchor="la")
    d.text((hx + wp, 92), accent, font=HEAD, fill=acc_c, anchor="la")
    d.text((CW / 2, 232), sub, font=SUB, fill=sub_c, anchor="ma")

    src = Image.open(os.path.join(RAW, f"raw-{raw}.png")).convert("RGBA")
    top, bottom_margin = 336, 64
    scale = (CH - top - bottom_margin) / src.height
    src = src.resize((int(src.width * scale), int(src.height * scale)), Image.LANCZOS)
    canvas.paste(src, ((CW - src.width) // 2, top), src)
    return canvas


def main():
    for num, scene, appear, theme in SHOTS:
        name = f"{num}-{scene}-{appear}"
        plain_composite(f"{scene}-{appear}", theme[0]).save(os.path.join(PLAIN, f"appstore-{name}.png"))
        overlay_composite(scene, f"{scene}-{appear}", theme).save(os.path.join(ROOT, f"appstore-{name}.png"))
        print("wrote", name)
    print("DONE")


if __name__ == "__main__":
    main()
