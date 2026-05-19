---
description: Summarize Bifrost fleet state — health, recent deploys, queue depth, open P0/P1 epics
allowed-tools:
  - mcp__bifrost__execute
  - mcp__bifrost__sql_execute
---

# /bifrost:status

You are summarizing the Bifrost fleet state for the operator. Be concise — 6-10 lines max. Focus on what's actionable, not what's nominal.

## What to fetch

Call these in parallel:

1. **Health:** `GET /health` via `mcp__bifrost__execute` — return version, status, repo capacity, circuit-breaker state.

2. **Deploy state:** `SELECT id, version, status, env, created_at FROM releases WHERE realm = (current_realm or 'bifrost') ORDER BY created_at DESC LIMIT 1` via `mcp__bifrost__sql_execute`. Note the gap (if any) between latest release and current /health version.

3. **Queue depth:** `SELECT agent_id, COUNT(*) FILTER (WHERE status='pending') AS pending, COUNT(*) FILTER (WHERE status='in_progress') AS in_progress FROM queue_active GROUP BY agent_id ORDER BY pending DESC` via `mcp__bifrost__sql_execute`.

4. **Open P0/P1 backlog:** `SELECT priority, COUNT(*) FROM epics WHERE status IN ('open','in_progress','approved','draft') AND priority IN (0,1) AND realm = (current_realm or 'bifrost') GROUP BY priority` via `mcp__bifrost__sql_execute`.

5. **Recent commits on forge-trunk:** if relevant for the operator's current question, fetch `SELECT title, conclusion, branch, commit_sha, started_at FROM ci_builds WHERE realm='bifrost' AND started_at > NOW() - INTERVAL '24 hours' ORDER BY started_at DESC LIMIT 5` — but only mention if anomalous.

## Output shape

```
**Fleet status** (as of <timestamp>)

🟢 /health: v<version> | repos: <pool_count> ok | circuit breakers: <count> closed/<count> open

📦 Queue: forge=<pending>/<in_progress> | heimdall=<pending>/<in_progress> | satellite=<...>

📋 Open backlog: P0=<n>, P1=<n>

⚠️ <only-include-if-anomalous: deploys-behind, circuit-breaker-open, queue-stuck-24hr+, etc.>
```

Skip empty/nominal sections. Skip the ⚠️ line if everything's green. The operator wants signal, not noise.

## Hard rules

- **Bifrost realm only.** If the operator's current realm is not bifrost (rare), narrow the queries to that realm. Never enumerate cross-realm stats unless asked.
- **No prose unless prompted.** This is a status snapshot, not a narrative.
- **Cite verbatim from the data.** Don't summarize-from-memory.
