# FIX-FAT-COW-DEPLOY-REFUSALS

**Status:** merged (PR #319). Compacted from `FIX-FAT-COW-DEPLOY-REFUSALS/` on 2026-11-23; the ticket files live on in git history.

Issue #296 (found by an automated review): the AI cow's deployment timer dropped the answer of `deploy`, so five of the six refusals (empty cow, airborne, scene, deployed, unknown) were silent, for the flight and for the log; the piloted cow's path already reported them. A flight whose cow was emptied, folded with Take off, then landed with Land here waited for an announced FARP that never came. The timer now reads the answer: an empty cow says so and advises RTB, the other refusals reuse the existing message, all are logged.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-report-a-refused-deployment` | ✅ done (PR #319) | 01 — The AI cow's deployment timer reports a refused deployment |

## PRD

## FIX-FAT-COW-DEPLOY-REFUSALS — the AI cow's deployment timer drops the reason `deploy` gave: every refusal is silent

**Status:** ✅ done (PR #319) — decisions taken in the grill of 2026-11-18 (no ADR, no `CONTEXT.md` term).

GitHub issue #296 (found by an automated review of `develop`; the code has moved since, the analysis holds).

### Problem Statement

When an AI Fat Cow lands, a timer waits for the deployment delay (60 s by default) and then asks the cow to open its FARP. The request answers either "done", or "refused" with a reason, and the timer **throws the answer away**. The reasons are six:

| Reason | Meaning | Told to the flight today |
|---|---|---|
| failed | the FARP or its fuel depot could not be added | yes: the scene's failure path tells it |
| empty | the cow has nothing left | **no** |
| airborne | the cow is in the air | **no** |
| deployed | its FARP is already open | **no** |
| scene | the scene did not start | **no** |
| unknown | no such cow | **no** |

No message to the flight, and no line in the log, for five of the six. The piloted cow's own path reads the same answer and tells its pilot: the two callers of the same contract have diverged.

The simplest way to meet it needs no DCS failure at all:

1. A flight requests an AI cow. It lands, its FARP opens, the helicopters take everything.
2. The flight orders **Take off**. The cow folds its FARP and reads the stock back from the warehouse: it is empty. Unlike the cow of an AI flight whose leader takes off, it is **not** sent home, on purpose: a player flight's cow does nothing on its own. It stays, empty.
3. Later the flight orders **Land here**. It reads "Fat Cow landing next to you: FARP open 60 s after touchdown", the cow lands, the delay runs.
4. The cow is empty, so nothing opens, nothing is displayed, and nothing is logged.

The flight waits for a FARP it was promised and never learns that the cow is empty, although **Fat Cow status** and **RTB** exist for that. On the server, the log carries no trace either: the only deployment line sits on the path that is never reached. The other four refusals are rare and silent the same way. No test makes the deployment that follows the delay fail.

### Solution

The timer reads the answer and says what happened, to the flight and to the log:

- a cow that is **empty** tells the flight so, and advises sending it home with **RTB**;
- a cow that **could not be deployed** for any other reason tells the flight so with the message it already knows;
- a cow already deployed says nothing to the flight (its FARP is open, there is nothing to tell) but is logged;
- the failure case is unchanged: it was already told, and is not told twice.

Nothing else about the cow changes: it still lands when asked, and it is not sent home on its own.

### User Stories

1. As a pilot whose flight's cow is empty, I want to be told when its FARP does not open, so that I do not wait for a FARP that will not come.
2. As a pilot, I want that message to say the cow is empty and to point to **RTB**, so that I know what to do next.
3. As a pilot, I want the message in my own language, with the name my menu gives the **RTB** command, so that I find the entry it names.
4. As a pilot whose cow could not be deployed for another reason, I want to read that the FARP could not be deployed, so that I do not wait either.
5. As a pilot, I do not want to be told twice when the FARP could not be added, so that one failure is one message.
6. As a pilot, I do not want a message when the FARP is already open, so that I am not told about something that went right.
7. As a server administrator reading the log, I want a line when a cow did not deploy after its delay, with the cow's name and the reason, so that I can tell an empty cow from a broken scene.
8. As a server administrator, I want the line at a warning level for the refusals, and at an information level when the FARP was already open, so that the log separates a problem from a curiosity.
9. As a maintainer, I want the AI cow path to honour the return contract the way the piloted cow path does, so that the two callers do not diverge.
10. As a pilot whose flight has gone by the time the delay runs out, I want nothing sent to a group that no longer exists, while the log still records the refusal.
11. As a pilot, I want a cow with stock to deploy exactly as before, with no new message and no warning, so that the nominal path is untouched.
12. As a pilot, I want **Land here** and **Take off** to behave as they do today, so that nothing else about the cow changes.
13. As a French or Spanish pilot, I want the new message translated, so that I can read it.
14. As a pilot reading the guide, I want to learn that a cow with nothing left opens no FARP and that the flight is told when the delay runs out, so that the guide stops promising a FARP unconditionally.
15. As a maintainer, I want tests that make the deployment fail for each reason, so that a refusal cannot go silent again unseen.
16. As a maintainer, I want no new setting, so that the catalogue and the saved configurations stay as they are.

### Implementation Decisions

- **The timer reports the answer.** After the delay, it reads what the deployment returned. When the deployment is refused, it tells the flight the cow serves, if that flight still exists, and writes a line in the log whether the flight exists or not.
- **Per reason:**
  - *empty*: a dedicated message to the flight, a new translated text ("The Fat Cow is empty: send it home with RTB."), and a warning line;
  - *airborne*, *scene*, *unknown*: the existing message "The Fat Cow FARP could not be deployed." (already translated), and a warning line that names the reason;
  - *deployed*: no message, an information line;
  - *failed*: unchanged. The scene's failure path has already told the audience; no second message, and no extra line is required.
- **Rejected: one dedicated message per reason.** It would add three or four new texts to translate for cases that almost never happen.
- **Nothing else changes.** There is no immediate refusal in **Land here** when the cow is empty (a new behaviour the issue does not ask for, possible later as a separate improvement), and the cow is not sent home when it folds its FARP while empty: that contradicts the documented principle that a player flight's cow does nothing on its own.
- **The message names the RTB command as the pilot's menu does**, since the command is translated there ("RTB" in English, "Rentre à la base" in French, "Regresa a la base" in Spanish, "기지로 귀환" in Korean). The new text is one literal passed to the translation function (the dictionary generator cannot read a concatenation):
  - English: "The Fat Cow is empty: send it home with RTB."
  - French: "La Fat Cow est vide : renvoyez-la avec « Rentre à la base »."
  - Spanish: "El Fat Cow está vacío: envíalo de vuelta con « Regresa a la base »."
  - Korean: "Fat Cow가 비었습니다. « 기지로 귀환 »으로 돌려보내세요." (written by the assistant, flagged for review in the pull request).
  The dictionaries are regenerated by the build.
- **Log lines** are in English, untranslated, with the levels the file already uses: a warning "CTLDFatCowManager: cow '<name>' did not deploy after the delay: <reason>", and an information line "CTLDFatCowManager: cow '<name>' already deployed when its delay ran out" for the *deployed* case.
- **Documentation.** One sentence in the pilot guide (English and French), by the **Land here** command: a cow with nothing left opens no FARP, and the flight is told when the delay runs out, with the advice to send it home with **RTB**. Today the guide only promises that the FARP opens one minute after touchdown.
- **CHANGELOG**: one *Fixed* entry under `[Unreleased]`. No configuration key: no `configVersion` change, no catalogue shape.

### Testing Decisions

- **A good test** observes what the flight reads and what the log says, not the internals of the timer.
- **Seam**: the existing AI Fat Cow spec, in which the cow lands and the scheduled timers can be run by hand; its scene is a double that can be made to refuse. Logs are captured the way the clearing-search specs capture them.
- **Cases, red first for the right reason** (today nothing is said and nothing is logged):
  - *empty*: the stock is emptied before the timer runs; the flight reads the empty-cow message, and a warning names the reason;
  - *airborne*: the cow unit reports being in the air when the timer runs; the flight reads the generic message and a warning names the reason;
  - *scene*: the scene fails to start; same;
  - *unknown*: the cow is no longer registered while its unit exists; same;
  - *deployed*: the cow is already deployed; no message, an information line;
  - *failed* (control): the FARP or fuel depot cannot be added; the flight reads exactly one message, the scene's, and the timer adds none;
  - the flight is gone: no message, the line is logged anyway;
  - nominal path: a cow with stock deploys, with no warning and no refusal message; the existing nominal and cancellation tests pass unchanged.
- **No live DCS check**: the path depends on a timer and on the cow's state, both covered by the unit tests. The pull request says so.

### Out of Scope

- An immediate refusal in **Land here** for an empty cow.
- Sending an empty cow home when it folds its FARP.
- The ground test of the cow (#295).
- The piloted cow's path, which already reports.
- Changing the return contract of the deployment or its reasons.
- Retrying a failed deployment, or refilling a cow.

### Further Notes

- One ticket is planned; the `to-issues` quiz is short.
- The reasons *airborne*, *scene*, *unknown* and *deployed* are rare. The generic message and the log line are enough for them: they cost one existing text and two lines, and keep the contract honoured on both callers.
