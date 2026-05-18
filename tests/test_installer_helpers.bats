#!/usr/bin/env bats

setup() {
  HELPERS="$BATS_TEST_DIRNAME/../shared/installer-helpers.sh"
  TMPDIR_TEST="$BATS_TEST_DIRNAME/.tmp/$BATS_TEST_NAME"
  mkdir -p "$TMPDIR_TEST"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "cortex_helpers loads without error" {
  source "$HELPERS"
}

@test "cortex_yaml_get reads a top-level scalar" {
  source "$HELPERS"
  cat > "$TMPDIR_TEST/c.yaml" <<EOF
preset: karpathy-lite
version: 0.1.0
EOF
  result="$(cortex_yaml_get "$TMPDIR_TEST/c.yaml" preset)"
  [ "$result" = "karpathy-lite" ]
}

@test "cortex_yaml_set writes a top-level scalar" {
  source "$HELPERS"
  cat > "$TMPDIR_TEST/c.yaml" <<EOF
preset: karpathy-lite
version: 0.1.0
EOF
  cortex_yaml_set "$TMPDIR_TEST/c.yaml" version 0.2.0
  result="$(cortex_yaml_get "$TMPDIR_TEST/c.yaml" version)"
  [ "$result" = "0.2.0" ]
}

@test "cortex_claude_md_has_block returns false on empty file" {
  source "$HELPERS"
  : > "$TMPDIR_TEST/CLAUDE.md"
  ! cortex_claude_md_has_block "$TMPDIR_TEST/CLAUDE.md"
}

@test "cortex_claude_md_has_block returns true when delimiters present" {
  source "$HELPERS"
  cat > "$TMPDIR_TEST/CLAUDE.md" <<'EOF'
# My rules

<!-- claude-cortex:begin v1 -->
content
<!-- claude-cortex:end -->
EOF
  cortex_claude_md_has_block "$TMPDIR_TEST/CLAUDE.md"
}

@test "cortex_claude_md_remove_block leaves other content untouched" {
  source "$HELPERS"
  cat > "$TMPDIR_TEST/CLAUDE.md" <<'EOF'
# My rules

This is mine.

<!-- claude-cortex:begin v1 -->
generated
<!-- claude-cortex:end -->

More mine.
EOF
  cortex_claude_md_remove_block "$TMPDIR_TEST/CLAUDE.md"
  ! cortex_claude_md_has_block "$TMPDIR_TEST/CLAUDE.md"
  grep -q "This is mine" "$TMPDIR_TEST/CLAUDE.md"
  grep -q "More mine" "$TMPDIR_TEST/CLAUDE.md"
}

@test "cortex_claude_md_append_block adds delimited block to empty file" {
  source "$HELPERS"
  : > "$TMPDIR_TEST/CLAUDE.md"
  echo "the rules" > "$TMPDIR_TEST/block.md"
  cortex_claude_md_append_block "$TMPDIR_TEST/CLAUDE.md" "$TMPDIR_TEST/block.md"
  cortex_claude_md_has_block "$TMPDIR_TEST/CLAUDE.md"
  grep -q "the rules" "$TMPDIR_TEST/CLAUDE.md"
}

@test "cortex_render_template substitutes {{vars}}" {
  source "$HELPERS"
  cat > "$TMPDIR_TEST/tmpl" <<'EOF'
vault_path={{VAULT_PATH}}
preset={{PRESET}}
EOF
  cortex_render_template "$TMPDIR_TEST/tmpl" \
    VAULT_PATH=/Users/x/vault \
    PRESET=karpathy-lite \
    > "$TMPDIR_TEST/out"
  grep -q "vault_path=/Users/x/vault" "$TMPDIR_TEST/out"
  grep -q "preset=karpathy-lite" "$TMPDIR_TEST/out"
}

@test "cortex_yaml_get on missing file returns empty without error" {
  source "$HELPERS"
  result="$(cortex_yaml_get /nonexistent/path/file.yaml somekey)"
  [ -z "$result" ]
}

@test "cortex_yaml_get distinguishes keys with regex metachars" {
  source "$HELPERS"
  cat > "$TMPDIR_TEST/c.yaml" <<EOF
vault.path: /a
vaultxpath: /b
EOF
  a="$(cortex_yaml_get "$TMPDIR_TEST/c.yaml" "vault.path")"
  [ "$a" = "/a" ]
}

@test "cortex_yaml_get distinguishes keys that are strict prefixes" {
  source "$HELPERS"
  cat > "$TMPDIR_TEST/c.yaml" <<EOF
pre: short
pretty: long
EOF
  s="$(cortex_yaml_get "$TMPDIR_TEST/c.yaml" pre)"
  l="$(cortex_yaml_get "$TMPDIR_TEST/c.yaml" pretty)"
  [ "$s" = "short" ]
  [ "$l" = "long" ]
}

@test "cortex_yaml_set on file without trailing newline produces clean output" {
  source "$HELPERS"
  printf 'preset: karpathy-lite' > "$TMPDIR_TEST/c.yaml"
  cortex_yaml_set "$TMPDIR_TEST/c.yaml" version 0.1.0
  expected=$'preset: karpathy-lite\nversion: 0.1.0\n'
  actual="$(cat "$TMPDIR_TEST/c.yaml")"
  # bash command substitution strips trailing newline, compare without it
  expected_trimmed=$'preset: karpathy-lite\nversion: 0.1.0'
  [ "$actual" = "$expected_trimmed" ]
}

@test "sourcing installer-helpers does not enable set -u in caller" {
  # Run in a sub-bash that starts with set +u, source helpers, check option state.
  out=$(bash -c "set +u; source '$HELPERS'; set -o | grep '^nounset'")
  echo "$out" | grep -q 'off'
}

@test "cortex_claude_md round-trip: empty CLAUDE.md" {
  source "$HELPERS"
  : > "$TMPDIR_TEST/CLAUDE.md"
  echo "the rules" > "$TMPDIR_TEST/block.md"
  expected="$(cat "$TMPDIR_TEST/CLAUDE.md")"
  cortex_claude_md_append_block "$TMPDIR_TEST/CLAUDE.md" "$TMPDIR_TEST/block.md"
  cortex_claude_md_remove_block "$TMPDIR_TEST/CLAUDE.md"
  actual="$(cat "$TMPDIR_TEST/CLAUDE.md")"
  [ "$expected" = "$actual" ]
}

@test "cortex_claude_md round-trip: trailing newline + content" {
  source "$HELPERS"
  printf '%s\n' "# My rules" "" "Some content here." > "$TMPDIR_TEST/CLAUDE.md"
  echo "the rules" > "$TMPDIR_TEST/block.md"
  expected="$(cat "$TMPDIR_TEST/CLAUDE.md")"
  cortex_claude_md_append_block "$TMPDIR_TEST/CLAUDE.md" "$TMPDIR_TEST/block.md"
  cortex_claude_md_remove_block "$TMPDIR_TEST/CLAUDE.md"
  actual="$(cat "$TMPDIR_TEST/CLAUDE.md")"
  [ "$expected" = "$actual" ]
}

@test "cortex_claude_md round-trip: trailing blank line" {
  source "$HELPERS"
  printf '%s\n' "# My rules" "" "Some content." "" > "$TMPDIR_TEST/CLAUDE.md"
  echo "the rules" > "$TMPDIR_TEST/block.md"
  expected="$(cat "$TMPDIR_TEST/CLAUDE.md")"
  cortex_claude_md_append_block "$TMPDIR_TEST/CLAUDE.md" "$TMPDIR_TEST/block.md"
  cortex_claude_md_remove_block "$TMPDIR_TEST/CLAUDE.md"
  actual="$(cat "$TMPDIR_TEST/CLAUDE.md")"
  [ "$expected" = "$actual" ]
}

@test "cortex_claude_md round-trip: file without trailing newline" {
  source "$HELPERS"
  printf '# My rules\nSome content.' > "$TMPDIR_TEST/CLAUDE.md"
  echo "the rules" > "$TMPDIR_TEST/block.md"
  # Note: append normalizes trailing newline. Round-trip equality must
  # account for this. We check that remove leaves the file functionally
  # equivalent — semantically the same prose, and consistent newline state
  # after the round trip. The post-round-trip file is allowed to have a
  # normalized trailing newline.
  cortex_claude_md_append_block "$TMPDIR_TEST/CLAUDE.md" "$TMPDIR_TEST/block.md"
  cortex_claude_md_remove_block "$TMPDIR_TEST/CLAUDE.md"
  result="$(cat "$TMPDIR_TEST/CLAUDE.md")"
  [ "$result" = "$(printf '# My rules\nSome content.')" ]
}

@test "cortex_claude_md_remove_block removes trailing block at EOF without leaving end delimiter" {
  source "$HELPERS"
  printf '%s\n' "# Prelude" "" "<!-- claude-cortex:begin v1 -->" "block content" "<!-- claude-cortex:end -->" > "$TMPDIR_TEST/CLAUDE.md"
  cortex_claude_md_remove_block "$TMPDIR_TEST/CLAUDE.md"
  # Result must NOT contain either delimiter.
  ! grep -q 'claude-cortex' "$TMPDIR_TEST/CLAUDE.md"
  # Result must contain the prelude.
  grep -q '# Prelude' "$TMPDIR_TEST/CLAUDE.md"
}

@test "cortex_jsonl_append writes one line of valid JSON" {
  source "$HELPERS"
  local f="$TMPDIR_TEST/log.jsonl"
  cortex_jsonl_append "$f" '{"kind":"event_emitted","eid":"e1"}'
  cortex_jsonl_append "$f" '{"kind":"dispatch_completed","eid":"e1"}'
  [ "$(wc -l < "$f")" -eq 2 ]
  grep -q '"event_emitted"' "$f"
  grep -q '"dispatch_completed"' "$f"
}

@test "cortex_jsonl_count counts lines matching a kind" {
  source "$HELPERS"
  local f="$TMPDIR_TEST/log.jsonl"
  cortex_jsonl_append "$f" '{"kind":"event_emitted","eid":"e1","observer":"cortex-capture"}'
  cortex_jsonl_append "$f" '{"kind":"event_emitted","eid":"e2","observer":"cortex-capture"}'
  cortex_jsonl_append "$f" '{"kind":"event_emitted","eid":"e3","observer":"other"}'
  result="$(cortex_jsonl_count "$f" event_emitted cortex-capture)"
  [ "$result" -eq 2 ]
}

@test "cortex_jsonl_count returns 0 on missing file" {
  source "$HELPERS"
  result="$(cortex_jsonl_count "$TMPDIR_TEST/missing.jsonl" event_emitted cortex-capture)"
  [ "$result" -eq 0 ]
}

@test "cortex_event_hash is deterministic for same input" {
  source "$HELPERS"
  h1="$(cortex_event_hash 'post_tool_use' 'Write' 'foo bar')"
  h2="$(cortex_event_hash 'post_tool_use' 'Write' 'foo bar')"
  [ "$h1" = "$h2" ]
  [ -n "$h1" ]
}

@test "cortex_event_hash differs for different input" {
  source "$HELPERS"
  h1="$(cortex_event_hash 'post_tool_use' 'Write' 'foo')"
  h2="$(cortex_event_hash 'post_tool_use' 'Write' 'bar')"
  [ "$h1" != "$h2" ]
}
