---
description: Manual wake an agent on its bifrost-agent-<name> channel — bypasses normal message routing for emergency dispatch
argument-hint: <agent-name> <message>
allowed-tools:
  - mcp__bifrost__messages_send
---

# /bifrost:wake $ARGUMENTS

Manually wake an agent. Use sparingly — normal flow is `messages_send` with the agent's channel.

## Parsing

Arguments: `<agent-name> <message>`. Agent name is the canonical slug (forge / heimdall / convey / satellite / pm-callboard / etc.), NOT the api_key subject (forge-bifrost).

## Send

```javascript
await mcp__bifrost__messages_send({
  channel: "<agent-name>",
  content: "<message>"
})
```

The `channel: "<agent-name>"` form auto-routes via `/messages` with `delivery_mechanism=bifrost-internal` per the canonical internal-messaging path.

## When to use

- Operator wants to bypass normal channels for an emergency directive
- A frozen agent needs an external nudge (note: stop-hook + auto-refill is the canonical path; manual wake is a fallback)
- Cross-agent dispatch when the natural sender doesn't have credentials

## When NOT to use

- Normal messaging — use `mcp__bifrost__messages_send` directly with the source channel
- "Standing by" / "are you alive" pings — that's the stop-hook's job, not a manual wake
- Cross-realm wakes — agents are realm-scoped; use the realm's PM persona instead

## Hard rules

- **Never wake an agent that's actively shipping code.** Check tmux state first if uncertain.
- **Quote the directive verbatim — no operator-anger filtering needed for wake messages, but DO strip raw quotes if forwarding from operator-channel per the [[feedback_dont_forward_operator_quotes_to_forge]] rule.
