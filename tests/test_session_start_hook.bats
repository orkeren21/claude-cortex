#!/usr/bin/env bats

setup() {
  HOOK="$BATS_TEST_DIRNAME/../presets/karpathy-lite/hooks/session-start.sh"
  TMPDIR_TEST="$BATS_TEST_DIRNAME/.tmp/$BATS_TEST_NAME"
  mkdir -p "$TMPDIR_TEST"
  export CLAUDE_CORTEX_HOME="$TMPDIR_TEST"
  FIXTURE="$BATS_TEST_DIRNAME/fixtures/session-start-stdin.json"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  unset CLAUDE_CORTEX_HOME
}

@test "hook is executable" {
  [ -x "$HOOK" ]
}

@test "hook writes session-id marker file" {
  bash "$HOOK" < "$FIXTURE"
  expected="$TMPDIR_TEST/session-env/0193ab51-991c-7d40-8f00-deadbeef1234/session-id.txt"
  [ -f "$expected" ]
  [ "$(cat "$expected")" = "0193ab51-991c-7d40-8f00-deadbeef1234" ]
}

@test "hook is idempotent" {
  bash "$HOOK" < "$FIXTURE"
  bash "$HOOK" < "$FIXTURE"
  expected="$TMPDIR_TEST/session-env/0193ab51-991c-7d40-8f00-deadbeef1234/session-id.txt"
  [ "$(cat "$expected")" = "0193ab51-991c-7d40-8f00-deadbeef1234" ]
}

@test "hook exits 0 on malformed JSON (non-fatal)" {
  echo "not json" | bash "$HOOK"
  [ "$?" -eq 0 ]
}

@test "hook exits 0 when session_id missing (non-fatal)" {
  echo '{"hook_event_name":"SessionStart"}' | bash "$HOOK"
  [ "$?" -eq 0 ]
}

@test "hook rejects path-traversal session_id" {
  echo '{"session_id":"../../../../tmp/cortex_pwned_test"}' | bash "$HOOK"
  # Should exit 0 silently
  [ "$?" -eq 0 ]
  # Must NOT have created any file under /tmp/cortex_pwned_test
  [ ! -e /tmp/cortex_pwned_test ]
  # Must NOT have created anything under TMPDIR_TEST/session-env (no valid id was provided)
  [ ! -d "$TMPDIR_TEST/session-env" ] || [ -z "$(ls -A "$TMPDIR_TEST/session-env" 2>/dev/null)" ]
}

@test "hook rejects session_id with shell metacharacters" {
  echo '{"session_id":"abc;rm -rf /tmp/should-not-happen"}' | bash "$HOOK"
  [ "$?" -eq 0 ]
  # No directory should have been created with that name
  [ ! -d "$TMPDIR_TEST/session-env/abc;rm -rf /tmp/should-not-happen" ]
  # And nothing valid should exist under session-env (the id was rejected)
  [ ! -d "$TMPDIR_TEST/session-env" ] || [ -z "$(ls -A "$TMPDIR_TEST/session-env" 2>/dev/null)" ]
}

@test "hook handles HOME unset (and CLAUDE_CORTEX_HOME unset) without crashing" {
  # Drop both; the hook should still exit 0 gracefully.
  # We can't easily verify the marker file location without polluting the system,
  # so just verify the exit code.
  ( unset HOME
    unset CLAUDE_CORTEX_HOME
    echo '{"session_id":"abc-123"}' | bash "$HOOK"
    exit_code=$?
    [ "$exit_code" -eq 0 ]
  )
}
