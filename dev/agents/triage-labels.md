# Triage labels configuration

Triage skills map their 5 roles onto a single `Status:` vocabulary used in `.backlog/` files.

| Status | Emoji | Triage role |
|--------|-------|-------------|
| ready | ⬜ | ready-for-agent |
| in-progress | 🔄 | (lifecycle only) |
| waiting-human | 🧑 | ready-for-human, needs-info |
| done | ✅ | (lifecycle only) |
| wontfix | 🚫 | wontfix |

The `Status:` line sits at the top of each PRD / ticket file and is the source of truth for its
lifecycle state. `.backlog/README.md` mirrors the per-lot status in its index table.
