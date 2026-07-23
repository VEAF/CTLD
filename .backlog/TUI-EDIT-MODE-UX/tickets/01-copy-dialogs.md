# 01 — Copy & dialogs: name the object, signal the dialog

Status: ✅ done
Type: tui + i18n

Cheapest, highest-leverage lever: make the words carry the model.

- **A1** — append `…` to the three catalogue buttons: `Ajouter…` / `Retirer…` /
  `Modifier…` (EN `Add…` / `Remove…` / `Patch…`). Universal convention: "opens a dialog,
  does not act on the current selection".
- **A2** — dialog titles name the object as the **catalogue**, not the selection.
  `tui.choose.remove` / `tui.choose.patch` and the picker/form titles reword to make clear
  the target is a CTLD default (e.g. "Which element **of the CTLD catalogue** to hide?"),
  distinguishing *Retirer* = mask a default from *Supprimer* = delete my line.
- **A3** — a permanent one-line subtitle over the config tree: *"You are editing the deltas
  to the CTLD catalogue — everything else keeps its default value."* (EN + FR).

Files: `ctld_tools/tui/app.py`, `ctld_tools/tui/forms.py`,
`ctld_tools/data/locales/{en,fr}.json`. No new logic → covered by existing TUI tests +
i18n key-parity check; add an assertion that every new key exists in both locales.
</content>
