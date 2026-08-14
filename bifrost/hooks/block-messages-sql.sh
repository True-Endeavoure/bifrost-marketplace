#!/usr/bin/env bash
# PreToolUse hook — blocks sql_execute calls touching the messages/message_reads pipeline.
#
# Bundled in the `bifrost` plugin (ported from bifrost-agent-tools). Key-gated (the
# matcher mcp__bifrost__sql_execute already scopes it to Bifrost MCP sessions).
#
# Why: agents MUST use mcp__bifrost__messages_list / messages_send for operator-facing
# message reads + replies. Raw SQL against `messages` / `message_reads` bypasses the
# GenServer ack path, so the operator's UI never sees "agent read this."
#
# Hook contract (Claude Code PreToolUse, JSON-on-stdin):
#   exit 0 → allow; exit >=2 → block, stderr shown to the model

set -euo pipefail

INPUT=$(cat)

# Key-gate: no Bifrost key → no bifrost MCP → nothing to guard.
[ -z "${BIFROST_API_KEY:-}" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
if [ "$TOOL_NAME" != "mcp__bifrost__sql_execute" ]; then
  exit 0
fi

QUERY=$(printf '%s' "$INPUT" | jq -r '.tool_input.query // empty')
if [ -z "$QUERY" ]; then
  exit 0
fi

# Lowercase + strip comments for matching
QUERY_LC=$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]' | sed -E 's|--[^\n]*||g; s|/\*[^*]*\*+([^/*][^*]*\*+)*/||g')

# Strip single-quoted string literals so matches inside literals (e.g. Epic-body docs
# describing SQL examples) don't false-block.
QUERY_STRIPPED=$(printf '%s' "$QUERY_LC" | awk '
  BEGIN { in_squote=0; out="" }
  {
    line = $0
    i = 1
    while (i <= length(line)) {
      c = substr(line, i, 1)
      if (c == "\x27") {
        in_squote = 1 - in_squote
        out = out " "
      } else if (in_squote == 0) {
        out = out c
      } else {
        out = out " "
      }
      i++
    }
    out = out "\n"
  }
  END { print out }
')

# Pattern: messages / message_reads / message_attachments as table references
# preceded by from/join/update/into/delete-from/truncate.
if printf '%s' "$QUERY_STRIPPED" | grep -Eq '\b(from|join|update|into|delete from|truncate)[[:space:]]+(public\.)?(messages|message_reads|message_attachments)\b'; then
  cat >&2 <<'EOF'
BLOCKED: sql_execute targeting messages / message_reads / message_attachments.

These tables are part of the operator-message pipeline. Direct SQL bypasses the
Messages GenServer ack (the operator's UI never sees "agent read this").

Use the canonical tools instead:
  - Read inbound: mcp__bifrost__messages_list(channel)   ← fires the ack/eyeballs
  - Send outbound: mcp__bifrost__messages_send(channel, content)

For diagnostic introspection that doesn't intersect the operator pipeline, query
via /admin/sql on tables OTHER than these three.

Memory: feedback_never_bypass_messages_list_with_sql
EOF
  exit 2
fi

exit 0
