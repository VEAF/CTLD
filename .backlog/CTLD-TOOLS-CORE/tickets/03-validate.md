# 03 — validate: schema + datamine + mixedSet

Status: 📋 todo
Type: tool (Python) + test

Validate a complete catalogue against the schema, the datamine type set, and AA `mixedSet`
consistency. Clear, structured report (a caller — lot 3 UI — presents it).

- Reuse/extend `validate.py`, driven by the ticket-02 core model.
- **mixedSet consistency**: each `mixedSet` weight resolves to an existing crate in its section
  (the invariant the runtime injection loop used to guarantee — now static data, so validated here).
- Schema-coverage stays a **blocking** test: every schema-declared key is reachable/validated.
- Unit tests: valid catalogue passes; broken mixedSet / unknown datamine type / schema violation
  each fail with a clear message.

Files: `ctld_tools/validate.py`, `tests/**`. Depends on: 02.
