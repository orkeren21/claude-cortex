#!/usr/bin/env bats

setup() {
  HOOK_DIR="$BATS_TEST_DIRNAME/../presets/karpathy-lite/sentinel/hooks"
  TMPDIR_TEST="$BATS_TEST_DIRNAME/.tmp/$BATS_TEST_NAME"
  mkdir -p "$TMPDIR_TEST"
  export CLAUDE_CORTEX_HOME="$TMPDIR_TEST"
  export CLAUDE_SENTINEL_HOME="$TMPDIR_TEST/sentinel"
  export SENTINEL_OBSERVERS_YAML="$BATS_TEST_DIRNAME/fixtures/sentinel/observers.yaml"
  FIX="$BATS_TEST_DIRNAME/fixtures/sentinel"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  unset CLAUDE_CORTEX_HOME CLAUDE_SENTINEL_HOME SENTINEL_OBSERVERS_YAML
}

@test "all five hook scripts are executable" {
  for h in session-start user-prompt-submit post-tool-use stop session-end; do
    [ -x "$HOOK_DIR/$h.sh" ]
  done
}

@test "post-tool-use hook emits event_emitted line + reminder for cortex-capture" {
  output="$(cat "$FIX/post-tool-use-stdin.json" | "$HOOK_DIR/post-tool-use.sh")"
  log="$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
  [ -f "$log" ]
  grep -q '"kind":"event_emitted"' "$log"
  grep -q '"observer":"cortex-capture"' "$log"
  grep -q '"hook":"post_tool_use"' "$log"
  printf '%s\n' "$output" | grep -q "Sentinel: dispatch observer 'cortex-capture'"
}

@test "user-prompt-submit hook emits event for cortex-capture" {
  output="$(cat "$FIX/user-prompt-submit-stdin.json" | "$HOOK_DIR/user-prompt-submit.sh")"
  grep -q '"hook":"user_prompt_submit"' "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
}

@test "stop hook emits event for cortex-capture" {
  output="$(cat "$FIX/stop-stdin.json" | "$HOOK_DIR/stop.sh")"
  grep -q '"hook":"stop"' "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
}

@test "session-start hook does not emit (cortex-capture not subscribed)" {
  output="$(cat "$FIX/session-start-stdin.json" | "$HOOK_DIR/session-start.sh")"
  log="$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
  [ ! -f "$log" ] || ! grep -q '"kind":"event_emitted"' "$log"
}

@test "session-end hook does not emit (cortex-capture not subscribed)" {
  output="$(cat "$FIX/session-end-stdin.json" | "$HOOK_DIR/session-end.sh")"
  log="$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
  [ ! -f "$log" ] || ! grep -q '"kind":"event_emitted"' "$log"
}

@test "post-tool-use hook is a no-op on malformed stdin" {
  echo "not json" | "$HOOK_DIR/post-tool-use.sh"
  [ "$?" -eq 0 ]
}

@test "post-tool-use hook dedups identical payload within window" {
  cat "$FIX/post-tool-use-stdin.json" | "$HOOK_DIR/post-tool-use.sh" >/dev/null
  cat "$FIX/post-tool-use-stdin.json" | "$HOOK_DIR/post-tool-use.sh" >/dev/null
  log="$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
  emitted="$(grep -c '"kind":"event_emitted"' "$log")"
  deduped="$(grep -c '"kind":"event_deduped"' "$log")"
  [ "$emitted" -eq 1 ]
  [ "$deduped" -eq 1 ]
}

@test "post-tool-use hook stops dispatching once cap reached" {
  for i in 1 2 3 4; do
    payload="$(printf '{"session_id":"sid1","tool_name":"Write","tool_input":{"file_path":"/tmp/x%s"},"hook_event_name":"PostToolUse"}' "$i")"
    printf '%s' "$payload" | "$HOOK_DIR/post-tool-use.sh" >/dev/null
  done
  log="$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
  emitted="$(grep -c '"kind":"event_emitted"' "$log")"
  cap_reached="$(grep -c '"kind":"cap_reached"' "$log")"
  [ "$emitted" -eq 3 ]
  [ "$cap_reached" -eq 1 ]
}
