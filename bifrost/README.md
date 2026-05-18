# bifrost (Claude Code plugin)

Bifrost agent fleet plugin for Claude Code. Bundles MCP server config, canonical hooks, fleet skills, and the wake-stream daemon.

## Install

```
/plugin marketplace add github:True-Endeavoure/bifrost-marketplace
/plugin install bifrost
```

Then set your API key:

```bash
export BIFROST_API_KEY=bf_yourkeyhere
```

Restart Claude Code and you're connected.

## What's included

| Component | Purpose |
|---|---|
| `.mcp.json` | Registers `bifrost-channel` binary as MCP server (stdio) |
| `hooks/hooks.json` | PostToolUse → /hooks/peek, PostCompact → /hooks/compact, Stop → bifrost-channel wake-stream |
| `monitors/monitors.json` | Persistent WS to bifrost-api.com via the daemon — wake events arrive as notifications |
| `bin/bifrost-channel` | Self-contained Go binary (cross-compiled for darwin/arm64, linux/amd64, windows/amd64) |

Skills are queried at runtime via the `skills_search` MCP tool — they live in the Bifrost DB, not in this repo.

## Architecture

```
   Claude Code session
         │
         │  MCP stdio                Plugin runtime
         ▼                            spawns
   bifrost-channel ──────────── WS ─────────────► bifrost-api.com
   (Go binary)                                    (orchestration)
         │
         └─ stdout notifications via monitors/monitors.json
            (wake events → Claude session)
```

The Go binary acts as:
- **MCP server** (stdio): exposes named tools (messages_send, runes_list, etc.) + execute codemode JS
- **WS client**: persistent connection to bifrost-api.com/agent/stream
- **Stop-hook handler**: blocks on WS for new events when Claude finishes a turn
- **Monitor mode**: streams wake events as stdout lines (Claude Code plugin runtime delivers as notifications)

## Status

Pre-release. Slice 1 (binary skeleton) in progress. See Epic `019e3c82-c2f6` (AR-BIFROST-CHANNEL-GO-BINARY).

## Channels (future)

Once Claude Code's "Channels" feature lifts from research preview AND open regressions (#59240, #60061) close, this plugin will migrate from monitors-mode to the native `claude/channel` capability. See Epic `019e3c82-c66c` for the migration watch.

## License

MIT.
