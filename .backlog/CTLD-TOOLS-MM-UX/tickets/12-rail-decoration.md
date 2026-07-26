# 12 — A picture of what the tool is for

**Status:** done

## Why

David asked whether the UI had any decoration — "une image d'hélicoptère qui dépose des troupes par
exemple". It did not: tickets 01–09 gave the app a palette, a type system and functional icons, but
nothing that depicts the subject. For a tool whose whole purpose is helicopter troop insertion and
sling-loading, that is a missed opportunity.

## Work

`RailArt.svelte` — hand-authored SVG line art: a transport helicopter in the hover with two troopers
descending on fast ropes. Stroked in the accent amber, no fill, so it reads as a technical sketch
rather than clip-art, and it needs no raster asset (the exe serves offline).

**Placement was measured, not assumed.** It started as a header watermark; on a 1280px window the
header's spare middle is only ~198px wide and the drawing landed *under the readouts* — a watermark
beneath figures a MM is reading is worse than none. Moved to the foot of the navigation rail: real
empty space, never text on top, verified with getBoundingClientRect (inside the rail, below the last
family, zero overlap with any nav button). Hidden below 1000px, where the rail collapses to a
horizontal bar.

Sized 210px wide at 22% opacity — present enough to give the app a subject, quiet enough that the
amber accent still means "this is interactive".

## Done when

- The art renders inside the rail, below the family list, overlapping no control.
- No horizontal body scroll at 1280px.
- Aesthetics reviewed by David (a standalone preview SVG was sent, since the agent cannot see the
  rendered page).
