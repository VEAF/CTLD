# Domain documentation configuration

Skills that need the project's domain language or past decisions (`grill-with-docs`,
`improve-codebase-architecture`, `diagnosing-bugs`, `tdd`) read a single context:

- **`CONTEXT.md`** (repo root) — the ubiquitous language / glossary of the CTLD domain.
- **`dev/adr/`** — Architecture Decision Records for structural decisions.

When a decision crystallises during a session, record it in a new ADR and, if it introduces or
redefines a domain term, update `CONTEXT.md` in the same move.
