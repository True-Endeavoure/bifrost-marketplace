#!/usr/bin/env bash
# PreToolUse(Bash) hook — blocks Bash docker lifecycle commands that bypass Coolify
# on Coolify-managed containers (the bifrost-ex prod container et al).
#
# Bundled in the `bifrost` plugin (ported from bifrost-agent-tools). Key-gated:
# a plain non-Bifrost Claude has no Coolify-managed prod to protect, so it allows
# all docker commands (exit 0 when no BIFROST_API_KEY).
#
# Why: 2026-05-27, heimdall took the entire Bifrost down by `docker stop` +
# `docker rm` on the Coolify-managed bifrost-ex container when a deploy didn't
# fire, expecting Coolify to auto-recreate it (it did NOT). Container lifecycle on
# Coolify-managed apps goes through the coolify_* MCP tools or the Coolify API,
# never raw docker.
#
# Hook contract (Claude Code PreToolUse, JSON-on-stdin):
#   exit 0 → allow; exit >=2 → block, stderr shown to the model
#
# ALLOWED: docker buildx, docker exec, docker ps|logs|inspect|images, docker pull|push,
# docker run|create. BLOCKED: docker stop|rm|kill|restart + compose down, when the
# command references a Coolify-managed target (bifrost-ex UUID / bifrost / coolify / -core).

set -euo pipefail

INPUT=$(cat)

# Key-gate: plain non-Bifrost Claude has no Coolify to protect — allow all docker.
[ -z "${BIFROST_API_KEY:-}" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
if [ -z "$CMD" ]; then
  exit 0
fi

CMD_LC=$(printf '%s' "$CMD" | tr '[:upper:]' '[:lower:]')

# Only consider commands that invoke docker at all.
if ! printf '%s' "$CMD_LC" | grep -Eq '\bdocker\b'; then
  exit 0
fi

# Destructive lifecycle verbs on an EXISTING container (run|create are safe: they
# create a new container and cannot stop/rm/kill a Coolify-managed one).
DANGER_VERB='\bdocker[[:space:]]+(stop|rm|kill|restart)\b|\bdocker[- ]compose[[:space:]].*\bdown\b'

# Match against a SKELETON with quoted argument text removed, so a docker-lifecycle
# phrase inside a quoted string (e.g. a git commit message) is not mistaken for a
# real docker invocation. Collapse newlines first (sed is line-oriented).
CMD_SKELETON=$(printf '%s' "$CMD_LC" | tr '\n' ' ' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

if ! printf '%s' "$CMD_SKELETON" | grep -Eq "$DANGER_VERB"; then
  exit 0
fi

# Coolify-managed target fingerprints. yexzkmxn4t12kreruh7o8uky = bifrost-ex app UUID.
if printf '%s' "$CMD_LC" | grep -Eq 'yexzkmxn4t12kreruh7o8uky|bifrost|coolify|-core'; then
  cat >&2 <<'EOF'
BLOCKED: docker lifecycle command on a Coolify-managed container.

This is the exact action that took the Bifrost down on 2026-05-27 (docker stop +
docker rm on the bifrost-ex container, expecting Coolify to auto-recreate — it did
NOT). Coolify owns container lifecycle. NEVER bypass it with raw docker.

Use instead:
  - Restart / start / stop / deploy: mcp__bifrost__coolify_apps (action=restart|start|stop|deploy)
  - Low-level Coolify REST: mcp__bifrost__coolify_request
  - To roll a new image: PATCH docker_registry_image_tag + POST /deploy via Coolify API

If a deploy isn't firing, the fix is to make the deploy work (check the build queue +
release pipeline + Coolify logs) — NOT to manage the container by hand.

Still allowed: docker buildx, docker exec, docker ps|logs|inspect|images, docker pull|push.

Memory: feedback_never_bypass_coolify_for_container_lifecycle
EOF
  exit 2
fi

exit 0
