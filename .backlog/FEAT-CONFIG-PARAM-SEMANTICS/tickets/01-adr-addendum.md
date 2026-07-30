# 01 — ADR 0011 addendum: the two config tiers

**Status:** done

> Delivered as `Addendum 1` in ADR 0011, cross-linked from the Status line and from point 1.
> The acceptance check on neighbouring ADRs found a real gap: **0008 and 0009 both still read
> "Accepted"** despite 0011 declaring them superseded. Both Status lines now say so — 0008 entirely,
> 0009 for points 2 & 3 only.

## Why

ADR 0011 says "a missing element means intentional removal" without distinguishing parameters from
lists. For a parameter that sentence has no meaning — the engine needs a value — and three call sites
crash to prove it. The document must say what the code will now do, or the next reader re-derives it.

## What changes

- Append an addendum section to
  [`dev/adr/0011-complete-yaml-config-and-webapp-tooling.md`](../../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md)
  (do not rewrite the original decision — add, date it 2026-07-30, and cross-reference from point 1).
- State the two tiers:
  - **Parameter** (default value is a scalar): must be present; if absent, the engine resolves it
    from `configDefault` and reports it. Never a removal.
  - **List** (default value is a list or map): omitting it, or omitting an element, is an intentional
    removal. Unchanged from the original decision.
- State why the rejected "runtime deep-merge" alternative is not being reopened: its stated objection
  — that merging makes element removal need explicit remove-ops — is about lists, and lists keep the
  original semantic.
- Note the classifier: the tier is derived from the shape of the default value, not declared.

## Acceptance

- The addendum names both tiers and the classifier rule.
- ADR 0011 point 1 links forward to the addendum, so a reader starting at the top cannot miss it.
- No other ADR contradicts it (check 0008 / 0009 are already marked superseded by 0011).
