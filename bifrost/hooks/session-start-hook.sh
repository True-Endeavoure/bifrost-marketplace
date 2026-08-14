#!/bin/bash
# SessionStart hook — CONTEXT LOADER (Epic 019ff269).
# On session start, injects the agent's SKILLS INDEX + recent MEMORY so the
# agent boots WITH the relevant context in hand instead of flailing blind.
# Output = hookSpecificOutput.additionalContext.
#
# Fail-open by construction: ANY error / missing data / no key → emit nothing,
# exit 0. This hook must NEVER block or slow session start. Keyless (plain
# non-Bifrost clod) → exits 0 immediately, injects nothing.
#
# Bundled in the `bifrost` plugin (ported from bifrost-agent-tools). Portable:
# uses only env + curl + jq; resolves agent id from $BIFROST_AGENT_ID.

HOOK_INPUT=$(cat 2>/dev/null)
AGENT="${BIFROST_AGENT_ID:-$(tmux display-message -p '#S' 2>/dev/null || echo unknown)}"
REALM="${BIFROST_REALM:-bifrost}"
BIFROST_URL="${BIFROST_URL:-https://bifrost-api.com}"
LOG=/tmp/bifrost-session-start-hook.log
log() { echo "[session-start-hook] $(date) $*" >> "$LOG" 2>/dev/null; }

# No key → can't fetch context; proceed silently (never block).
[ -z "$BIFROST_API_KEY" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

source_kind=$(echo "$HOOK_INPUT" | jq -r '.source // "startup"' 2>/dev/null || echo startup)
log "start agent=$AGENT realm=$REALM source=$source_kind"

# 1) recent memory — AM-2 pre-inject formatted block (already display-ready).
MEM=$(curl -s --max-time 5 -H "Authorization: Bearer $BIFROST_API_KEY" \
  "${BIFROST_URL}/memory/recall-for-context?agent_id=${AGENT}&limit=8" 2>/dev/null \
  | jq -r '.formatted_block // empty' 2>/dev/null)

# 2) skills index (name — one-line description) for the agent's realm, so the
#    agent knows what skills EXIST to search. Full content via skills_show on demand.
SKILLS=$(curl -s --max-time 5 -H "Authorization: Bearer $BIFROST_API_KEY" \
  "${BIFROST_URL}/skills?realm=${REALM}&limit=45" 2>/dev/null \
  | jq -r '(.skills // .matches // .) | if type=="array" then .[] else empty end
           | "- " + (.name // "?") + ": " + ((.description // "") | gsub("\n";" ") | .[0:110])' 2>/dev/null \
  | head -45)

CTX="## SKILLS-FIRST (your operating system): before acting on a task, call skills_search for it and skills_show the match — skills are authoritative and current. Available skills in your realm (search these; do NOT operate from memory/assumption):"
[ -n "$SKILLS" ] && CTX="${CTX}
${SKILLS}"
[ -n "$MEM" ] && CTX="${CTX}

${MEM}"

# Nothing useful fetched → stay silent, never inject an empty block.
if [ -z "$SKILLS" ] && [ -z "$MEM" ]; then log "no context fetched; exit 0 quiet"; exit 0; fi

jq -cn --arg ctx "$CTX" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}' 2>/dev/null
log "injected: skills_len=${#SKILLS} mem_len=${#MEM}"
exit 0
