# 01 — Design system + app shell (cockpit theme)

**Status:** done

## Goal

Give the app a visual identity rooted in its subject (DCS rotary-wing logistics / flight planning),
and put the tokens in one place so every later ticket styles through them.

## Direction

A cockpit-at-night / kneeboard instrument panel, not a generic dark theme:

- **Ground** `#0f1417` with a slightly olive-biased set of neutrals (`#171f24`, `#1e2a31`, `#2b3a43`)
  — chosen, not inherited grey.
- **Accent** caution-amber `#e8a13a` — the one bold colour, used for the active nav item, section
  rules, primary action and `on` toggles. Everything else stays quiet.
- **Semantic** avionics lamps, separate from the accent: `#5fb86b` ok, `#e5533c` error.
- **Side coding** NATO: `#4e9bd1` BLUE, `#d2503f` RED — used wherever a coalition is shown.
- **Type** a condensed/wide display face for labels and headings, the system UI face for prose, and
  a mono face for values and config keys, so a number always reads as an instrument readout.
  Font stacks only — no webfont fetch (the exe serves offline).

## Work

- `src/lib/theme.css` — all tokens as custom properties on `:root`, imported by `app.css`.
- Restyle the shell in `App.svelte`: header (brand + readouts + status lamp), left rail, content
  panel. Rounded 8–10px, hairline borders, no drop-shadow soup.
- Shared control styling (buttons, inputs, selects, toggles, tables) so the editors inherit it
  instead of each re-declaring `#c3ccda`.
- Keyboard focus must stay visible; honour `prefers-reduced-motion`.

## Done when

- No component hardcodes a hex value that exists as a token.
- The window is usable down to ~1000px wide without horizontal body scroll.
- `npm run check` and `npm test` pass.
