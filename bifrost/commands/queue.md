---
description: Show current agent's pending + in-progress work-queue items, sorted by priority
allowed-tools:
  - mcp__bifrost__sql_execute
---

# /bifrost:queue

Query the current agent's work-queue and render a compact table.

## Steps

1. Determine `BIFROST_AGENT_ID` from the shell environment. If unset, ask the operator which agent to query.

2. Run:

```sql
SELECT priority, position, status, kind,
       LEFT(content, 100) AS preview,
       (metadata->>'priority') AS p_label,
       updated_at
FROM queue_active
WHERE agent_id = '<agent_id>'
  AND status IN ('pending', 'in_progress')
ORDER BY priority, position
LIMIT 20
```

3. Render:

```
**Queue for <agent_id>** — N pending, M in_progress

| Pri | Pos | Status | Preview |
|-----|-----|--------|---------|
| P0  | 1   | pending     | AR-MESSAGING-UNIFICATION-FINISH-MIGRATE... |
| P0  | 2   | pending     | AR-UNREAD-SYNC-CROSS-SUBSCRIBER-LEAK... |
| P1  | 6   | in_progress | AR-KNOWLEDGE-LAYER-SKILLS-MATCH-500... |
```

If the queue is empty, say: "Queue empty — agent should self-refill or pull from backlog."

## Hard rules

- Bifrost realm only (the queue_active table is realm-scoped).
- Never list other agents' queues unless operator explicitly asks for fleet-wide view.
- Cite verbatim — do not paraphrase queue item content.
