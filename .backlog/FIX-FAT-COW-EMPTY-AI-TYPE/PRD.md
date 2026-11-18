# FIX-FAT-COW-EMPTY-AI-TYPE — an empty `fatCowAIType` removes the whole Fat Cow menu from the pilots a cow serves, not just "Request a Fat Cow"

**Status:** ✅ done (PR #318) — decisions taken in the grill of 2026-11-18 (no ADR, no `CONTEXT.md` term).

GitHub issue #297 (found by an automated review of `develop`; the code has moved since, the analysis holds).

## Problem Statement

`fatCowAIType` is the DCS type of the helicopter brought in when a flight requests an AI Fat Cow. The three places that document it say that **an empty value only removes the command "Request a Fat Cow"**: the mission maker's guide (English and French) and the description the `ctld-tools` editor shows next to the setting.

In the code, an empty value makes the whole AI cow menu return before its submenu is even created. The **Fat Cow** branch disappears for every helicopter pilot that is not a cow pilot: the Apache, Ka-50 and Mi-24P pilots, the very pilots the feature serves. They lose, at once:

- **Request a Fat Cow**, the only command that needs the type;
- **Land here, Take off, Hold here, Join us, Fat Cow status, RTB, Release the Fat Cow**;
- **Take over a Fat Cow**;
- **FARP status**, which depends on no AI cow at all: it reads every cow FARP, those of piloted cows included, and the pilot guide promises it "in the same menu".

An empty `fatCowAIType` is the documented way to open only **piloted** cows: a server with player CH-47s and no AI cow. It is an intended configuration, not an edge case. An Apache pilot who lands on the FARP of a piloted cow then has no Fat Cow menu, and no way to read what the FARP still holds before asking for a rearm. It is not a loud failure: the menu is simply absent, and the pilot concludes that the guide lags behind the code or that his server turned Fat Cow off.

One more case, not in the issue, found in the grill: **cows placed by the mission** (`fatCowAICows`, the VMCT contract) do not look at `fatCowAIType` and work with an empty one. The pilots they serve lose the same commands, so they cannot command their own cow at all. That is the configuration of a server that only uses placed cows.

No test covers an empty `fatCowAIType`: the AI cow specs set a type, and the piloted-cow spec only builds the piloted menu.

## Solution

An empty `fatCowAIType` removes **only "Request a Fat Cow"**, as the three texts already say:

- the **Fat Cow** submenu stays, with every other command: Land here, Take off, Hold here, Join us, Fat Cow status, FARP status, RTB, Release the Fat Cow, and Take over a Fat Cow when there is a cow to take over;
- those commands already defend themselves: with no cow in the flight they answer "Your flight has no Fat Cow.";
- the three texts are made complete, so that the mission maker also learns why the other commands stay.

## User Stories

1. As a pilot of a helicopter a cow serves, I want the Fat Cow menu to stay when the server has no AI cow type, so that I still find the commands that do not depend on it.
2. As a pilot, I want **FARP status** whatever the server's AI cow setting, so that I can read what the FARP I am at still holds before I ask for a rearm.
3. As a pilot on a server that only places cows in its missions, I want Land here, Take off, Hold here, Join us, Fat Cow status, RTB and Release the Fat Cow, so that I can command the cow my flight was given.
4. As a pilot, I want a cow that lost its flight to stay available under Take over a Fat Cow when the server has no AI cow type, so that a placed cow is not lost for everyone.
5. As a pilot of a flight with no cow, I want the commands that need one to answer "Your flight has no Fat Cow.", so that I am told, not ignored.
6. As a pilot on a server that opens no AI cow, I do not want to be offered "Request a Fat Cow", since it could only fail.
7. As a mission maker who opens only piloted cows, I want to empty `fatCowAIType` and lose only the request command, so that the rest of the menu serves my pilots.
8. As a mission maker who places cows in the mission, I want the setting to be irrelevant to them, so that I do not have to give an AI type I will never use.
9. As a mission maker, I want the guide to say that the other commands stay and why, so that I understand what my pilots will see.
10. As a mission maker reading the setting in the `ctld-tools` editor, I want the description to match what the game does, so that ticking the box does not remove seven more commands than announced.
11. As a French mission maker, I want the same precision in French, so that the French guide and editor say what the English ones say.
12. As a maintainer, I want the guard that protects the creation of an AI cow to sit on the one command that needs it, so that the menu does not depend on a setting it has no use for.
13. As a maintainer, I want the menu labels and their order unchanged, so that nothing else moves for the pilots.
14. As a maintainer, I want tests for an empty `fatCowAIType`, so that the menu cannot disappear unseen again.
15. As a maintainer, I want no new setting, so that the catalogue version and the saved configurations stay as they are.

## Implementation Decisions

- **The guard moves down.** The AI cow menu no longer returns when `fatCowAIType` is empty. It builds the **Fat Cow** submenu and every command as before, and leaves out only the **Request a Fat Cow** submenu with the loadout commands under it, the only part that needs the type.
- **Everything else is unchanged**: the labels, the order numbers, the **Take over a Fat Cow** submenu (still shown when a cow can be taken over), and the answer "Your flight has no Fat Cow." of the commands a flight without a cow clicks. A server with no AI cow at all sees commands that only answer that: the accepted cost.
- **Rejected: keeping only FARP status** when the type is empty. It would leave placed cows uncommandable, or need a condition on a second state ("empty type and no placed cow") that multiplies the cases to document and to test.
- **The texts**, four places, aligned with what the game does:
  - the mission maker's guide, English: "Type of the helicopter brought in when a flight requests a cow. Empty removes **Request a Fat Cow** only: the other commands stay (a cow placed in the mission needs no type, and **FARP status** needs no AI cow).";
  - the same guide, French: "Type de l'hélicoptère amené quand une patrouille demande une cow. Vide, seule **Demander une Fat Cow** disparaît : les autres commandes restent (une cow placée dans la mission n'a pas besoin de type, et **Statut FARP** n'a besoin d'aucune cow IA).", the two command names being those of the French dictionary;
  - the description of the setting in the `ctld-tools` schema, English and French: the same content, with a mention of `fatCowAICows` (for example: "DCS type of the helicopter brought in when a flight requests a Fat Cow. Empty removes only the Request a Fat Cow command; the other commands stay, for the cows placed in the mission (fatCowAICows) and for FARP status.", and its French equivalent).
  The pilot guide (English and French) is adjusted only if it claims something this contradicts.
- **No configuration change.** A schema description is not part of the catalogue shape: no `configVersion` change, no catalogue shape file. The menu labels are unchanged and the guide and schema texts are not in the dictionaries, so no dictionary change either; the build is still run before the pull request to confirm there is no drift.
- **CHANGELOG**: one *Fixed* entry under `[Unreleased]`.

## Testing Decisions

- **A good test** observes what the pilot sees in the menu and what a click does, not the internals of the menu builder.
- **Seam**: the existing AI Fat Cow spec, with its fake menu that collects the labels and its settings table, where the type can be emptied for the case.
- **Cases, red first for the right reason** (today the whole menu is absent):
  - with an empty `fatCowAIType`, a helicopter flight with no cow sees the Fat Cow submenu with FARP status, Land here, Take off, Hold here, Join us, Fat Cow status, RTB and Release the Fat Cow, and neither **Request a Fat Cow** nor its loadout commands;
  - control: with the default type the menu is as it was, **Request a Fat Cow** included;
  - with an empty type, **Take over a Fat Cow** still appears when a cow can be taken over;
  - end to end, with an empty type and a cow placed by the mission (`fatCowAICows`), the pilot's **Land here** reaches the cow, which lands;
  - with an empty type and no cow, **Fat Cow status** and **Land here** answer "Your flight has no Fat Cow.".
- **No live DCS check**: F10 cannot be read from the DCS bridge. The pull request says the on-screen result was not checked in a mission.

## Out of Scope

- The other Fat Cow issues: the ground test of the cow (#295) and the return value of its deployment (#296).
- Changing which commands exist, their labels or their order.
- The piloted cow's menu (`fatCowTypes`), which does not depend on `fatCowAIType`.
- Hiding the commands that need a cow when there is none.
- Making `fatCowAIType` required or validating it: an empty value stays valid.

## Further Notes

- One ticket is planned; the `to-issues` quiz is short.
- The guard was almost certainly written at the top of the function to protect the creation of the AI cow, whose request command is the only one that needs the type; the commands added around it afterwards ended up behind it.
