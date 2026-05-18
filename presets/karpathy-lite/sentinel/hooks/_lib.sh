#!/usr/bin/env bash
# presets/karpathy-lite/sentinel/hooks/_lib.sh
# Sentinel hook library. Sourced by every hook script.
# Owns: dedup check, cap check, event JSON write, JSONL log line,
# system-reminder emission for Path A dispatch.
#
# All functions MUST be safe for `set -u` and MUST NOT exit on internal
# errors -- a hook crash must never break the user's session. Callers
# are expected to swallow non-zero exits.

set -u

# sentinel_valid_observer_id ID
# Returns 0 if ID matches [A-Za-z0-9_-]+, non-zero otherwise.
# Observer IDs that fail this check are unsafe to interpolate into
# the dedup grep regex. The framework rejects such IDs at lookup time
# rather than escape them.
sentinel_valid_observer_id() {
  printf '%s' "$1" | grep -qE '^[A-Za-z0-9_-]+$'
}

: "${CLAUDE_CORTEX_HOME:=$HOME/.claude}"
: "${CLAUDE_SENTINEL_HOME:=$CLAUDE_CORTEX_HOME/sentinel}"
: "${SENTINEL_OBSERVERS_YAML:=$CLAUDE_SENTINEL_HOME/observers.yaml}"
: "${SENTINEL_CONFIG_YAML:=$CLAUDE_SENTINEL_HOME/config.yaml}"

# sentinel_observers_subscribed_to HOOK_NAME
# Prints space-separated observer IDs whose 'subscribe:' list contains HOOK_NAME.
# Reads SENTINEL_OBSERVERS_YAML. Tolerant of missing file (prints nothing).
sentinel_observers_subscribed_to() {
  local hook="$1"
  [ -f "$SENTINEL_OBSERVERS_YAML" ] || return 0
  awk -v hook="$hook" '
    /^[[:space:]]*-[[:space:]]+id:/ {
      sub(/^[^:]*:[[:space:]]*/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      cur = $0
    }
    /^[[:space:]]+subscribe:/ {
      line = $0
      sub(/^[^:]*:[[:space:]]*/, "", line)
      gsub(/[\[\]]/, "", line)
      n = split(line, parts, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
        if (parts[i] == hook) {
          print cur
          break
        }
      }
    }
  ' "$SENTINEL_OBSERVERS_YAML" | while IFS= read -r id; do
    if sentinel_valid_observer_id "$id"; then
      printf '%s\n' "$id"
    fi
  done
}

# sentinel_observer_yaml_field OBSERVER FIELD
# Reads a per-observer scalar field from SENTINEL_OBSERVERS_YAML.
# Returns empty if observer or field missing.
sentinel_observer_yaml_field() {
  local observer="$1" field="$2"
  [ -f "$SENTINEL_OBSERVERS_YAML" ] || return 0
  awk -v obs="$observer" -v field="$field" '
    /^[[:space:]]*-[[:space:]]+id:/ {
      line = $0
      sub(/^[^:]*:[[:space:]]*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      cur = (line == obs) ? 1 : 0
    }
    cur && $0 ~ ("^[[:space:]]+" field ":") {
      out = $0
      sub(/^[^:]*:[[:space:]]*/, "", out)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", out)
      print out
      exit
    }
  ' "$SENTINEL_OBSERVERS_YAML"
}

# sentinel_should_dispatch SID OBSERVER HOOK TOOL_NAME PAYLOAD_TEXT
# Returns 0 if a dispatch should proceed, 1 otherwise.
# Writes cap_reached / event_deduped JSONL lines as side effect.
sentinel_should_dispatch() {
  local sid="$1" observer="$2" hook="$3" tool="$4" payload="$5"
  local log="$CLAUDE_SENTINEL_HOME/log/$sid.jsonl"
  local cap
  cap="$(sentinel_observer_yaml_field "$observer" per_session_cap)"
  [ -z "$cap" ] && cap=30

  local count
  count="$(cortex_jsonl_count "$log" event_emitted "$observer")"
  if [ "$count" -ge "$cap" ]; then
    cortex_jsonl_append "$log" \
      "{\"kind\":\"cap_reached\",\"observer\":\"$observer\",\"hook\":\"$hook\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    return 1
  fi

  # Cap is checked before dedup so a duplicate event still increments
  # cap_reached when cap is full. Dedup is best-effort; cap is structural.
  local hash
  hash="$(cortex_event_hash "$hook" "$tool" "$payload")"
  if [ -f "$log" ] && grep -q "\"observer\":\"$observer\".*\"hash\":\"$hash\"\|\"hash\":\"$hash\".*\"observer\":\"$observer\"" "$log" 2>/dev/null; then
    cortex_jsonl_append "$log" \
      "{\"kind\":\"event_deduped\",\"observer\":\"$observer\",\"hook\":\"$hook\",\"hash\":\"$hash\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    return 1
  fi

  return 0
}

# sentinel_emit_event SID EID OBSERVER HOOK TOOL_NAME PAYLOAD_JSON TRANSCRIPT_JSON
# Writes the event payload file, appends event_emitted JSONL line,
# prints the system-reminder text to stdout (caller injects it).
sentinel_emit_event() {
  local sid="$1" eid="$2" observer="$3" hook="$4" tool="$5" payload="$6" transcript="$7"
  local events_dir="$CLAUDE_SENTINEL_HOME/events/$sid"
  local log="$CLAUDE_SENTINEL_HOME/log/$sid.jsonl"
  mkdir -p "$events_dir" 2>/dev/null
  local payload_file="$events_dir/$eid.json"

  local hash
  hash="$(cortex_event_hash "$hook" "$tool" "$payload")"

  printf '{"event_id":"%s","session_id":"%s","hook":"%s","observer":"%s","payload":%s,"transcript_window":%s,"hash":"%s","ts":"%s"}' \
    "$eid" "$sid" "$hook" "$observer" "$payload" "$transcript" "$hash" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$payload_file"

  cortex_jsonl_append "$log" \
    "{\"kind\":\"event_emitted\",\"observer\":\"$observer\",\"hook\":\"$hook\",\"eid\":\"$eid\",\"hash\":\"$hash\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"

  local system_prompt
  system_prompt="$(sentinel_observer_yaml_field "$observer" system_prompt_path)"
  cat <<REMINDER
Sentinel: dispatch observer '$observer' in background.
Event payload: $payload_file
System prompt: $system_prompt
Tool allowlist (per observers.yaml): Read, Write, Edit, Bash
  (Bash restricted to vault-path globs; rm/rmdir/unlink denied)
REMINDER
}

# sentinel_read_transcript_window SID K
# Best-effort read of last K turns from Claude Code transcript file.
# Path is heuristic (~/.claude/projects/<project>/<session-id>.jsonl).
# Trusts session-id uniqueness across projects (uses head -1 on find).
# Assumes each transcript line is a single-line JSON value (true for
# Claude Code's JSONL format). Returns "[]" if path missing/unreadable.
sentinel_read_transcript_window() {
  local sid="$1" k="$2"
  local transcript_path
  transcript_path="$(find "$HOME/.claude/projects" -name "$sid.jsonl" 2>/dev/null | head -1)"
  if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    printf '[]'
    return 0
  fi
  printf '['
  tail -n "$k" "$transcript_path" 2>/dev/null | awk 'NR>1{printf ","} {printf "%s", $0}'
  printf ']'
}
