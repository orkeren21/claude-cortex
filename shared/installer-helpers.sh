#!/usr/bin/env bash
# shared/installer-helpers.sh
# Bash helpers for the Claude Cortex installer, hooks, and tests.
# Source this file: `source path/to/installer-helpers.sh`
#
# Note: this file deliberately does not enable `set -u`. Sourcing must not
# alter the option state of the caller. Functions rely on `local` scoping
# and quoting for robustness.

CORTEX_BLOCK_BEGIN='<!-- claude-cortex:begin v1 -->'
CORTEX_BLOCK_END='<!-- claude-cortex:end -->'

# cortex_yaml_get FILE KEY
# Reads a top-level scalar key from a YAML file. Returns empty if missing.
# Returns empty (and exits 0) if FILE does not exist.
cortex_yaml_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  awk -v k="$key" '
    index($0, k":") == 1 {
      line = substr($0, length(k) + 2)
      sub("^[[:space:]]+", "", line)
      sub("[[:space:]]+$", "", line)
      print line
      exit
    }
  ' "$file"
}

# cortex_yaml_set FILE KEY VALUE
# Sets a top-level scalar key. Adds it if missing.
# Ensures FILE ends in a newline before appending so the new line is clean.
cortex_yaml_set() {
  local file="$1" key="$2" value="$3"
  local last_byte
  if [ -s "$file" ]; then
    last_byte="$(tail -c 1 "$file")"
    if [ -n "$last_byte" ]; then
      printf '\n' >> "$file"
    fi
  fi
  if awk -v k="$key" 'index($0, k":") == 1 { found=1; exit } END { exit !found }' "$file" 2>/dev/null; then
    awk -v k="$key" -v v="$value" '
      index($0, k":") == 1 { print k": "v; next }
      { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    printf '%s: %s\n' "$key" "$value" >> "$file"
  fi
}

# cortex_claude_md_has_block FILE
# Returns 0 if the cortex block delimiters are present, 1 otherwise.
cortex_claude_md_has_block() {
  local file="$1"
  [ -f "$file" ] && grep -qF "$CORTEX_BLOCK_BEGIN" "$file"
}

# cortex_claude_md_remove_block FILE
# Removes the delimited block (and one trailing blank line, if present)
# from FILE.
cortex_claude_md_remove_block() {
  local file="$1"
  awk -v b="$CORTEX_BLOCK_BEGIN" -v e="$CORTEX_BLOCK_END" '
    BEGIN { in_block = 0 }
    !in_block && index($0, b) { in_block = 1; next }
    in_block && index($0, e) {
      in_block = 0
      if ((getline next_line) > 0 && next_line != "") print next_line
      next
    }
    !in_block { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# cortex_claude_md_append_block CLAUDE_MD BLOCK_FILE
# Appends BLOCK_FILE wrapped in delimiters to CLAUDE_MD.
# If CLAUDE_MD is non-empty: ensures it ends in a newline; adds a single
# blank-line separator only when the existing last line is non-blank.
cortex_claude_md_append_block() {
  local target="$1" block_file="$2"
  local last_byte last_line block_last_byte
  if [ -s "$target" ]; then
    last_byte="$(tail -c 1 "$target")"
    if [ -n "$last_byte" ]; then
      printf '\n' >> "$target"
    fi
    last_line="$(tail -n 1 "$target")"
    if [ -n "$last_line" ]; then
      printf '\n' >> "$target"
    fi
  fi
  printf '%s\n' "$CORTEX_BLOCK_BEGIN" >> "$target"
  cat "$block_file" >> "$target"
  if [ -s "$block_file" ]; then
    block_last_byte="$(tail -c 1 "$block_file")"
    if [ -n "$block_last_byte" ]; then
      printf '\n' >> "$target"
    fi
  fi
  printf '%s\n' "$CORTEX_BLOCK_END" >> "$target"
}

# cortex_render_template TEMPLATE_FILE KEY=VAL [KEY=VAL ...]
# Substitutes {{KEY}} placeholders. Prints to stdout.
cortex_render_template() {
  local tmpl="$1"
  shift
  local content
  content="$(cat "$tmpl")"
  local kv key val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    content="${content//\{\{${key}\}\}/$val}"
  done
  printf '%s' "$content"
}

# cortex_log MSG ...
# Prints to stderr with a [cortex] prefix.
cortex_log() {
  printf '[cortex] %s\n' "$*" >&2
}

# cortex_jsonl_append FILE JSON_LINE
# Appends a single JSON line to FILE. Creates parent dir + file if missing.
# Always ends with a newline. Atomic per-line on POSIX append semantics.
cortex_jsonl_append() {
  local file="$1" line="$2"
  local dir
  dir="$(dirname "$file")"
  [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null
  printf '%s\n' "$line" >> "$file"
}

# cortex_jsonl_count FILE KIND OBSERVER
# Counts lines whose JSON contains both "kind":"<KIND>" and
# "observer":"<OBSERVER>". Substring match; sufficient for fixed-shape
# events the framework writes.
cortex_jsonl_count() {
  local file="$1" kind="$2" observer="$3"
  [ -f "$file" ] || { printf '0'; return 0; }
  local n
  n="$(grep -c "\"kind\":\"$kind\".*\"observer\":\"$observer\"" "$file" 2>/dev/null)"
  printf '%s' "${n:-0}"
}

# cortex_event_hash KIND TOOL_NAME PAYLOAD_TEXT
# Returns a short stable hex hash for dedup. Uses shasum (built into macOS).
# Inputs are joined with '|' for cheapness; collisions across "a|b","c"
# vs "a","b|c" are possible but harmless at our hash width (64 bits)
# and per-session cap.
cortex_event_hash() {
  printf '%s|%s|%s' "$1" "$2" "$3" | shasum -a 256 | cut -c1-16
}
