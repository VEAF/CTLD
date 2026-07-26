# 06 — Guided workflow: auto-load, step strip, primary action, save state

**Status:** done

## Goal

Answer the three questions the current UI leaves open for a non-technical user: what is this tool
for, where am I, and is my work safe? (findings 3, 4, 10)

## Work

**Boot into a usable state.** On mount, after the schema, load the default catalogue automatically.
No more "Load the defaults or open a config file to begin." wall. A failure to boot shows a plain
error with what to do next, not a stringified exception.

**Step strip** under the header: `1 Load — 2 Adjust — 3 Inject into your mission`, current step
highlighted, completed steps ticked. Step 1 is done as soon as a catalogue is loaded; step 3
completes on a successful injection. The strip is the explanation of the tool, not decoration —
it encodes the actual sequence.

**One primary action.** `Inject into mission…` is the visually primary button (amber). `Open…` and
`Save as…` are secondary. Wording moves from file-format vocabulary to user intent:
- `Load defaults` → `Start from CTLD defaults`
- `Open…` → `Open a config file…`
- `Save…` → `Save as…`
- `Inject to .miz…` → `Inject into mission…`

**Save state** in the header: the loaded file name (or "CTLD defaults"), and one of
`No changes` / `Unsaved changes` / `Saved`. Any edit flips it to `Unsaved changes`; a successful save
flips it to `Saved`. This is the missing answer to "did I save?", given that edits are applied to
the in-memory catalogue immediately.

**Confirm before losing work**: opening another file or starting from defaults while there are
unsaved changes asks first.

**Injection feedback**: on success, a clear confirmation naming the mission file and telling the MM
what happens next (the config is applied at mission start). On the backend's 422
("fix validation errors before injecting"), point at the validation panel instead of echoing the
raw detail.

## Done when

- A component test asserts the app renders a populated family list with no user interaction.
- Save-state transitions are tested (edit → unsaved, save → saved).
- The unsaved-changes guard is tested on both `Open` and `Start from defaults`.
