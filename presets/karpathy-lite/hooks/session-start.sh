#!/usr/bin/env bash
# presets/karpathy-lite/hooks/session-start.sh
# Claude Cortex SessionStart hook.
# Reads JSON from stdin, extracts session_id, writes marker file.
# Always exits 0 — a hook failure must never break the session.

set -u

CORTEX_HOME="${CLAUDE_CORTEX_HOME:-${HOME:-/tmp}/.claude}"

stdin="$(cat)"

# Tolerate both stdin variants; we only need session_id.
session_id="$(printf '%s' "$stdin" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"

if [ -z "${session_id:-}" ]; then
  exit 0
fi

# Validate: only allow letters, digits, hyphens, underscores. Reject anything that
# could traverse paths or contain shell metacharacters.
if ! printf '%s' "$session_id" | grep -qE '^[A-Za-z0-9_-]+$'; then
  exit 0
fi

session_dir="$CORTEX_HOME/session-env/$session_id"
mkdir -p "$session_dir" 2>/dev/null || exit 0
printf '%s' "$session_id" > "$session_dir/session-id.txt" 2>/dev/null || exit 0

exit 0
