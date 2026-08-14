#!/bin/sh
# Stop hook — KEY-GATED wrapper around the bifrost-channel wake client.
#
# Why this wrapper exists: bifrost-channel --stop-hook exits 2 (= BLOCK the stop)
# when BIFROST_API_KEY is unset. At user scope that would wedge a plain, non-Bifrost
# Claude session — its turn could never cleanly end. This wrapper key-gates:
#   no key  → exit 0 (allow the session to stop cleanly; plain clod deactivates)
#   has key → exec bifrost-channel --stop-hook (block + wait for a Bifrost wake)
#
# Binary path is resolved relative to this script ($0) so it works regardless of
# how the plugin root is mounted. Bundled in the `bifrost` plugin.

[ -z "$BIFROST_API_KEY" ] && exit 0

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$DIR/../bin/bifrost-channel" --stop-hook
