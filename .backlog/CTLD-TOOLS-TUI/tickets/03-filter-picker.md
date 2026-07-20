# 03 — Filterable picker (filter logic + widget)

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

A **filter-as-you-type picker** for large lists (DCS types ~1143, catalogue crates/troops):

- Pure **filter function**: given a list + a query, return the narrowed list (case-insensitive
  substring; fuzzy optional). Unit-tested independently.
- A textual widget (text input driving a filtered option list) reusing that filter, used by the crate
  `unit` picker, the remove/patch crate picker, and the troop pickers.

## Acceptance criteria

- [ ] Filter function: query → expected narrowed list (case-insensitive substring).
- [ ] Widget filters live as the user types; empty query shows all.
- [ ] Reused by every large-list picker in the TUI (types, crates, troops).
- [ ] Filter function pytest-covered.

## Blocked by

Ticket 01 (catalogue lists come from the reference).
