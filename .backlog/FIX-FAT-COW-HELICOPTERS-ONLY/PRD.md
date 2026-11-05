# FIX-FAT-COW-HELICOPTERS-ONLY — an aeroplane gets no Fat Cow menu

Status: done — 2026-11-04 (PR #285); verified in game by Zip, 2026-11-05

## Problem

Zip, in an A-10 on an Open Training (2026-11-01), could request a Fat Cow.
`CTLDFatCowManager:buildMenuSection` gave the AI Fat Cow menu (request, orders, status) to every player who was not a cow pilot, and the pilot guide said so ("Any player whose aircraft is not a cow").
The cow refuels and rearms helicopters: an aeroplane has nothing to do with it.
Taking a cow over was already a helicopter's only (FEAT-FAT-COW-TAKEOVER, Zip 2026-10-30).

## Solution

- The AI Fat Cow menu is built for a helicopter only, with the test taking a cow over uses (`isHelicopter`, now defined before the menu code).
- `requestAICow` sends nothing for an aircraft that is not a helicopter, in case a menu built for another aircraft is still on screen.
- A mission-placed cow escorting a client flight is commanded from that menu: the mission-maker guide says to escort a helicopter flight.

## Definition of done

- busted: an aeroplane sees no Fat Cow menu, a helicopter sees "Request a Fat Cow"; a request from an aeroplane creates no cow.
- Docs: pilot and mission-maker Fat Cow pages, EN + FR; CHANGELOG.

## Not claimed

Not flown: the check is the next session on a server running a CTLD with this fix.
