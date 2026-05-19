#!/usr/bin/env bash
# bifrost-marketplace plugin status-line
#
# Renders: <agent> | active=<epic-title-short> | q=<pending>/<inprog> | wake=<seconds>s
#
# Wire up in ~/.claude/settings.json:
#   {
#     "statusLine": {
#       "command": "~/.claude/plugins/marketplaces/bifrost-marketplace/bifrost/statusline.sh"
#     }
#   }
#
# Environment expected:
#   BIFROST_API_KEY   — agent's api_key (or machine key)
#   BIFROST_URL       — defaults to https://bifrost-api.com
#   BIFROST_AGENT_ID  — short agent name (e.g. heimdall, forge)
#
# Epic 019e3a51 slice 4 — completes Phase 4 of AR-BIFROST-NATIVE-CLAUDE-PLUGIN.

set -u

BIFROST_URL="${BIFROST_URL:-https://bifrost-api.com}"
AGENT="${BIFROST_AGENT_ID:-${USER:-?}}"
TIMEOUT=3

# Suppress curl errors — status-line should never noise the operator's terminal
fail_silent() { return 0; }
trap fail_silent ERR

# Active Epic — query the agent's api_key
active_epic=""
if [ -n "${BIFROST_API_KEY:-}" ]; then
  active_epic=$(curl -s --max-time "$TIMEOUT" \
    -H "Authorization: Bearer ${BIFROST_API_KEY}" \
    "${BIFROST_URL}/agents/${AGENT}/active_epic" 2>/dev/null \
    | grep -oP '"title":"\K[^"]+' \
    | head -1)
fi
# Truncate to ~30 chars to keep status-line tight
if [ -n "$active_epic" ]; then
  active_epic_short=$(echo "$active_epic" | cut -c1-35)
else
  active_epic_short="(none)"
fi

# Queue depth — pending + in_progress
queue_pending=0
queue_in_progress=0
if [ -n "${BIFROST_API_KEY:-}" ]; then
  queue_json=$(curl -s --max-time "$TIMEOUT" \
    -H "Authorization: Bearer ${BIFROST_API_KEY}" \
    "${BIFROST_URL}/agents/${AGENT}/work-queue?status=pending,in_progress" 2>/dev/null)
  queue_pending=$(echo "$queue_json" | grep -oP '"status":"pending"' | wc -l)
  queue_in_progress=$(echo "$queue_json" | grep -oP '"status":"in_progress"' | wc -l)
fi

# Last wake age — seconds since last entry in /tmp/bifrost-stop-hook.log
wake_age="-"
log=/tmp/bifrost-stop-hook.log
if [ -f "$log" ]; then
  last_mtime=$(stat -c %Y "$log" 2>/dev/null)
  now=$(date +%s)
  if [ -n "$last_mtime" ]; then
    wake_age=$((now - last_mtime))s
  fi
fi

# Compose status-line
printf "%s | active=%s | q=%d/%d | wake=%s" \
  "$AGENT" \
  "$active_epic_short" \
  "$queue_pending" \
  "$queue_in_progress" \
  "$wake_age"
