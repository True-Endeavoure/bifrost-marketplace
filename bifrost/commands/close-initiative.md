---
description: Close a Bifrost Initiative by aggregating child Epic closures into the canonical 5-evidence-field gate
argument-hint: <initiative-id>
allowed-tools:
  - mcp__bifrost__execute
  - mcp__bifrost__sql_execute
---

# /bifrost:close-initiative $ARGUMENTS

Close an Initiative whose child Epics are all terminal. Mirrors the `/bifrost:close-epic` flow but aggregates evidence from the closed children instead of requiring per-Initiative work.

## Prerequisites

The Initiative must have:
- All child Epics in `status='closed'` AND `stage='done'`
- ≥1 child Epic (don't close an empty Initiative)
- Real shipment evidence in the closed children's `closed_reason` fields

If any child is still open / approved / draft / in_progress → **refuse to close**. The Klu signal `initiative-auto-close-blocked` is the canonical trigger.

## Steps

1. **Fetch Initiative + children:**

```javascript
const init = await codemode.request({ method: "GET", path: `/initiatives/<initiative-id>` })
```

```sql
SELECT id, title, status, stage, closed_at, LEFT(closed_reason, 200) AS reason
FROM epics
WHERE initiative_id = '<initiative-id>'
ORDER BY closed_at DESC NULLS LAST
```

2. **Validate all-terminal:**

For each child row: status must be `closed` AND stage must be `done`. If any row fails → list them + refuse.

3. **Aggregate evidence from children's closed_reason:**

Concatenate child-closures into a roll-up:
```
"Initiative complete. Closed children: <child-id>: <child-closed-reason-1-line>; <child-id>: <child-closed-reason-1-line>; ..."
```

4. **PUT close:**

```javascript
await codemode.request({
  method: "PUT",
  path: `/initiatives/<initiative-id>`,
  body: {
    status: "closed",
    closed_reason: "<aggregated child summary + Initiative-level outcome statement>",
    test_coverage_evidence: "<aggregated child test_coverage_evidence>",
    integration_test_evidence: "<aggregated child integration_test_evidence>",
    physical_probe_evidence: "<aggregated child physical_probe_evidence>",
    dedup_validation: "<why this Initiative isn't a duplicate of sibling Initiative X — orthogonal scope>",
    definition_of_done: "<Initiative-level DoD: all N children shipped, each DoD met per its own evidence>"
  }
})
```

5. **Verify:**

```sql
SELECT status, closed_at FROM initiatives WHERE id = '<initiative-id>'
```

If `closed_at` is non-null + status=closed → done.

## Hard rules

- **Never close an Initiative with non-terminal children.** Refuse + list the open ones.
- **Never fake-aggregate evidence.** If a child's evidence is null, surface that as a defect; don't paper over.
- **Bifrost realm only.** Other-realm Initiatives have their own PM scope.
- **Initiative close ≠ retirement.** Closed Initiatives stay queryable + auditable; their children's commits + Epic IDs are the long-term record.

## When operator flags a "premature-close" pattern

The audit-reopen-filer sub-agent re-opens fake closures. If audit-reopen finds an Initiative whose children's commits don't exist → re-open the Initiative + its children. This command does NOT prevent fake-closure; it codifies the legit pattern. Pair with audit-reopen-filer as backstop.
