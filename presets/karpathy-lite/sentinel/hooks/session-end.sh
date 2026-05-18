#!/usr/bin/env bash
# presets/karpathy-lite/sentinel/hooks/session-end.sh
# Sentinel SessionEnd hook. Reads JSON from stdin, emits an event
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

sentinel_check_dispatch_mode || exit 0

stdin="$(cat)"
[ -z "$stdin" ] && exit 0

# Extract session_id.
# Extract first occurrence of "key":"value". sed with .* is greedy and picks the LAST
# occurrence -- awk's match() with offsets gives us first-occurrence semantics.
sentinel_extract_first_string() {
  local key="$1" json="$2"
  printf '%s' "$json" | awk -v key="$key" '
    {
      pat = "\"" key "\"[[:space:]]*:[[:space:]]*\""
      if (match($0, pat)) {
        rest = substr($0, RSTART + RLENGTH)
        end = index(rest, "\"")
        if (end > 0) print substr(rest, 1, end - 1)
        exit
      }
    }
  '
}

session_id="$(sentinel_extract_first_string session_id "$stdin")"
[ -z "$session_id" ] && exit 0
printf '%s' "$session_id" | grep -qE '^[A-Za-z0-9_-]+$' || exit 0

tool_name="-"

# Best-effort transcript window read (last 20 turns).
transcript="$(sentinel_read_transcript_window "$session_id" 20)"

observers="$(sentinel_observers_subscribed_to session_end)"
[ -z "$observers" ] && exit 0

for obs in $observers; do
  if sentinel_should_dispatch "$session_id" "$obs" session_end "$tool_name" "$stdin"; then
    eid="$(printf '%s%s' "$(date +%s%N)" "$$")"
    sentinel_emit_event "$session_id" "$eid" "$obs" session_end "$tool_name" "$stdin" "$transcript"
  fi
done

exit 0
