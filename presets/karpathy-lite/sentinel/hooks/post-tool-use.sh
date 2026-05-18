#!/usr/bin/env bash
# presets/karpathy-lite/sentinel/hooks/post-tool-use.sh
# Sentinel PostToolUse hook. Reads JSON from stdin, emits an event
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

# Extract session_id and tool_name from stdin. tool_input is not parsed; raw stdin flows through as the payload.
# Extract first occurrence of "key":"value". sed with .* is greedy and picks the LAST
# occurrence -- a tool_input field literally containing "tool_name":"..." would shadow
# the real tool name. awk's match() with offsets gives us first-occurrence semantics.
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

tool_name="$(sentinel_extract_first_string tool_name "$stdin")"
tool_name="${tool_name:-unknown}"

# Best-effort transcript window read (last 20 turns).
transcript="$(sentinel_read_transcript_window "$session_id" 20)"

observers="$(sentinel_observers_subscribed_to post_tool_use)"
[ -z "$observers" ] && exit 0

for obs in $observers; do
  if sentinel_should_dispatch "$session_id" "$obs" post_tool_use "$tool_name" "$stdin"; then
    eid="$(printf '%s%s' "$(date +%s%N)" "$$")"
    sentinel_emit_event "$session_id" "$eid" "$obs" post_tool_use "$tool_name" "$stdin" "$transcript"
  fi
done

exit 0
