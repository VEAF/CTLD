# 04 — Feedback loop after a catalogue op

Status: ✅ done
Type: tui

Close the loop so the MM sees *what* happened and *where*.

- **D1** — after a successful catalogue op (add / remove / patch), `notify(...)` a short
  confirmation naming the target (e.g. *"Retrait de « 2x - Anti Air » ajouté au diff"*) and
  **auto-select the newly created line** in the tree so it is visible and immediately
  editable/deletable.
- Reuse the same select-existing-line behaviour when ticket 03 rejects a duplicate (point the
  MM at the line that already exists).

Files: `ctld_tools/tui/app.py` (`_apply` / op callbacks, a tree-cursor helper),
`ctld_tools/data/locales/{en,fr}.json` (notify strings). Tests: assert the cursor lands on
the new/existing line after each op.
</content>
