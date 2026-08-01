# TUI-EDIT-MODE-UX

**Status:** merged (PR #63). Compacted from `TUI-EDIT-MODE-UX/` on 2026-08-01; the ticket files live on in git history.

Lever l'ambiguïté du modèle d'édition du TUI `ctld-tools` (retours FullGas 2026-07-23) : le TUI édite un **diff** (add/remove/patch contre le catalogue CTLD) mais l'UI le présente comme la liste effective. On garde le modèle diff (D2) et on rend l'UI explicite : copy + `…` sur les boutons catalogue, layout 2 axes (Catalogue / Ligne sélectionnée / Fichier) avec Éditer/Supprimer visibles + activation contextuelle, garde-fous anti-doublon remove **et** patch (prévention dans les pickers + block+message), feedback + auto-sélection, et **formulaire de modif complet pré-rempli** (valeurs actuelles + défaut CTLD en hint).

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-copy-dialogs` | ✅ done | 01 — Copy & dialogs: name the object, signal the dialog |
| `02-layout-three-zones` | ✅ done | 02 — Layout: make the two axes visible |
| `03-guards-dedup` | ✅ done | 03 — Guards & dedup (core bug fix) |
| `04-feedback-autoselect` | ✅ done | 04 — Feedback loop after a catalogue op |
| `05-prefill-modify-form` | ✅ done | 05 — Pre-filled modify form (core feature request) |

## PRD

## Lot TUI-EDIT-MODE-UX — disambiguate the ctld-tools TUI edit model

Status: ✅ merged (PR #63)
Branch: feature/tui-edit-mode-ux → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`). Follows the
`CTLD-TOOLS-*` line (TUI shipped in PR #52, polished in PR #55).

### Problem Statement

FullGas (MM field-testing the TUI, 2026-07-23) reported two things that share **one root
cause**: the TUI edits an **ops/diff document** (`add` / `remove` / `patch` buckets against
the CTLD default catalogue), but the UI presents that model as if it were the effective
crate/troop list.

1. **Bug (repro):** to delete a line he had just created, he pressed the **Retirer**
   (remove) button and picked the troop name — which *appended* a new remove-op instead of
   deleting his line. Repeating it appended a 2nd and 3rd line. Root cause: the
   Add/Remove/Patch buttons are **declarative and append-only** (they act on the catalogue,
   not on the selected tree line); deleting/editing a line is a **separate, keyboard-only**
   path (`Delete` / `e`).
2. **Feature request:** the **Modifier** (patch) form asks for a raw field name + value —
   the MM must know the attribute names by heart — whereas **Ajouter** shows every field as a
   labelled input. He asks that *modify* reuse the *add* form, pre-filled with current
   values, generalised to crates, troop groups and list-settings.

Design decisions (David, this session): keep the diff model; make the UI explicit and
unambiguous instead. Mode = **Operate**. Design lens borrowed from the `impeccable` skill
(`clarify` + `critique`), adapted to a Textual TUI (not a web surface).

### Tickets

| # | Scope | Nature |
|---|-------|--------|
| 01 | **Copy & dialogs** — `…` suffix on the 3 catalogue buttons (opens a dialog, does not act on selection); dialog titles name the object ("an element **of the CTLD catalogue**"); a permanent subtitle over the tree naming the diff model. i18n EN+FR. | tui + i18n |
| 02 | **Layout: two axes made visible** — split the 6-button row into 3 zones (Catalogue / Selected line / File); promote `Éditer`/`Supprimer` to visible buttons; contextual enabling (line-ops greyed until a tree line is selected); group the tree by op nature with word headers (Ajoutées / Retirées / Modifiées), non-empty only. | tui |
| 03 | **Guards & dedup (core bug)** — reject a duplicate remove-op (C1) and a duplicate patch-op (C2, block + message, no reroute); reject empty/invalid ops (C3); **prevention upstream** (B3): in the Retirer/Modifier pickers, names already consumed in the diff are greyed/unpickable, so a duplicate is unreachable — block+message stays the safety net. | editmodel + tui + tests |
| 04 | **Feedback loop** — after a catalogue op, toast what happened and **auto-select the new line** in the tree. | tui |
| 05 | **Pre-filled modify form (core feature)** — Modifier opens the full Add form, pre-filled with the entry's current values; the **CTLD default shown as a hint** per field label. Reference gains full default entries by name (troop_by_name + full crate entry). Generalised to crates, troops and list-settings. | reference + tui + tests |

### Decisions

- **D2** — keep the ops/diff model; disambiguate the UI, no WYSIWYG rewrite (deferred).
- **C2** — a duplicate patch-op is **blocked with a message** (parity with remove), not
  rerouted to editing the existing line.
- **B3 (extended)** — the anti-duplicate rule is enforced *upstream* by greying already-used
  names in the Retirer/Modifier pickers (error prevention), with block+message as fallback.
- **D4** — the modify form pre-fills the **current** value in the input; the **CTLD default**
  is shown as a hint in the field label (e.g. `aa  (défaut CTLD : 2)`).
- **B1/B4** — the layout reorganisation is in scope (David to validate the result visually).

### Non-goals

- WYSIWYG rewrite (edit the resolved effective list, derive the diff underneath) — the deeper
  D2 option, explicitly deferred.
- Runtime (`src/`) changes: this lot is `tools/ctld-tools` only. No `CHANGELOG.md`/
  `changelog-guard` obligation (that gate is `src/`-scoped).
- Any change to the generated `CTLD_userConfig.lua` op semantics (`genuser` runtime calls).
</content>
</invoke>
