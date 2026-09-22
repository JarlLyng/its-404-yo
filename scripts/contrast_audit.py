"""WCAG 2.1 AA contrast audit of the token pairs It's 404, yo! actually renders.

Run:  python3 scripts/contrast_audit.py       (exits non-zero if anything fails)

Colour values are transcribed from iamjarl-design at tag **v1.2.1**, the version project.yml
pins. They are NOT read from the package at runtime, so when that pin moves, re-transcribe the
values here and re-run. Results are written up in docs/accessibility.md.

Two things this gets right that a naive check does not:
  * translucent colours are composited over the surface actually behind them before measuring,
    which is what decides the muted greys;
  * the threshold depends on the role. Text needs 4.5:1 (3:1 when large), while a non-text UI
    boundary falls under WCAG 1.4.11 and needs 3:1.
"""

def srgb_to_lin(c):
    c = c / 255.0
    return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055) ** 2.4

def luminance(rgb):
    r, g, b = (srgb_to_lin(v) for v in rgb)
    return 0.2126*r + 0.7152*g + 0.0722*b

def ratio(fg, bg):
    l1, l2 = luminance(fg), luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)

def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def over(fg_rgba, bg_rgb):
    """Composite a translucent colour onto its actual backing colour. This is the step that
    decides the muted greys: rgba(0,0,0,0.55) is NOT a 0.55-strength black, it is whatever
    it becomes on the surface behind it."""
    (r, g, b, a) = fg_rgba
    return tuple(round(a*c + (1-a)*bgc) for c, bgc in zip((r, g, b), bg_rgb))

WHITE, BLACK = hexrgb('#FFFFFF'), hexrgb('#000000')

# (label, foreground, background, pt size, bold?, role)
#   role 'text' -> AA needs 4.5 (or 3.0 when large); 'ui' -> AA 1.4.11 needs 3.0
cases = []

# ---------- LIGHT: app background #FFFFFF ----------
L_BG = WHITE
L_CARD = over((0,0,0,0.04), L_BG)
L_BADGE = over(hexrgb('#A435D2') + (0.12,), L_BG)
cases += [
 ("Light", "Text.primary on Background.app",      BLACK,                      L_BG,   16, False, 'text'),
 ("Light", "Text.secondary on Background.app",    over((0,0,0,0.70), L_BG),   L_BG,   14, False, 'text'),
 ("Light", "Text.tertiary on Background.app",     over((0,0,0,0.55), L_BG),   L_BG,   12, False, 'text'),
 ("Light", "primary (accent) as text",            hexrgb('#A435D2'),          L_BG,   14, False, 'text'),
 ("Light", "State.error as text",                 hexrgb('#D70015'),          L_BG,   14, False, 'text'),
 ("Light", "State.warning as text",               hexrgb('#C2410C'),          L_BG,   12, False, 'text'),
 ("Light", "State.success as icon",               hexrgb('#2E7D32'),          L_BG,   16, False, 'ui'),
 ("Light", "primary as icon",                     hexrgb('#A435D2'),          L_BG,   16, False, 'ui'),
 ("Light", "State.error as icon",                 hexrgb('#D70015'),          L_BG,   16, False, 'ui'),
 ("Light", "badge text on primarySubtle",         BLACK,                      L_BADGE,12, False, 'text'),
 ("Light", "Text.tertiary on Background.card",    over((0,0,0,0.55), L_CARD), L_CARD, 12, False, 'text'),
 ("Light", "drop-zone outline, idle",             over((0,0,0,0.55), L_BG),   L_BG,   0,  False, 'ui'),
 ("Light", "drop-zone outline, drag over",        hexrgb('#A435D2'),          L_BG,   0,  False, 'ui'),
]

# ---------- DARK: app background #000000 ----------
D_BG = BLACK
D_CARD = over((255,255,255,0.05), D_BG)
D_BADGE = over(hexrgb('#D0FF00') + (0.15,), D_BG)
cases += [
 ("Dark", "Text.primary on Background.app",       WHITE,                            D_BG,   16, False, 'text'),
 ("Dark", "Text.secondary on Background.app",     over((255,255,255,0.75), D_BG),   D_BG,   14, False, 'text'),
 ("Dark", "Text.tertiary on Background.app",      over((255,255,255,0.60), D_BG),   D_BG,   12, False, 'text'),
 ("Dark", "primary (accent) as text",             hexrgb('#D0FF00'),                D_BG,   14, False, 'text'),
 ("Dark", "State.error as text",                  hexrgb('#FF453A'),                D_BG,   14, False, 'text'),
 ("Dark", "State.warning as text",                hexrgb('#FF6B35'),                D_BG,   12, False, 'text'),
 ("Dark", "State.success as icon",                hexrgb('#4CAF50'),                D_BG,   16, False, 'ui'),
 ("Dark", "primary as icon",                      hexrgb('#D0FF00'),                D_BG,   16, False, 'ui'),
 ("Dark", "State.error as icon",                  hexrgb('#FF453A'),                D_BG,   16, False, 'ui'),
 ("Dark", "badge text on primarySubtle",          WHITE,                            D_BADGE,12, False, 'text'),
 ("Dark", "Text.tertiary on Background.card",     over((255,255,255,0.60), D_CARD), D_CARD, 12, False, 'text'),
 ("Dark", "drop-zone outline, idle",              over((255,255,255,0.60), D_BG),   D_BG,   0,  False, 'ui'),
 ("Dark", "drop-zone outline, drag over",         hexrgb('#D0FF00'),                D_BG,   0,  False, 'ui'),
]

def threshold(pt, bold, role):
    if role == 'ui':
        return 3.0, "3.0 (UI component, 1.4.11)"
    large = pt >= 18 or (pt >= 14 and bold)
    return (3.0, "3.0 (large text)") if large else (4.5, "4.5 (normal text)")

fails = []
print(f"{'Mode':<6} {'Pair':<38} {'Ratio':>7}  {'Needs':<26} Verdict")
print("-" * 92)
for mode, label, fg, bg, pt, bold, role in cases:
    r = ratio(fg, bg)
    need, needlabel = threshold(pt, bold, role)
    ok = r >= need
    if not ok:
        fails.append((mode, label, r, need))
    print(f"{mode:<6} {label:<38} {r:>6.2f}:1  {needlabel:<26} {'PASS' if ok else 'FAIL'}")

print()
if fails:
    print(f"{len(fails)} FAILING PAIR(S):")
    for mode, label, r, need in fails:
        print(f"  - {mode}: {label} = {r:.2f}:1, needs {need}:1")
else:
    print("All audited pairs meet WCAG AA.")

raise SystemExit(1 if fails else 0)
