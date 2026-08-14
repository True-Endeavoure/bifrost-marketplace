#!/usr/bin/env bash
# PreToolUse(Bash) — ENFORCE that every run_in_background command self-wakes.
#
# Bundled in the `bifrost` plugin (ported from bifrost-agent-tools). Portable:
# no hardcoded paths, key-gated so plain non-Bifrost clods are never blocked.
#
# Problem this solves: Claude kept launching long background jobs then ending its
# turn, sitting idle at the Stop hook because nothing woke it when the job finished.
# A background process that POSTs a message to the agent channel DOES break through
# the Stop hook (bifrost-channel returns on a new message), so the fix is to make
# EVERY background job self-wake. This hook makes that unavoidable: it blocks a
# run_in_background Bash call unless the command posts a wake to /messages.
#
# Fail-safe: on ANY parse problem it ALLOWS (exit 0) — it must never wedge bash.
# Exit 2 = block the tool call + feed stderr to Claude as the reason.

input="$(cat 2>/dev/null)" || exit 0

# Key-gate: only enforce for real Bifrost agents. A plain keyless clod has no
# wake channel, so background self-wake is meaningless — allow everything.
[ -z "$BIFROST_API_KEY" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

tool="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)" || exit 0
[ "$tool" = "Bash" ] || exit 0

# run_in_background may surface as snake_case or camelCase depending on harness version.
bg="$(printf '%s' "$input" | jq -r '.tool_input.run_in_background // .tool_input.runInBackground // false' 2>/dev/null)" || exit 0
[ "$bg" = "true" ] || exit 0

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || exit 0

# Already self-waking? (posts a wake to /messages directly, or via a bg-wake helper.)
if printf '%s' "$cmd" | grep -qE 'bg-wake\.sh|/messages'; then
  exit 0
fi

cat >&2 <<'EOF'
BLOCKED: a run_in_background job must SELF-WAKE so you are re-invoked when it finishes
(otherwise you sit idle at the Stop hook until a human pings you).

Make the background job post a wake to your own agent channel on completion — e.g. end
the command with a curl POST to ${BIFROST_URL}/messages (Authorization: Bearer
$BIFROST_API_KEY) targeting your own channel. bifrost-channel's Stop-hook wait returns
on that message and re-invokes you automatically.

Or, if it's short, just run it in the FOREGROUND (omit run_in_background) and poll actively.
EOF
exit 2
