#!/usr/bin/env bash
# Fake subagent: reads event payload path from arg, writes a deterministic
# file recording what it saw, and appends dispatch_completed JSONL.

set -u

payload_file="$1"
[ -f "$payload_file" ] || exit 1

event_id="$(sed -n 's/.*"event_id":"\([^"]*\)".*/\1/p' "$payload_file" | head -1)"
session_id="$(sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p' "$payload_file" | head -1)"
hook="$(sed -n 's/.*"hook":"\([^"]*\)".*/\1/p' "$payload_file" | head -1)"

mock_out="$CLAUDE_SENTINEL_HOME/mock-out/$event_id.txt"
mkdir -p "$(dirname "$mock_out")"
printf 'sid=%s hook=%s eid=%s\n' "$session_id" "$hook" "$event_id" > "$mock_out"

log="$CLAUDE_SENTINEL_HOME/log/$session_id.jsonl"
printf '{"kind":"dispatch_completed","observer":"cortex-capture","eid":"%s","outcome":"captured","files":["mock"],"ts":"%s"}\n' \
  "$event_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
