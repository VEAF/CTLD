# 15 — In-app help, generated from the schema and the catalogue

**Status:** done

## Why

A non-technical Mission Maker opening the exe for the first time has no idea what the lamp means, why
some settings are folded away, or what "the configuration replaces the defaults completely" implies
until it bites them. The published docs cover it, but nobody reads docs while the tool is open in
front of them.

## The point: not prose

The obvious implementation — a page of hand-written text — goes stale the moment a family or a setting
is added, and nobody notices. So the help is **generated from live data**:

- setting and family counts, from the catalogue currently open;
- the family list with **the schema's own descriptions** (the `families:` section added in ticket 10),
  so it cannot drift from the navigation;
- an inventory of every structured table with its real size — 108 pilot slot names, 7 crate sections,
  9 aircraft types — which doubles as an answer to "what is actually in the config I have open?".

Add a family to the schema and the help describes it with no prose to update.

The hand-written part is limited to what data cannot express: the three steps, how to read a setting
row, what validation does, saving vs injecting, and the complete-snapshot rule (framed in amber,
because it is the one that surprises people).

## Where

`HelpPanel.svelte`, opened from a **Help** button in the header next to the language picker. Closes on
`Escape` or the button. 28 new `web.help.*` keys in both catalogs, so it is EN+FR like the rest — the
parity test covers them automatically, and it immediately flagged two new EN/FR-identical strings
("Validation", "{n} sections") which are now listed as deliberate.

## A defect it turned up

The help button exists from the first paint, i.e. possibly before the boot fetch has landed. Clicking
it that early rendered "0 settings across 0 families" — a lie dressed as a fact. The counts, family
list and inventory now appear only once a catalogue is loaded; the explanations always show.

## Done when

- Help opens in both languages, with counts and inventory matching the open catalogue.
- Component tests assert the numbers come from the fixture rather than from a constant.
- Docs mention it (EN + FR).
