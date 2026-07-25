# 04 — version-gap detection

Status: 📋 todo
Type: tool (Python) + test

Compare a `configUser`'s authored `configVersion` to the current catalogue version and compute the
diff (new / changed / removed defaults) for a caller (lot 3 UI) to present. Pure function, no UI.

- Read both `configVersion`s. If they differ, diff the two catalogues by path: keys added in the new
  default, keys removed, keys whose default value changed. Return structured data.
- No runtime behaviour — this only powers the tool's re-migration popup (ADR 0011 point 5).
- Unit tests: same version → empty diff; added / removed / value-changed keys surfaced correctly.

Files: new `ctld_tools/versiongap.py`, `tests/**`. Depends on: 02.
