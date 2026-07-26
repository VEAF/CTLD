# 12 — A picture of what the tool is for

**Status:** done

## Why

David asked whether the UI had any decoration — "une image d'hélicoptère qui dépose des troupes par
exemple". It did not: tickets 01–09 gave the app a palette, a type system and functional icons, but
nothing depicting the subject.

## Three attempts, and what each taught

**1. Hand-drawn SVG line art**, at the foot of the navigation rail. Redrawn once head-on after a
screenshot David sent. Verdict: *"mignon mais pas dingue"*, then *"non c'est moche"*. Deleted — a
decoration nobody likes is worse than none.

**2. The real photo, banded across the header.** Correctly processed and finely tuned… in the wrong
place. A header is roughly 1265×82, a 15:1 ratio; a 16:9 frame can only ever show **11%** of its
height there. David: *"dans ce bandeau on ne voit presque rien"* — and he was right. Careful tuning
of a bad decision.

**3. The photo behind the whole page** (David's suggestion), with the cards and the rail translucent
over it. The viewport is roughly 16:9, so **the entire frame is on show** — 100% of both axes instead
of 11% of one. This is what shipped.

## How it is built

- `body::before`, `position: fixed`, `z-index: -1`. Fixed positioning rather than
  `background-attachment: fixed`, which repaints the image on every scroll frame.
- Surfaces above it are translucent: `--panel-glass` (0.80) for setting rows, data cards and the step
  strip, `--panel-2-glass` (0.78) for the rail. The header stays **opaque** on purpose — it is the
  band that anchors the page.
- `--ink-faint` lifted from `#62757e` to `#7b8d96`: the photo raises the background luminance and the
  old value fell to 2.5:1 on it.

## Intensity is measured, not chosen

Photo brightness × opacity × card alpha were swept together against a contrast floor for every text
colour that ends up over the frame's brightest region (the sky). The brightest passing combination:

| Check | Ratio |
|---|---|
| ink on a card | 12.4:1 |
| muted text on a card | 5.9:1 |
| ink directly on the background | 9.5:1 |
| muted text directly on the background | 4.5:1 |
| accent on the background | 5.5:1 |

That is 2.8× more present than the first guess, which measured 13:1 everywhere because the photo was
nearly black. Turning it up further starts costing legibility.

## Asset

`web/public/hero-troop-insertion.webp` — 1920×1080 → 1600×900, WebP q74, 194 KB → 79 KB. It ships
inside the exe, so the size matters. Watermark-checked (zero vivid-green pixels in the top band). A
missing file paints nothing, so the page falls back to its gradient.
