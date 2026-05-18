#!/usr/bin/env bats

setup() {
  LIB="$BATS_TEST_DIRNAME/../presets/karpathy-lite/sentinel/hooks/_lib.sh"
  HELPERS="$BATS_TEST_DIRNAME/../shared/installer-helpers.sh"
  TMPDIR_TEST="$BATS_TEST_DIRNAME/.tmp/$BATS_TEST_NAME"
  mkdir -p "$TMPDIR_TEST"
  export CLAUDE_CORTEX_HOME="$TMPDIR_TEST"
  export CLAUDE_SENTINEL_HOME="$TMPDIR_TEST/sentinel"
  export SENTINEL_OBSERVERS_YAML="$BATS_TEST_DIRNAME/fixtures/sentinel/observers.yaml"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  unset CLAUDE_CORTEX_HOME CLAUDE_SENTINEL_HOME SENTINEL_OBSERVERS_YAML
}

@test "sentinel_lib loads without error" {
  source "$HELPERS"
  source "$LIB"
}

@test "sentinel_observers_subscribed_to lists observers for a hook" {
  source "$HELPERS"; source "$LIB"
  result="$(sentinel_observers_subscribed_to post_tool_use)"
  [ "$result" = "cortex-capture" ]
}

@test "sentinel_observers_subscribed_to returns empty for unsubscribed hook" {
  source "$HELPERS"; source "$LIB"
  result="$(sentinel_observers_subscribed_to session_start)"
  [ -z "$result" ]
}

@test "sentinel_emit_event writes payload + jsonl line + reminder" {
  source "$HELPERS"; source "$LIB"
  output="$(sentinel_emit_event 'sid1' 'eid1' 'cortex-capture' 'post_tool_use' 'Write' '{"tool":"Write"}' '[]')"
  [ -f "$CLAUDE_SENTINEL_HOME/events/sid1/eid1.json" ]
  [ -f "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl" ]
  grep -q '"kind":"event_emitted"' "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
  grep -q '"observer":"cortex-capture"' "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
  printf '%s\n' "$output" | grep -q "Sentinel: dispatch observer 'cortex-capture' in background"
  printf '%s\n' "$output" | grep -q "Event payload:.*sid1/eid1.json"
}

@test "sentinel_should_dispatch dedups identical event after emit" {
  source "$HELPERS"; source "$LIB"
  # First emit: payload+tool combination not in log -> should dispatch.
  sentinel_should_dispatch 'sid1' 'cortex-capture' 'post_tool_use' 'Write' '{"tool":"Write"}'
  sentinel_emit_event 'sid1' 'eid_a' 'cortex-capture' 'post_tool_use' 'Write' '{"tool":"Write"}' '[]' >/dev/null
  # Second check with same inputs -> hash already in log -> should NOT dispatch.
  ! sentinel_should_dispatch 'sid1' 'cortex-capture' 'post_tool_use' 'Write' '{"tool":"Write"}'
  grep -q '"kind":"event_deduped"' "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
}

@test "sentinel_should_dispatch does not dedup different tool args with same payload" {
  source "$HELPERS"; source "$LIB"
  sentinel_emit_event 'sid1' 'eid_a' 'cortex-capture' 'post_tool_use' 'Write' '{"tool":"Write"}' '[]' >/dev/null
  # Different tool name -> different hash -> should dispatch.
  sentinel_should_dispatch 'sid1' 'cortex-capture' 'post_tool_use' 'Read' '{"tool":"Write"}'
}

@test "sentinel_should_dispatch returns 1 (drop) when cap reached" {
  source "$HELPERS"; source "$LIB"
  # Pre-seed JSONL with cap (3) event_emitted lines for cortex-capture
  for i in 1 2 3; do
    cortex_jsonl_append "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl" \
      "{\"kind\":\"event_emitted\",\"observer\":\"cortex-capture\",\"eid\":\"e$i\"}"
  done
  ! sentinel_should_dispatch 'sid1' 'cortex-capture' 'post_tool_use' 'Write' '{"tool":"Write"}'
  grep -q '"kind":"cap_reached"' "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
}
