# Accessibility: colour contrast

This records the WCAG 2.1 AA contrast audit behind the **"Sufficient Contrast"** accessibility
label on the App Store listing, so that tick is backed by numbers rather than by assumption.

Re-run it with:

```sh
python3 scripts/contrast_audit.py    # exits non-zero if any pair fails
```

## Scope and method

The audit covers the token pairs the app **actually renders**, in both colour schemes, not the
whole palette. Two details decide the results:

**Translucent colours are composited first.** Most of the muted tokens are `rgba`, and a colour
like `rgba(0, 0, 0, 0.55)` has no contrast ratio on its own. It has to be flattened onto the
surface actually behind it before measuring. Skipping this step is the usual way a palette gets
declared compliant when it isn't.

**The threshold depends on the role, not the colour.** Text needs 4.5:1 (3:1 when large, meaning
18pt or 14pt bold). A non-text boundary that identifies a control falls under WCAG 1.4.11 and
needs 3:1. Purely decorative elements have no requirement at all, which is exactly the
distinction the one finding below turned on.

Colour values are transcribed from `iamjarl-design` at tag **v1.2.1**, the version `project.yml`
pins. They are not read from the package at runtime, so **when that pin moves, re-transcribe the
values in the script and re-run it.**

## Results

Every audited pair meets AA.

| Mode | Pair | Ratio | Needs |
|---|---|---|---|
| Light | Text.primary on Background.app | 21.00:1 | 4.5 |
| Light | Text.secondary on Background.app | 8.45:1 | 4.5 |
| Light | Text.tertiary on Background.app | 4.74:1 | 4.5 |
| Light | primary (accent) as text | 5.23:1 | 4.5 |
| Light | State.error as text | 5.38:1 | 4.5 |
| Light | State.warning as text | 5.18:1 | 4.5 |
| Light | badge text on primarySubtle | 17.66:1 | 4.5 |
| Light | Text.tertiary on Background.card | 4.68:1 | 4.5 |
| Light | State.success / primary / State.error as icons | 5.13 / 5.23 / 5.38:1 | 3.0 |
| Light | drop-zone outline, idle / drag over | 4.74 / 5.23:1 | 3.0 |
| Dark | Text.primary on Background.app | 21.00:1 | 4.5 |
| Dark | Text.secondary on Background.app | 11.42:1 | 4.5 |
| Dark | Text.tertiary on Background.app | 7.37:1 | 4.5 |
| Dark | primary (accent) as text | 17.99:1 | 4.5 |
| Dark | State.error as text | 6.16:1 | 4.5 |
| Dark | State.warning as text | 7.41:1 | 4.5 |
| Dark | badge text on primarySubtle | 15.72:1 | 4.5 |
| Dark | Text.tertiary on Background.card | 7.25:1 | 4.5 |
| Dark | State.success / primary / State.error as icons | 7.56 / 17.99 / 6.16:1 | 3.0 |
| Dark | drop-zone outline, idle / drag over | 7.37 / 17.99:1 | 3.0 |

The narrowest margins are the light-mode muted greys, `Text.tertiary` at 4.74:1 on the app
background and 4.68:1 on a card, against a 4.5:1 requirement. They pass, but there is almost no
headroom: darkening the card surface or lightening that grey upstream would break them. Worth
re-checking on any token bump.

## The one failure found, and why it was real

The drop zone's dashed outline used `Border.subtle`, which measures about **1.25:1** in light and
**1.27:1** in dark. Far under the 3:1 that WCAG 1.4.11 asks of a UI boundary.

The tempting reading is that this is decoration and therefore exempt. It isn't. The drop zone is
the app's primary interactive target, and in its idle state that outline is the *only* thing
marking where files can be dropped. That is "visual information required to identify a user
interface component", so 3:1 applies.

Neither border token could fix it: `Border.subtle` (1.25:1) and `Border.default` (1.45:1) are
both built to be decorative dividers, and that is a legitimate job for them elsewhere. The bug
was this app using a divider token for a load-bearing boundary. So the fix belongs here, not
upstream in the shared package: the idle outline now uses `Text.tertiary` (4.74:1 light, 7.37:1
dark), which clears the bar while staying visually restrained. The drag-over state keeps the
accent colour and already passed.

## Not covered here

Contrast is one accessibility label among several. Still open: an in-app text-size control
(issue #9). VoiceOver labels and Reduce Motion are already handled in the views.
