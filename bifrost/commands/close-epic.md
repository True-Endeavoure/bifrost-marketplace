---
description: Close an Epic with the canonical 5-evidence-field gate — closed_reason + test_coverage + integration_test + physical_probe + dedup_validation + DoD
argument-hint: <epic-id>
allowed-tools:
  - mcp__bifrost__execute
  - mcp__bifrost__sql_execute
---

# /bifrost:close-epic $ARGUMENTS

Close the Epic with full evidence. **Refuse to close without all 5 evidence fields + a valid testing_vectors line.** This is the canonical close-gate — auto-enforced by BifrostEx.Epics.

## Steps

1. **Fetch the Epic:**

```javascript
await codemode.request({ method: "GET", path: `/epics/<epic-id>` })
```

Read: title, body, current status/stage, existing testing_vectors, related-Epic IDs.

2. **Audit prior-work shipment:**
   - Grep for the Epic's hypothesis-keyword in forge-trunk + bf-go + bifrost-marketplace
   - Check related Epics in description for prior closures or carved-out slices
   - If audit shows already-shipped: this is an audit-finding close (cite specific commits + closed sibling Epics)
   - If NOT already shipped: refuse — ship the work first, don't fake-close

3. **Validate testing_vectors against the integration gate:**

The gate parses lines as `<TYPE> <PROBE>; >= <THRESHOLD>`. Acceptable types:
- `SQL` — `SQL SELECT count(*) FROM <table> WHERE <cond>; >= 1`
- `SQL SELECT 1; >= 1` (canonical tautology — only acceptable for code-shipped probe Epics)
- `bf-go grep` — `bf-go grep: grep -c 'PATTERN' file.go >= N`

If existing testing_vectors don't fit the parser, PUT to update them BEFORE closing.

4. **Construct the close payload** — every field required:

```javascript
await codemode.request({
  method: "PUT",
  path: `/epics/<epic-id>`,
  body: {
    status: "closed",
    stage: "done",
    closed_reason: "<which-slices-shipped + commit-shas + Epic-IDs of sibling closures>",
    test_coverage_evidence: "<which commits, which tests, link to test file>",
    integration_test_evidence: "<live verification + post-deploy probe>",
    physical_probe_evidence: "<observed pre/post-state — log lines, /health diff, etc.>",
    dedup_validation: "<why this isn't a duplicate of sibling Epic X — orthogonal failure modes>",
    definition_of_done: "<from-Epic-body, each DoD item marked [shipped] | [operational-pending] | [verified]>"
  }
})
```

5. **Verify close landed:**

```sql
SELECT status, stage, closed_at, LEFT(closed_reason, 100)
FROM epics WHERE id = '<epic-id>'
```

If `closed_at` is non-null and `status='closed'` — done.

## Hard rules

- **Never close without commit evidence.** If the work isn't actually shipped, this command refuses.
- **Never write `closed_reason: "stale"` or `"obsolete"`.** Either ship the work + close-by-audit, or escalate to operator for premise-drift-refile.
- **Never duplicate-close.** If a sibling Epic already covered this work, cite the sibling + close-as-resolved-by-prior-work.
- **Bifrost realm only.** Do not close Epics from convey / callboard / paper-plane etc. — those are other-realm scope.

## After close

Brief the operator (or messages_send to their channel) with the closure + cumulative session-tally. Operator wants throughput visibility on the audit-close cadence.
