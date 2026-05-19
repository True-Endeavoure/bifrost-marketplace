---
description: Show recent wake events for the current (or named) agent — last 20 wakes from bf-go ring buffer
argument-hint: [agent-name]
allowed-tools:
  - Bash
---

# /bifrost:wake-health $ARGUMENTS

Query bf-go's per-agent recent_wakes ring buffer + render a compact table. Useful for diagnosing:

- Stale-wake noise (peek-cache events firing without real messages)
- Wake fan-out leaks (one event waking multiple agents)
- Quiet-agent debugging (is anything actually waking the agent?)

## Parsing

If `$ARGUMENTS` is empty: target `${BIFROST_AGENT_ID:-$USER}` (current agent).
Otherwise: target the named agent.

## Steps

1. Determine target agent.

2. Curl bf-go's local HTTP endpoint:

```bash
BFGO_URL="http://127.0.0.1:${BIFROST_BFGO_PORT:-3200}"
curl -s --max-time 3 "$BFGO_URL/agents/<agent>/recent_wakes"
```

Returns JSON: `{"agent": "<name>", "wakes": [{"reason": "...", "message": "...", "ts": "..."}, ...]}`.

3. Render compact table:

```
**Recent wakes for <agent>** — last 20 events

| Age | Reason | Message |
|-----|--------|---------|
| 12s | new_message | New message on telegram-... |
| 1m  | work_queue_item | POST-DEPLOY-VERIFY... |
| 3m  | new_message | New message on bifrost-agent-heimdall |
| ... |
```

Age is computed from ts → now-ts difference (short form: 12s / 1m / 3m / 1h).

If the ring is empty (`wakes: []`): say "No wake events recorded since last bf-go restart." Suggest checking systemd start time via `systemctl --user status bf-go`.

## Hard rules

- **Only works on the local agent's host** — bf-go HTTP endpoint is 127.0.0.1:3201 by default. Cross-host wake-health needs the LiveView surface (Epic 019e3ddf-d2c1, BifrostEx side, not yet shipped).
- **Bifrost realm only** — bf-go runs per-realm; this command's scope is the local agent.
- **Ring is in-memory** — survives between agent claude-session restarts but NOT between bf-go.service restarts. For persistent wake history, query the metrics table after Vector ingest (Epic 019e3ddf-13f7).

## Source

bf-go commit 6919333 — added recentWakes ring buffer + GET /agents/<name>/recent_wakes endpoint. Capped at 20 events per agent.
