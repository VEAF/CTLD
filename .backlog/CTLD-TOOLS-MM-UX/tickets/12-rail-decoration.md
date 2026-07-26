# 12 — A picture of what the tool is for

**Status:** in progress — waiting on the image file

## Why

David asked whether the UI had any decoration — "une image d'hélicoptère qui dépose des troupes par
exemple". It did not: tickets 01–09 gave the app a palette, a type system and functional icons, but
nothing depicting the subject.

## First attempt, rejected

Hand-drawn SVG line art of a transport helicopter with a slung crate, at the foot of the navigation
rail. Redrawn once head-on (after a DCS screenshot David sent) because the first profile version read
flat. Verdict: *"mignon mais pas dingue"*, then *"non c'est moche"*. Removed — a decoration nobody
likes is worse than none.

Worth keeping from that round: the placement finding. As a header watermark the drawing landed **under
the readouts** on a 1280px window (the header's spare middle is only ~198px), which is why the photo
now uses a masked scrim instead of sitting behind the text unprotected.

## Current approach: the real thing

A DCS screenshot — Mi-8 in the hover, crate on the hook — banded across the header:

- `.bar::before` carries the frame, `::after` a left-to-right scrim, content above both.
- Framed low and right (`background-position: 62% 68%`) so the source frame's third-party watermark
  is cropped out and the airframe sits where the header is otherwise empty.
- `filter: saturate(.4) contrast(1.08) brightness(.62) sepia(.16)` pulls a bright daylight photo into
  the panel's palette.
- `mask-image` dissolves it leftwards so it never competes with the brand or the readouts.
- **Missing asset degrades silently**: a CSS background that does not resolve paints nothing, so the
  header falls back to its gradient. No broken-image box, no build failure.

## Provenance

Raised with David that the frame carries a third party's watermark and this repo ships publicly; he
decided to use it. Noted here rather than argued: it is the maintainer's call. The crop removes the
watermark either way.

## Remaining

Drop the file at `tools/ctld-tools/web/public/hero-slingload.jpg`. Then: crop the watermark in pixels
rather than only in CSS, resize to ~1600px wide and compress (Pillow and ffmpeg are both available),
and re-measure the header contrast with the photo actually in place.
