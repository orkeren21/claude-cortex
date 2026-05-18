#!/usr/bin/env bash
# presets/karpathy-lite/sentinel/hooks/session-start.sh
# Sentinel SessionStart hook. Reads JSON from stdin, emits an event
# per subscribed observer. Always exits 0; hook failure must never
# break the session.

set -u

HOOK_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
HELPERS="${SENTINEL_HELPERS:-$HOOK_DIR/../../../../shared/installer-helpers.sh}"
LIB="$HOOK_DIR/_lib.sh"

[ -f "$HELPERS" ] || exit 0
[ -f "$LIB" ] || exit 0

# shellcheck source=/dev/null
source "$HELPERS"
# shellcheck source=/dev/null
source "$LIB"

stdin="$(cat)"
[ -z "$stdin" ] && exit 0

# Extract session_id.
session_id="$(printf '%s' "$stdin" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$session_id" ] && exit 0
printf '%s' "$session_id" | grep -qE '^[A-Za-z0-9_-]+$' || exit 0

tool_name="-"

# Best-effort transcript window read (last 20 turns).
transcript="$(sentinel_read_transcript_window "$session_id" 20)"

observers="$(sentinel_observers_subscribed_to session_start)"
[ -z "$observers" ] && exit 0

for obs in $observers; do
  if sentinel_should_dispatch "$session_id" "$obs" session_start "$tool_name" "$stdin"; then
    eid="$(printf '%s%s' "$(date +%s%N)" "$$")"
    sentinel_emit_event "$session_id" "$eid" "$obs" session_start "$tool_name" "$stdin" "$transcript"
  fi
done

exit 0
