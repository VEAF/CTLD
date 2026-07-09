# 03 — Migrate the four scenario templates

Status: ✅ done
Type: AFK

## What to build

Migrate the four templates to the return contract (ticket 02):
`_template_scenario.lua`, `_template_noPlayer.lua`, `_template_pilotActive.lua`,
`_template_pilotPassive.lua`.

- Drop the Witchcraft guard comments and `return Witchcraft`.
- Emit the standard verdict via the contract helper; set `_G["_SCN_<ID>_RESULT"]`.
- Keep the step machinery (auto / delayed / polled / F10 human) intact — only the return path
  and the ABORT/verdict wording change.
- Reconcile CLAUDE.md: it references a single `_template_scenario.lua`; document that there are
  four category templates (noPlayer / pilotActive / pilotPassive + the generic one) and when to
  use which.

## Acceptance criteria

- [ ] All four templates emit contract-compliant verdicts, no `return Witchcraft`.
- [ ] Async template returns `STARTED` and writes the final verdict to the result variable.
- [ ] `luac5.1 -p` clean on all four (Lua 5.1).
- [ ] CLAUDE.md template guidance matches the four-template reality.

## Blocked by

Ticket 02 (contract + helper).
