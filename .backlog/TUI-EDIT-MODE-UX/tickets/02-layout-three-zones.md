# 02 — Layout: make the two axes visible

Status: ✅ done
Type: tui

Materialise the "catalogue op" axis vs the "my line" axis in the layout.

- **B1** — split the single 6-button row into three labelled zones:
  - `Catalogue` : `Ajouter…` `Retirer…` `Modifier…`
  - `Ligne sélectionnée` : `Éditer` `Supprimer`
  - `Fichier` : `Enregistrer` `Générer` `Injecter`
- **B2** — promote `Éditer` (`e`) and `Supprimer` (`Delete`) from keyboard-only to visible
  buttons (keybinds kept). Wire them to the existing `action_edit_entry` /
  `action_delete_entry`.
- **B3** — contextual enabling: the two `Ligne sélectionnée` buttons are **disabled while no
  tree line is selected**, enabled on selection (Textual `Tree.NodeHighlighted`). Catalogue
  buttons stay always-enabled. The enabled/disabled state itself teaches "these act on my
  selection, those don't". (Picker-level greying of consumed names → ticket 03.)
- **B4** — group the tree by op nature under each family with **word headers**
  (`➕ Ajoutées` / `➖ Retirées` / `✏️ Modifiées`), rendering only non-empty sub-sections,
  instead of the bare `+`/`-`/`~` glyph prefixes.

Files: `ctld_tools/tui/app.py` (compose, `_rebuild_tree`, button handlers, a
`NodeHighlighted` handler), `ctld_tools/data/locales/{en,fr}.json` (zone/header labels).
Tests: extend the TUI tests for the new tree grouping and the enabled/disabled transitions.
David validates the visual result before merge.
</content>
