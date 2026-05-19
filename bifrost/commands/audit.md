---
description: Audit open Epics for already-shipped work and surface candidates for audit-driven close
allowed-tools:
  - mcp__bifrost__sql_execute
  - mcp__bifrost__execute
  - Bash
---

# /bifrost:audit

Find open Epics whose work has actually been shipped but the Epic is still in `status='open'`. Surface them as audit-close candidates. **Do not auto-close** — the operator or PM agent makes the close decision.

## Steps

1. **Query candidates:**

```sql
SELECT id, title, priority, stage, status, assignee, inserted_at
FROM epics
WHERE realm = 'bifrost'
  AND status IN ('open', 'approved', 'in_progress')
  AND priority IN (0, 1, 2)
  AND inserted_at < NOW() - INTERVAL '12 hours'
ORDER BY priority, inserted_at DESC
LIMIT 30
```

2. **For each Epic, run a grep audit:**

Extract the hypothesis-keyword from the title (e.g. `AR-MESSAGING-UNIFICATION-FINISH-MIGRATE` → search for "MESSAGING-UNIFICATION", "internal_messages", "drop the table" etc.).

```bash
git -C ~/dev/bifrost_ex log --oneline forge-trunk -50 | grep -i "<keyword>"
git -C ~/dev/bifrost_ex log --grep="<epic-id-short>" -10
```

If grep returns ≥1 matching commit, this is an **audit-close candidate**.

3. **Cross-check related Epics:**

```sql
SELECT id, title, status, closed_at, closed_reason
FROM epics
WHERE description ILIKE '%<keyword>%' OR title ILIKE '%<keyword>%'
ORDER BY closed_at DESC NULLS LAST
LIMIT 10
```

A sibling Epic that closed with overlapping scope is strong evidence for resolved-by-prior-work.

4. **Render the candidate table:**

```
**Audit-close candidates** (N found, M reviewed)

| Epic ID | Title | Evidence | Close action |
|---------|-------|----------|--------------|
| 019e2bc2 | KL-SEMANTIC-IRI-1 slice 2 | commit c63e3335 | close-as-shipped |
| 019e2e77 | UNREAD-SYNC-CROSS-SUBSCRIBER-LEAK | 48cbaa06 + dc616ec3 | close-as-resolved-by-prior-work |
| 019e3a1c | V2-TOOL-LAYER-HARDENING slice 1 | (audit Epic; closed-by-decision) | (already closed) |

Skipped (no evidence): N Epics
```

5. **Surface to operator:**

Use `mcp__bifrost__messages_send` with channel="zach" to brief on the list. Operator decides which to close.

## Hard rules

- **Bifrost realm only.** Never enumerate cross-realm Epics.
- **Never auto-close.** This command surfaces candidates; the close decision is operator-or-PM.
- **Cite specific commit SHAs.** "Looks shipped" without a SHA is hand-waving.
- **Skip Epics needing operator-judgment** (e.g. design questions, language choice, scope-reset) — flag them separately.
- **Skip partial-slice Epics.** If only some slices closed and others are pending, the Epic stays open.
