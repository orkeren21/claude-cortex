#!/usr/bin/env bats

setup() {
  HOOK_DIR="$BATS_TEST_DIRNAME/../presets/karpathy-lite/sentinel/hooks"
  TMPDIR_TEST="$BATS_TEST_DIRNAME/.tmp/$BATS_TEST_NAME"
  mkdir -p "$TMPDIR_TEST"
  export CLAUDE_CORTEX_HOME="$TMPDIR_TEST"
  export CLAUDE_SENTINEL_HOME="$TMPDIR_TEST/sentinel"
  export SENTINEL_OBSERVERS_YAML="$BATS_TEST_DIRNAME/fixtures/sentinel/observers.yaml"
  MOCK="$BATS_TEST_DIRNAME/fixtures/sentinel/mock-observer.sh"
  FIX="$BATS_TEST_DIRNAME/fixtures/sentinel"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  unset CLAUDE_CORTEX_HOME CLAUDE_SENTINEL_HOME SENTINEL_OBSERVERS_YAML
}

@test "event payload contains all contract fields" {
  cat "$FIX/post-tool-use-stdin.json" | "$HOOK_DIR/post-tool-use.sh" >/dev/null
  payload="$(ls "$CLAUDE_SENTINEL_HOME/events/sid1/"*.json | head -1)"
  grep -q '"event_id":' "$payload"
  grep -q '"session_id":' "$payload"
  grep -q '"hook":' "$payload"
  grep -q '"observer":' "$payload"
  grep -q '"payload":' "$payload"
  grep -q '"transcript_window":' "$payload"
  grep -q '"hash":' "$payload"
  grep -q '"ts":' "$payload"
}

@test "mock observer can be dispatched against an emitted event" {
  cat "$FIX/post-tool-use-stdin.json" | "$HOOK_DIR/post-tool-use.sh" >/dev/null
  payload="$(ls "$CLAUDE_SENTINEL_HOME/events/sid1/"*.json | head -1)"
  "$MOCK" "$payload"
  eid="$(basename "$payload" .json)"
  [ -f "$CLAUDE_SENTINEL_HOME/mock-out/$eid.txt" ]
  grep -q "hook=post_tool_use" "$CLAUDE_SENTINEL_HOME/mock-out/$eid.txt"
  grep -q '"kind":"dispatch_completed"' "$CLAUDE_SENTINEL_HOME/log/sid1.jsonl"
}

@test "system-reminder string is well-formed for Agent tool dispatch" {
  output="$(cat "$FIX/post-tool-use-stdin.json" | "$HOOK_DIR/post-tool-use.sh")"
  printf '%s\n' "$output" | grep -q "^Sentinel: dispatch observer"
  printf '%s\n' "$output" | grep -q "Event payload: .*\\.json$"
  printf '%s\n' "$output" | grep -q "System prompt: .*system-prompt.md"
  printf '%s\n' "$output" | grep -q "Tool allowlist"
}

@test "transcript_window is a valid JSON array (empty when no transcript)" {
  cat "$FIX/post-tool-use-stdin.json" | "$HOOK_DIR/post-tool-use.sh" >/dev/null
  payload="$(ls "$CLAUDE_SENTINEL_HOME/events/sid1/"*.json | head -1)"
  grep -qE '"transcript_window":\[' "$payload"
}
