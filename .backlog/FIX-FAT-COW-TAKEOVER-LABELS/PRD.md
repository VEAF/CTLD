# FIX-FAT-COW-TAKEOVER-LABELS — the "Take over a Fat Cow" entries are rebuilt under the pilot's finger, and two cows can share a label

**Status:** ⬜ ready — decisions taken in the grill of 2026-11-18 (no ADR: the rule "a label is an identity, so nothing that moves goes in it" already follows from [ADR 0027](../../dev/adr/0027-stable-f10-entries.md) decision 1; no `CONTEXT.md` term: it has no Fat Cow vocabulary).

GitHub issue #298 (found by an automated review of `develop`; the code has moved since, the analysis holds).

## Problem Statement

A helicopter flight with no Fat Cow finds, under *Fat Cow → Take over a Fat Cow*, one entry per AI cow that is going home (sent RTB, or lost its flight) or that its flight released. Each entry is labelled with the cow's distance rounded to the kilometre ("Fat Cow 12 km away, going home to Akrotiri"), the list is sorted nearest first, and a timer rebuilds the menu of every flight that may take a cow over every 30 seconds.

Since ADR 0027, **an F10 entry's label is its identity**: a changed label means the entry is removed and created again, its DCS id freed and "parked". Three defects follow.

1. **The pilot clicks into the void.** A cow flying home covers about 2 km per 30 s cycle, so the rounded kilometre changes at almost every refresh. The entry is recreated, and a click from an F10 screen left open fires a parked command: nothing happens, an INFO line is logged, `takeOverAICow` is never called, and the pilot gets neither "Fat Cow joining your flight" nor "This Fat Cow is no longer available". ADR 0027 accepted that cost for changes triggered by an event, not for a timer, on the one entry whose whole purpose is to be read and then clicked, four F10 levels deep. Every removal also adds a parked command for the life of the mission; a released cow never expires, so a coalition with idle helicopter pilots piles up to 120 of them an hour per pilot.
2. **Two cows can swap, and the pilot takes the other one.** Two cows at the same rounded kilometre get the same label, so their keys are positional and follow the distance sort. If their ranks swap between two refreshes, the keys do not move, the entries are kept, but each is relinked to the other cow. The labels being word for word identical, nothing tells the pilot.
3. **The order would bring the defect back** (found in the grill, not in the issue). Even with unique labels, "nearest first" depends on the distance, and ADR 0027 recreates the entries that fall out of the wanted order, so two cows swapping rank would recreate entries again, through the sort.

The tests do not see any of this. The Fat Cow specs drive the entries against a fake menu that keeps only a label and a cow name, with no keys and no memory of the previous rendering, and one of them asserts the very behaviour that produces the defect (that the timer rebuilds the menu). The double that can see it exists in the repository: the one that recycles ids as DCS does, used by the stable-entries spec.

## Solution

The entry names the cow, never its distance, and the list stops moving under the pilot:

- each AI cow has a **number**, and the entry reads "Fat Cow #3 — going home to Akrotiri", "Fat Cow #3 — going home" or "Fat Cow #3 — waiting" (released);
- the list is in the **order of the numbers**, not of the distances;
- the **periodic refresh is gone**: the menu is rebuilt only when something happens (a cow released, taken over, arrived, lost), as it already is;
- the **distance stays where the pilot needs it**: in the message a flight receives when a cow loses its flight or is released, and in the confirmation of the take-over. The three announcement messages now name the cow with the same number, so the pilot can tell which entry it is.

A pilot who reads the list and clicks always reaches the cow the entry names, and a click that cannot be honoured always answers.

## User Stories

1. As a helicopter pilot, I want the entry I read under "Take over a Fat Cow" to stay the same entry while I read it, so that my click takes the cow I chose.
2. As a helicopter pilot, I want a click on an entry whose cow went away to tell me "This Fat Cow is no longer available", so that I am never left clicking into the void.
3. As a helicopter pilot, I want each cow to be named in the list, so that two cows are never identical on screen.
4. As a helicopter pilot, I want the entry to tell the cow's state (waiting, going home, going home to a named base), so that I can tell a released cow from one flying home.
5. As a helicopter pilot, I want the entries in a fixed order, so that the one I looked at is still where I saw it.
6. As a helicopter pilot, I want the message I get when a cow loses its flight or is released to name the cow, so that I can find its entry in the list.
7. As a helicopter pilot, I want that message to keep the distance and bearing of the cow from me, so that I can decide whether to take it over.
8. As a helicopter pilot, I want the confirmation of the take-over to keep telling the distance, the time to join and the stock, so that I know what I took.
9. As a helicopter pilot, I want a cow the mission maker placed to be named like the others, so that every cow in the list reads the same way.
10. As a helicopter pilot, I want the same cow to keep its number as long as it exists, so that I can follow it between messages and menus.
11. As a mission maker, I want my own group names for placed cows left alone, so that my mission's naming contract is unchanged.
12. As a mission maker, I want the group names of requested cows unchanged, so that scripts and logs that read them keep working.
13. As a maintainer, I want the menu not to be rebuilt every 30 s for a distance nobody can read in time, so that no entry is recreated and no parked command piles up for nothing.
14. As a maintainer, I want the label to carry only what changes on an event, so that ADR 0027's cost stays limited to what it accepted.
15. As a maintainer, I want the menu still rebuilt on every event that changes the set of cows that can be taken over, so that removing the timer leaves no stale entry.
16. As a maintainer, I want a test that sees the menu the way DCS does and fails when an entry is recreated for nothing, so that the defect cannot come back unseen.
17. As a maintainer, I want the tests that assert the removed behaviour (a distance in the label, the 30 s refresh) rewritten and not kept, so that the suite describes the menu as it now is.
18. As a French or Spanish pilot, I want the new labels and messages translated, so that the menu reads in my language.
19. As a pilot reading the guide, I want the documentation to describe the list as it now is (stable entries, ordered by number, no distance in the menu), so that I do not look for a distance that is not there.
20. As a maintainer, I want no new configuration key, so that the catalogue version and the saved configurations stay as they are.

## Implementation Decisions

- **Entry = identity.** The label of a "Take over" entry is "Fat Cow #N — " followed by its state; it never carries a distance or anything that moves between events. The three states are the three cases that exist: waiting (released), going home to a named base, going home (no base known). The state changes only on an event (the cow is released, taken over, or arrives), which ADR 0027 accepts.
- **Stable order.** Entries are ordered by cow number, ascending: the order in which the cows were registered. "Nearest first" is dropped.
- **Cow number.** Every AI cow gets a number when it is registered, drawn from the counter that already numbers the group names of requested cows. A requested cow keeps exactly the number of its group name ("Fat Cow <flight> #N"); a cow placed by the mission (`fatCowAICows`, the VMCT contract) takes the next number when it is activated, in the order of that list. The number is kept on the cow, which it is not today. The mission maker's group name is never shown to pilots, and a requested cow's group name does not change.
- **No periodic refresh.** The timer that rebuilds the menus every 30 s, its period, the function it calls and the parameter that restricted a rebuild to candidate pilots (used only by that function) are removed. Every change to the set of cows that can be taken over already rebuilds the menus on an event: a cow destroyed or vanished, its arrival at home, its return home, its release, a take-over. A click on an entry whose cow is gone already answers "This Fat Cow is no longer available."
- **Announcements name the cow.** The three messages sent to the flights that could take a cow over (released; lost its flight and going home to a base; lost its flight and going home) carry the cow's number, in the same words as the entry ("Fat Cow #3 lost its flight and is going home to Akrotiri: 12.4 km at 270° from you, with …"), and keep their distance and bearing. The confirmation of a take-over is unchanged.
- **Texts.** The three labels and the three announcement messages are new or changed texts: each a single literal passed to the translation function (the dictionary generator cannot read a concatenation). The dictionaries are regenerated by the build; French and Spanish are provided, Korean is written by the assistant and flagged for review; the old keys go stale in the dictionaries.
- **Documentation.** The pilot guide (English and French) paragraph that promises "one entry per cow, nearest first, with its distance from you (updated every 30 s)" is rewritten: one stable entry per cow, in the order of their numbers, named with its number and state; the distance comes in the message the flight receives and in the confirmation. The mission maker's page that mentions the take-over is adjusted only if it claims the distance.
- **CHANGELOG**: one *Fixed* entry under `[Unreleased]`. No configuration key: no `configVersion` change, no catalogue shape.
- **Parked commands**: fewer removals now; nothing else to do about ADR 0027's pool.

## Testing Decisions

- **A good test** observes the menu the way DCS does: which entries are created and removed, and which cow a click reaches. It does not call the internal helpers of the manager.
- **Seam**: the real menu rendering against the `missionCommands` double that recycles ids as DCS does (the one the stable-entries spec uses, mutation-checked under ADR 0027). The Fat Cow AI spec keeps the unit-level cases that do not depend on the rendering (the numbers, the announcements, the take-over itself).
- **Regression test, red before the change for the right reason**: two successive refreshes of the take-over submenu, with a cow that came closer between them, then check that no entry was created or removed. Today the label carries the distance, changes, and the entry is recreated.
- **Cases**:
  - two cows in the same state get two distinct labels;
  - the order is the same whatever the distances, even when they invert;
  - after the cows swap distance ranks, the first entry still takes the cow it names;
  - the label carries the number and the state, for each of the three states;
  - the periodic refresh is no longer registered;
  - a requested cow keeps the number of its group name; a mission-placed cow gets the next number from the same counter, in the order of `fatCowAICows`;
  - the announcements name the cow and keep the distance and bearing;
  - the take-over itself behaves as before.
- **Rewritten, not preserved**: the existing assertions on the old labels with a distance, and the test that "updates the distances every so often", assert the behaviour being removed.
- **No live DCS check**: F10 cannot be read from the DCS bridge, and the double is the reference since ADR 0027. The pull request says the on-screen result was not checked in a mission.

## Out of Scope

- The other Fat Cow issues: the ground test of the cow (#295), the return value of its deployment (#296), the empty `fatCowAIType` that hides the whole menu (#297).
- Who may take a cow over, and which cows can be taken over; the take-over mechanics themselves.
- A distance anywhere new in the menu.
- The pagination of ADR 0027 and its pool of parked commands.
- A cow's identity in any other message than the three announcements listed above.

## Further Notes

- The ordering by number replaces "nearest first" on purpose: ADR 0027 recreates entries that leave the wanted order, so any order that depends on a moving value would bring the dead click back. The pilot loses the at-a-glance distance in a list that rarely holds more than one or two cows, and keeps it in the message the flight received.
- Two tickets are proposed, to confirm with the user in the `to-issues` quiz: 01 the cow's number and the announcements that name it; 02 the stable take-over list (labels, order, removal of the refresh, the regression test, the documentation).
