# Claude Cortex v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the v1 Claude Cortex distribution repo: a paste-and-run installer that lays down a karpathy-lite Obsidian vault skeleton, a global CLAUDE.md block, six slash commands, one consolidated skill, and a session-id capture hook — all on macOS.

**Architecture:** A public GitHub repo (`orkeren21/claude-cortex`) ships templates and an `install.md` that Claude reads and executes. The installer copies a karpathy-lite preset bundle (skeleton + skills + commands + CLAUDE.md template) into the user's `~/.claude/` and `<vault_path>/`. Runtime contract lives in `~/.claude/CLAUDE.md` between delimiters; vault config lives in `<vault>/.claude-cortex/config.yaml`. Slash commands and capture flows are markdown files Claude Code already understands — the heavy lifting is in well-structured prompts, not new code.

**Tech Stack:**
- Markdown (skill files, slash commands, install.md)
- YAML (frontmatter, config.yaml, sessions.yaml)
- Bash (installer-internal scripts; SessionStart hook)
- Bats (bash test framework, for hook + verifier scripts)
- `jq` / `yq` (config parsing in scripts)
- `gh` CLI (release tagging at the end)

**Scope:**
- v1 ships **karpathy-lite preset only.** PARA preset is a follow-on plan.
- v1 ships **install.md only.** `update.md` and `uninstall.md` are follow-on plans (uninstall.md is included as a stub to avoid users worrying about being trapped).
- v1 ships **macOS only.** Linux/Windows out of scope per spec.
- v1 ships **one consolidated skill file** (`claude-cortex.md`). Splitting into per-procedure skill files is a follow-on optimization.

**Spec reference:** `docs/specs/2026-05-12-second-brain-design.md` (commit `5e56b4d` and later)

**Repo location:** `/Users/okeren/Projects/personal/claude-cortex/` (origin: `git@github.com:orkeren21/claude-cortex.git`)

---

## File Structure

The plan produces these files. Paths are relative to repo root unless prefixed with `~/` or `<vault>/`.

### Top-level

| Path | Responsibility |
|---|---|
| `README.md` | Landing page with paste-this-into-Claude prompt, feature summary, install/uninstall TLDRs |
| `LICENSE` | MIT (already exists) |
| `.gitignore` | macOS/editor/log/env hygiene (already exists) |
| `.github/CODEOWNERS` | Already exists |
| `install.md` | The full installer Claude reads & executes |
| `uninstall.md` | Stub: removes CLAUDE.md block + skills/commands; leaves vault data untouched |

### `presets/karpathy-lite/`

| Path | Responsibility |
|---|---|
| `presets/karpathy-lite/preset.yaml` | name, version, description, default settings |
| `presets/karpathy-lite/CLAUDE.md.tmpl` | Global rules block with `{{...}}` placeholders |
| `presets/karpathy-lite/skeleton/_index.md` | Top-level vault map |
| `presets/karpathy-lite/skeleton/inbox/_index.md` | Inbox staging-folder list, ages |
| `presets/karpathy-lite/skeleton/retros/_index.md` | Retro index |
| `presets/karpathy-lite/skeleton/insights/_index.md` | Insights index |
| `presets/karpathy-lite/skeleton/insights/debugging/_index.md` | Debugging insights |
| `presets/karpathy-lite/skeleton/insights/architecture/_index.md` | Architecture insights |
| `presets/karpathy-lite/skeleton/insights/tooling/_index.md` | Tooling insights |
| `presets/karpathy-lite/skeleton/projects/_index.md` | Projects index |
| `presets/karpathy-lite/skeleton/people/_index.md` | People index |
| `presets/karpathy-lite/skeleton/references/_index.md` | References index |
| `presets/karpathy-lite/skills/claude-cortex.md` | Consolidated skill: full frontmatter schema, retro algorithm, heuristics, etc. |
| `presets/karpathy-lite/commands/save-insight.md` | Slash command: single-note durable capture |
| `presets/karpathy-lite/commands/save-to-inbox.md` | Slash command: zero-friction staging |
| `presets/karpathy-lite/commands/retro.md` | Slash command: synthesis + dispatch |
| `presets/karpathy-lite/commands/resume-work.md` | Slash command: post-vacation resume brief |
| `presets/karpathy-lite/commands/triage-inbox.md` | Slash command: stale-staging cleanup |
| `presets/karpathy-lite/commands/refresh-index.md` | Slash command: regenerate `_index.md` |
| `presets/karpathy-lite/hooks/session-start.sh` | SessionStart hook: writes session-id marker |

### `shared/`

| Path | Responsibility |
|---|---|
| `shared/version.txt` | One-line semver: `0.1.0` |
| `shared/installer-helpers.sh` | Bash helpers sourced by hooks/scripts (path resolution, yaml read/write) |

### `docs/`

| Path | Responsibility |
|---|---|
| `docs/specs/2026-05-12-second-brain-design.md` | Already committed |
| `docs/plans/2026-05-12-claude-cortex-v1.md` | THIS DOC |
| `docs/troubleshooting.md` | Common install issues, recovery steps |

### Tests

| Path | Responsibility |
|---|---|
| `tests/test_session_start_hook.bats` | bats tests for the SessionStart hook |
| `tests/test_installer_helpers.bats` | bats tests for `installer-helpers.sh` functions |
| `tests/fixtures/` | Sample CLAUDE.md, sample sessions.yaml, etc. |

### What lands on the user's machine after `install.md` runs

| Path | From |
|---|---|
| `~/.claude/CLAUDE.md` (block appended) | `presets/karpathy-lite/CLAUDE.md.tmpl` rendered |
| `~/.claude/skills/claude-cortex/claude-cortex.md` | `presets/karpathy-lite/skills/claude-cortex.md` |
| `~/.claude/commands/{save-insight,save-to-inbox,retro,resume-work,triage-inbox,refresh-index}.md` | `presets/karpathy-lite/commands/*.md` |
| `~/.claude/hooks/claude-cortex-session-start.sh` | `presets/karpathy-lite/hooks/session-start.sh` |
| `~/.claude/settings.json` (`hooks.SessionStart` entry added) | edited in place by installer |
| `<vault>/_index.md` and folder skeleton | `presets/karpathy-lite/skeleton/` |
| `<vault>/.claude-cortex/config.yaml` | written by installer with chosen settings |

---

## Task Order Rationale

Tasks are ordered so each one produces something testable and the dependencies flow forward:

1. **Tasks 1-2** — version + installer-helpers (everything else needs them)
2. **Tasks 3-4** — SessionStart hook (slash commands need the session id)
3. **Tasks 5-6** — preset metadata + CLAUDE.md template (the contract)
4. **Tasks 7-8** — skeleton + the consolidated skill (the runtime knowledge)
5. **Tasks 9-14** — six slash commands (one task each; user-visible surface)
6. **Task 15** — `install.md` (orchestrates everything above)
7. **Task 16** — `uninstall.md` stub (safety net)
8. **Tasks 17-18** — README + troubleshooting (the entry points)
9. **Task 19** — end-to-end smoke test against a throwaway vault
10. **Task 20** — tag and ship v0.1.0

---

## Task 1: Add `shared/version.txt` and bootstrap test framework

**Why first:** Every later task references the version. Tests bootstrap here too so subsequent tasks can write tests immediately.

**Files:**
- Create: `shared/version.txt`
- Create: `tests/README.md`
- Modify: `.gitignore`
- Test: bats install verification

- [ ] **Step 1: Verify bats is installed**

Run: `which bats || brew install bats-core`
Expected: bats path printed, or Homebrew installs `bats-core`.

- [ ] **Step 2: Create `shared/version.txt`**

```
0.1.0
```

- [ ] **Step 3: Append test artifacts to `.gitignore`**

Edit `.gitignore`, append:

```
# Test artifacts
tests/.tmp/
tests/.bats-output/
```

- [ ] **Step 4: Create `tests/README.md`**

```markdown
# Tests

Bats-based tests for installer helpers and hook scripts.

## Run all tests

```bash
bats tests/*.bats
```

## Run a single test

```bash
bats tests/test_installer_helpers.bats
```

## Fixtures

`tests/fixtures/` holds sample files (CLAUDE.md snippets, sessions.yaml, etc.) used by tests.
```

- [ ] **Step 5: Verify bats can run an empty test**

Create temp file `tests/test_smoke.bats`:

```bash
#!/usr/bin/env bats

@test "bats is wired up" {
  result=1
  [ "$result" -eq 1 ]
}
```

Run: `bats tests/test_smoke.bats`
Expected: `1 test, 0 failures`. Then `rm tests/test_smoke.bats`.

- [ ] **Step 6: Commit**

```bash
git add shared/version.txt tests/README.md .gitignore
git commit -m "feat: add version marker and bats test scaffolding"
```

---

## Task 2: Implement `shared/installer-helpers.sh`

**Why:** Reusable bash helpers for path resolution, YAML read/write, CLAUDE.md block management. The installer, hook, and tests all source this.

**Files:**
- Create: `shared/installer-helpers.sh`
- Test: `tests/test_installer_helpers.bats`
- Test fixtures: `tests/fixtures/sample-claude.md`, `tests/fixtures/sample-config.yaml`

- [ ] **Step 1: Write failing tests**

Create `tests/test_installer_helpers.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test_installer_helpers.bats`
Expected: All tests fail with "command not found" / "no such file".

- [ ] **Step 3: Implement `shared/installer-helpers.sh`**

```bash
#!/usr/bin/env bash
# shared/installer-helpers.sh
# Bash helpers for the Claude Cortex installer, hooks, and tests.
# Source this file: `source path/to/installer-helpers.sh`

set -u

CORTEX_BLOCK_BEGIN='<!-- claude-cortex:begin v1 -->'
CORTEX_BLOCK_END='<!-- claude-cortex:end -->'

# cortex_yaml_get FILE KEY
# Reads a top-level scalar key from a YAML file. Returns empty if missing.
cortex_yaml_get() {
  local file="$1" key="$2"
  awk -v k="$key" '
    $0 ~ "^"k":" {
      sub("^"k":[[:space:]]*", "")
      sub("[[:space:]]*$", "")
      print
      exit
    }
  ' "$file"
}

# cortex_yaml_set FILE KEY VALUE
# Sets a top-level scalar key. Adds it if missing.
cortex_yaml_set() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}:" "$file" 2>/dev/null; then
    awk -v k="$key" -v v="$value" '
      $0 ~ "^"k":" { print k": "v; next }
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
# Removes the delimited block (and one trailing blank line) from FILE.
cortex_claude_md_remove_block() {
  local file="$1"
  awk -v b="$CORTEX_BLOCK_BEGIN" -v e="$CORTEX_BLOCK_END" '
    BEGIN { in_block = 0 }
    !in_block && index($0, b) { in_block = 1; next }
    in_block && index($0, e) { in_block = 0; getline; if ($0 != "") print; next }
    !in_block { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# cortex_claude_md_append_block CLAUDE_MD BLOCK_FILE
# Appends BLOCK_FILE wrapped in delimiters to CLAUDE_MD.
# Adds a leading blank line if CLAUDE_MD is non-empty and doesn't end in one.
cortex_claude_md_append_block() {
  local target="$1" block_file="$2"
  if [ -s "$target" ]; then
    local last
    last="$(tail -c 1 "$target" | xxd -p)"
    if [ "$last" != "0a" ]; then printf '\n' >> "$target"; fi
    printf '\n' >> "$target"
  fi
  printf '%s\n' "$CORTEX_BLOCK_BEGIN" >> "$target"
  cat "$block_file" >> "$target"
  # Ensure the block file ended with a newline before our end-delimiter.
  if [ -s "$block_file" ]; then
    local block_last
    block_last="$(tail -c 1 "$block_file" | xxd -p)"
    if [ "$block_last" != "0a" ]; then printf '\n' >> "$target"; fi
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test_installer_helpers.bats`
Expected: `8 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add shared/installer-helpers.sh tests/test_installer_helpers.bats
git commit -m "feat: add installer-helpers.sh with yaml + claude.md block utilities"
```

---

## Task 3: Implement the SessionStart hook

**Why:** Slash commands and auto-capture flows write `source_session:` frontmatter. They need a reliable way to read the current session id. The hook writes a per-session marker file at `~/.claude/session-env/<id>/session-id.txt`.

**Files:**
- Create: `presets/karpathy-lite/hooks/session-start.sh`
- Test: `tests/test_session_start_hook.bats`
- Test fixtures: `tests/fixtures/session-start-stdin.json`

**Background:** Claude Code's hook protocol passes JSON on stdin describing the event. For SessionStart, the JSON includes a `session_id` field. The hook writes that id to `~/.claude/session-env/<id>/session-id.txt` so any tool (a slash command running later in the session) can `cat $CLAUDE_SESSION_DIR/session-id.txt` to discover the id. We also export `CLAUDE_CORTEX_SESSION_ID` and `CLAUDE_CORTEX_SESSION_DIR` for any process the hook spawns.

- [ ] **Step 1: Write failing tests**

Create `tests/fixtures/session-start-stdin.json`:

```json
{"session_id": "0193ab51-991c-7d40-8f00-deadbeef1234", "cwd": "/tmp/test", "hook_event_name": "SessionStart"}
```

Create `tests/test_session_start_hook.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test_session_start_hook.bats`
Expected: All tests fail with "no such file".

- [ ] **Step 3: Implement the hook**

```bash
#!/usr/bin/env bash
# presets/karpathy-lite/hooks/session-start.sh
# Claude Cortex SessionStart hook.
# Reads JSON from stdin, extracts session_id, writes marker file.
# Always exits 0 — a hook failure must never break the session.

set -u

CORTEX_HOME="${CLAUDE_CORTEX_HOME:-$HOME/.claude}"

stdin="$(cat)"

# Tolerate both stdin variants; we only need session_id.
session_id="$(printf '%s' "$stdin" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"

if [ -z "${session_id:-}" ]; then
  exit 0
fi

session_dir="$CORTEX_HOME/session-env/$session_id"
mkdir -p "$session_dir" 2>/dev/null || exit 0
printf '%s' "$session_id" > "$session_dir/session-id.txt" 2>/dev/null || exit 0

exit 0
```

- [ ] **Step 4: Mark hook executable**

Run: `chmod +x presets/karpathy-lite/hooks/session-start.sh`

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats tests/test_session_start_hook.bats`
Expected: `5 tests, 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add presets/karpathy-lite/hooks/session-start.sh tests/test_session_start_hook.bats tests/fixtures/session-start-stdin.json
git commit -m "feat: add SessionStart hook that captures session id to marker file"
```

---

## Task 4: Document the session-id discovery contract

**Why:** Slash commands and skill files need a single canonical instruction for "how to know my own session id." Document it in one place, reference from everywhere.

**Files:**
- Create: `shared/session-id-contract.md`

- [ ] **Step 1: Write the contract doc**

```markdown
# Session ID Discovery Contract

This is how a Claude Code session learns its own id at runtime, for use in
`source_session:` frontmatter and `sessions.yaml` updates.

## The contract

The Claude Cortex SessionStart hook (`~/.claude/hooks/claude-cortex-session-start.sh`)
runs at every session start. It reads JSON from stdin, extracts `session_id`, and
writes the id to:

```
~/.claude/session-env/<session_id>/session-id.txt
```

## How callers find their session id

There is no straightforward way for a Claude Code session to know its own id
without external help. The hook above writes a marker file per session. Callers
discover the id via this strategy:

1. **If `CLAUDE_CORTEX_SESSION_ID` is in the environment, use it.** (Set this
   in your wrapper or via Claude Code env settings if you control the launch.)

2. **Otherwise, find the most-recent session-id.txt in `~/.claude/session-env/`.**
   Useful for the bootstrapped case where no env var exists. The most recently
   modified session marker is the current session.

   ```bash
   find ~/.claude/session-env -name session-id.txt -type f -exec stat -f '%m %N' {} \; \
     | sort -rn | head -1 | awk '{print $2}' | xargs cat
   ```

3. **If neither works, fall back to writing `unknown` for `source_session:`.**
   The system continues to function; only the audit/forensics use case degrades.

## Why this approach

- Claude Code's hook protocol is the only reliable signal for session boundaries.
- A per-session marker file means the id is queryable from any later moment in
  the session (slash commands, capture flows) without re-parsing hook stdin.
- Marker files in `session-env/` are already a Claude Code convention; we are
  not introducing a novel directory.
- Concurrent sessions don't collide because each gets its own subdirectory.
```

- [ ] **Step 2: Commit**

```bash
git add shared/session-id-contract.md
git commit -m "docs: define session-id discovery contract"
```

---

## Task 5: Author `presets/karpathy-lite/preset.yaml`

**Why:** Preset metadata. The installer reads it; future tooling can introspect.

**Files:**
- Create: `presets/karpathy-lite/preset.yaml`

- [ ] **Step 1: Write the preset metadata**

```yaml
# presets/karpathy-lite/preset.yaml
name: karpathy-lite
display_name: "Karpathy-lite"
description: |
  Default Claude Cortex preset. Folders organized by kind of artifact
  (retros, insights, projects, people, references) rather than abstract
  life-domains. Auto-triage success rate is high because every routing
  decision is mechanical.
version: 0.1.0

defaults:
  auto_capture_mode: balanced
  stale_staging_days: 14
  index_auto_maintenance: true
  daily_notes: false

# Folders the installer creates in the vault skeleton.
# `_index.md` is auto-created via the skeleton itself.
skeleton_folders:
  - inbox
  - inbox/.archive
  - retros
  - insights
  - insights/debugging
  - insights/architecture
  - insights/tooling
  - projects
  - people
  - references
  - references/articles
  - references/books
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/preset.yaml
git commit -m "feat: add karpathy-lite preset.yaml metadata"
```

---

## Task 6: Author `presets/karpathy-lite/CLAUDE.md.tmpl`

**Why:** This is the global runtime contract that lands in `~/.claude/CLAUDE.md`. Every Claude Code session loads it. The single biggest piece of "user-visible product" in v1.

**Files:**
- Create: `presets/karpathy-lite/CLAUDE.md.tmpl`

- [ ] **Step 1: Write the template**

```markdown
# Claude Cortex — Second Brain

## Vault location
- Path: `{{VAULT_PATH}}`
- Preset: `karpathy-lite`
- Auto-capture mode: `{{AUTO_CAPTURE_MODE}}`
- Stale-staging threshold: {{STALE_STAGING_DAYS}} days
- Index auto-maintenance: {{INDEX_AUTO_MAINTENANCE}}
- Cortex version: {{CORTEX_VERSION}}

## Read/write contract

**You may READ from the vault freely** — search, grep, open files any time
the vault has relevant context for the user's question. Before reading any
file inside a vault folder, read that folder's `_index.md` if present and
use it to choose which files to open.

**You may WRITE to the vault only via these paths:**
1. **Auto-stage to `inbox/<W-ID>/`** — when you detect a query that worked,
   a decision being made, or a gotcha worth remembering. Always announce
   the stage in one line: `Staged → inbox/<W-ID>/<slug>.md`.
2. **Offer-and-approve for durable destinations** — when you detect content
   that belongs in `insights/`, `projects/<name>/decisions/`, `architecture/`,
   or `references/`. Surface a short proposal; user says yes/edit/no.
3. **Slash commands** — `/save-to-inbox`, `/save-insight`, `/retro`,
   `/resume-work`, `/triage-inbox`, `/refresh-index`. The user explicitly invoked.
4. **Natural-language equivalents** — phrases like "save this to the vault",
   "stage this", "let's retro W-XXXXXX". Map to the corresponding command.

**You may NEVER:**
- Modify existing notes outside `inbox/` without an explicit user request.
- Write literal credentials/secrets to the vault. Use references
  (e.g. `op://Vault/Item/field`, keychain item names) — never values.
  This rule applies to "mocked" or "test" credentials too.
- Delete files from the vault. The retro flow archives; only the user purges.

## Auto-capture heuristics (mode = `{{AUTO_CAPTURE_MODE}}`)

Detect these patterns and act per the mode. In every mode, auto-stages are
announced in one line; durable writes always go through offer-and-approve.

| Pattern | Trigger phrases | Type |
|---|---|---|
| Query confirmed working | "that worked", "yep returns the rows", "this query gives me…" | query |
| Decision made | "we decided", "going with X", "let's use X over Y" | decision |
| Generalizable gotcha | "turns out", "gotcha is", "next time remember" | insight |
| Architecture explained | extended explanation of repo/system structure | architecture |
| Person context | "Jane is the owner of…", "ask John about…" | person |
| W-XXXXXX mentioned | any `W-\d{6,}` pattern | (sets active work item) |

Mode behaviors:
- `aggressive`: auto-stage every detected pattern; batched offer at session end.
- `balanced` (default): auto-stage queries and scratch; offer for decisions/insights;
  batched offer at session end.
- `minimal`: no auto-stage; offers only at session end / completion signals.
- `off`: slash commands + natural language only.

## Triggers

| Trigger | When | What you do |
|---|---|---|
| Slash command | user types `/retro`, `/save-insight`, etc. | Run the command. |
| Natural language | "save this to the vault", "stage this", "let's retro W-XXXXXX" | Map to corresponding command. |
| Auto-stage | Heuristic match per mode | Stage and announce in one line. |
| Session-end offer | Long session (>30 min activity) AND captures made/queued | Ask once: "Save these N items?" |
| Completion signal | PR merged via `gh`, "shipped it", work-item closed | Ask: "Run /retro for W-<ID>?" |
| Stale-staging | At session start: any `inbox/W-*/` `last_touched` > {{STALE_STAGING_DAYS}} days | One-line surface; offer `/triage-inbox`. |

## Routing table (Karpathy-lite)

| `type:` | Destination |
|---|---|
| `scratch` | `inbox/<W-ID>/<slug>.md` |
| `retro` | `retros/<project>/YYYY-MM-DD-<W-ID>-<slug>.md` |
| `insight` | `insights/<topic>/<slug>.md` |
| `architecture` | `projects/<project>/architecture/<slug>.md` |
| `decision` | `projects/<project>/decisions/YYYY-MM-DD-<slug>.md` |
| `query` | `projects/<project>/queries/<query_kind>/<slug>.md` |
| `person` | `people/<firstname>-<lastname>-<role-slug>.md` |
| `reference` | `references/<kind>/<slug>.md` |

## Frontmatter requirement

Every Claude-written note carries YAML frontmatter:

```yaml
---
type: <required, drives routing>
title: "<required>"
created: <ISO-8601 UTC>
updated: <ISO-8601 UTC>
tags: [<list>]
source_session: <session-id>
---
```

The full per-type schema lives in `~/.claude/skills/claude-cortex/claude-cortex.md`.

## Index files (`_index.md`)

Before reading any vault folder's contents, read its `_index.md` first if present.
When you write a new file via any capture flow, also update the parent folder's
`_index.md`: add an entry under "Contents" with a one-line description, and
bump `last_updated:`.

## Session tracking

When writing into `inbox/<W-ID>/`, also update `inbox/<W-ID>/sessions.yaml`:
- Create with current session id, started, cwd, summary if first time.
- Update `last_touched`, append/refresh this session's entry, add new file
  to `files_touched` on subsequent writes.

The session id comes from the marker file at
`~/.claude/session-env/<id>/session-id.txt` (written by the SessionStart hook).
The discovery procedure is documented in
`~/.claude/skills/claude-cortex/claude-cortex.md` § Session ID.

## When in doubt
Ask the user. Especially: ambiguous routing, ambiguous work item, unclear
whether something belongs in inbox vs. a durable folder.
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/CLAUDE.md.tmpl
git commit -m "feat: add karpathy-lite CLAUDE.md template"
```

---

## Task 7: Author the vault skeleton (`_index.md` files)

**Why:** When the installer copies `presets/karpathy-lite/skeleton/` into the vault, every folder must already have a useful `_index.md` so the user immediately understands what each folder is for.

**Files:**
- Create: `presets/karpathy-lite/skeleton/_index.md`
- Create: `presets/karpathy-lite/skeleton/inbox/_index.md`
- Create: `presets/karpathy-lite/skeleton/inbox/.archive/.gitkeep`
- Create: `presets/karpathy-lite/skeleton/retros/_index.md`
- Create: `presets/karpathy-lite/skeleton/insights/_index.md`
- Create: `presets/karpathy-lite/skeleton/insights/debugging/_index.md`
- Create: `presets/karpathy-lite/skeleton/insights/architecture/_index.md`
- Create: `presets/karpathy-lite/skeleton/insights/tooling/_index.md`
- Create: `presets/karpathy-lite/skeleton/projects/_index.md`
- Create: `presets/karpathy-lite/skeleton/people/_index.md`
- Create: `presets/karpathy-lite/skeleton/references/_index.md`
- Create: `presets/karpathy-lite/skeleton/references/articles/.gitkeep`
- Create: `presets/karpathy-lite/skeleton/references/books/.gitkeep`

- [ ] **Step 1: Create vault root `_index.md`**

Write `presets/karpathy-lite/skeleton/_index.md`:

```markdown
---
folder: /
purpose: Top-level map of the Claude Cortex vault
last_updated: 2026-05-12
---

# Vault root

This is your second brain. Claude Code reads it freely and writes only via
explicit capture flows defined in `~/.claude/CLAUDE.md`.

## Top-level folders
- [inbox/](inbox/_index.md) — STAGING ONLY. Per-work-item folders that get
  promoted at retro. Don't put things here you intend to keep.
- [retros/](retros/_index.md) — synthesized retrospectives produced by
  `/retro`, organized by project.
- [insights/](insights/_index.md) — durable cross-project lessons. Debugging
  gotchas, architecture patterns, tooling tips.
- [projects/](projects/_index.md) — per-project canonical knowledge.
  Each project has a `README.md`, `architecture/`, `decisions/`,
  `queries/`, `org-ids.md`, etc.
- [people/](people/_index.md) — collaborators, expertise, 1:1 notes.
- [references/](references/_index.md) — distilled external reading.

## Conventions
- Every Claude-written note has YAML frontmatter with at least `type:`,
  `title:`, `created:`, `updated:`, and `source_session:`.
- Every folder has a `_index.md` listing its contents.
- Filenames are kebab-case, ~6 words max.
- Dates in filenames are `YYYY-MM-DD`.
- Credentials are never literals — only references (`op://...`, keychain
  item names).
```

- [ ] **Step 2: Create `inbox/_index.md`**

Write `presets/karpathy-lite/skeleton/inbox/_index.md`:

```markdown
---
folder: inbox
purpose: Staging area for mid-flight work. All files here are temporary.
last_updated: 2026-05-12
---

# Inbox — staging only

Work-item folders accumulate here during active work. Run `/retro <W-ID>` to
synthesize them into durable destinations.

## Active staging folders

(None yet — Claude will list them here as they're created.)

## Stale folders

If any folder here has `last_touched` > 14 days, Claude will flag it at session
start and offer `/triage-inbox`.

## Archive

Promoted staging folders move to `.archive/`. Read-only by convention; auditable
for "which session wrote this?" forensics.
```

- [ ] **Step 3: Create `inbox/.archive/.gitkeep`**

Write empty file `presets/karpathy-lite/skeleton/inbox/.archive/.gitkeep`.

- [ ] **Step 4: Create `retros/_index.md`**

Write `presets/karpathy-lite/skeleton/retros/_index.md`:

```markdown
---
folder: retros
purpose: Synthesized retrospectives, organized by project
last_updated: 2026-05-12
---

# Retrospectives

Each retro is a fresh synthesis Claude wrote at the end of a work item. Filename
pattern: `<project>/YYYY-MM-DD-W-<ID>-<slug>.md`.

## Projects

(Subfolders appear as projects accumulate retros.)
```

- [ ] **Step 5: Create `insights/_index.md`**

Write `presets/karpathy-lite/skeleton/insights/_index.md`:

```markdown
---
folder: insights
purpose: Durable cross-project lessons
last_updated: 2026-05-12
---

# Insights

Cross-cutting lessons that apply beyond one project. Subfolders are by topic.

## Topics
- [debugging/](debugging/_index.md) — debugging gotchas and patterns
- [architecture/](architecture/_index.md) — architecture decisions/patterns worth remembering
- [tooling/](tooling/_index.md) — tool-specific lessons (CI, build systems, editors)

Add new topic folders as needed. Folder names are kebab-case.
```

- [ ] **Step 6: Create `insights/debugging/_index.md`**

Write `presets/karpathy-lite/skeleton/insights/debugging/_index.md`:

```markdown
---
folder: insights/debugging
purpose: Durable debugging gotchas and patterns
last_updated: 2026-05-12
---

# Debugging insights

Gotchas, traps, and patterns that bit you once and would bite again.

## Contents

(Empty — Claude will populate as gotchas accumulate.)

## Read this folder when
- Investigating a flaky log query
- Reading a stack trace that doesn't match source
- A query returns unexpected counts
```

- [ ] **Step 7: Create `insights/architecture/_index.md`**

Write `presets/karpathy-lite/skeleton/insights/architecture/_index.md`:

```markdown
---
folder: insights/architecture
purpose: Architecture patterns and decisions worth carrying between projects
last_updated: 2026-05-12
---

# Architecture insights

Patterns and decisions that generalize across projects. Project-specific
architecture lives under `projects/<project>/architecture/`.

## Contents

(Empty.)
```

- [ ] **Step 8: Create `insights/tooling/_index.md`**

Write `presets/karpathy-lite/skeleton/insights/tooling/_index.md`:

```markdown
---
folder: insights/tooling
purpose: Tool-specific lessons (CI, build systems, editors)
last_updated: 2026-05-12
---

# Tooling insights

Things you learned about your tools the hard way.

## Contents

(Empty.)
```

- [ ] **Step 9: Create `projects/_index.md`**

Write `presets/karpathy-lite/skeleton/projects/_index.md`:

```markdown
---
folder: projects
purpose: Per-project canonical knowledge
last_updated: 2026-05-12
---

# Projects

One subfolder per project. Each project subfolder typically contains:

- `README.md` — overview, status, links
- `architecture/` — architecture notes
- `decisions/` — ADR-style decisions
- `queries/<query_kind>/` — saved queries (splunk/, soql/, sql/, argus/, ...)
- `org-ids.md` — test/scratch/prod-investigation orgs
- `secrets.md` — REFERENCES to keychain/1Password, never literal values
- `open-questions.md` — running list

## Active projects

(Empty — Claude will populate as projects are referenced.)
```

- [ ] **Step 10: Create `people/_index.md`**

Write `presets/karpathy-lite/skeleton/people/_index.md`:

```markdown
---
folder: people
purpose: Collaborators, expertise, 1:1 notes
last_updated: 2026-05-12
---

# People

One file per person. Filename pattern: `<firstname>-<lastname>-<role-slug>.md`.

## Contents

(Empty.)
```

- [ ] **Step 11: Create `references/_index.md`**

Write `presets/karpathy-lite/skeleton/references/_index.md`:

```markdown
---
folder: references
purpose: Distilled external reading
last_updated: 2026-05-12
---

# References

External material distilled. The point is not to mirror the source — it's to
capture the parts you'll come back to.

## Subfolders
- [articles/](articles/) — blog posts, papers, internal docs
- [books/](books/) — books, distilled by chapter or by theme

(Index files for subfolders are added when their first entry lands.)
```

- [ ] **Step 12: Create empty `.gitkeep` files for `references/articles/` and `references/books/`**

Write `presets/karpathy-lite/skeleton/references/articles/.gitkeep` (empty)
Write `presets/karpathy-lite/skeleton/references/books/.gitkeep` (empty)

- [ ] **Step 13: Verify the skeleton tree**

Run: `find presets/karpathy-lite/skeleton -type f | sort`
Expected output:

```
presets/karpathy-lite/skeleton/_index.md
presets/karpathy-lite/skeleton/inbox/.archive/.gitkeep
presets/karpathy-lite/skeleton/inbox/_index.md
presets/karpathy-lite/skeleton/insights/_index.md
presets/karpathy-lite/skeleton/insights/architecture/_index.md
presets/karpathy-lite/skeleton/insights/debugging/_index.md
presets/karpathy-lite/skeleton/insights/tooling/_index.md
presets/karpathy-lite/skeleton/people/_index.md
presets/karpathy-lite/skeleton/projects/_index.md
presets/karpathy-lite/skeleton/references/_index.md
presets/karpathy-lite/skeleton/references/articles/.gitkeep
presets/karpathy-lite/skeleton/references/books/.gitkeep
presets/karpathy-lite/skeleton/retros/_index.md
```

- [ ] **Step 14: Commit**

```bash
git add presets/karpathy-lite/skeleton
git commit -m "feat: add karpathy-lite vault skeleton with _index.md files"
```

---

## Task 8: Author the consolidated skill file

**Why:** This is the procedural depth the CLAUDE.md block points to. Claude reads it on demand when running a slash command, performing a retro synthesis, or resolving a routing edge case.

**Files:**
- Create: `presets/karpathy-lite/skills/claude-cortex.md`

- [ ] **Step 1: Write the skill**

```markdown
---
name: claude-cortex
description: Use when running any Claude Cortex slash command (/save-insight, /save-to-inbox, /retro, /resume-work, /triage-inbox, /refresh-index), when auto-staging into the vault, when synthesizing retrospectives, or when resolving routing/frontmatter questions for vault writes.
---

# Claude Cortex Skill

The full procedural manual for the Claude Cortex second-brain system. The
top-level contract lives in `~/.claude/CLAUDE.md`; this file is the depth.

## Quick Pointers

- Vault location and runtime config — `~/.claude/CLAUDE.md` (between
  `<!-- claude-cortex:begin v1 -->` delimiters)
- Persistent install metadata — `<vault>/.claude-cortex/config.yaml`
- Session id discovery — § Session ID below

## Frontmatter Schema (full)

### Universal fields (every Claude-written note)

```yaml
---
type: insight | retro | architecture | decision | query | person | reference | scratch
title: "<required, human-readable>"
created: 2026-05-12T11:30:00Z      # ISO-8601 UTC
updated: 2026-05-12T11:30:00Z      # ISO-8601 UTC
tags: [<free-form list>]
source_session: <session-id>       # see § Session ID
---
```

### Type-specific fields

```yaml
# type: retro
work_item: W-123456
project: agentforce-actions
duration_days: 4
related: [insights/debugging/splunk-pagination-gotcha.md]

# type: insight
topic: debugging                   # subfolder under insights/
applies_to: [agentforce-actions, udd-entity-builder]

# type: architecture
project: agentforce-actions
component: rate-limiter

# type: decision
project: agentforce-actions
status: accepted | superseded | proposed
supersedes: [decisions/2026-04-01-old.md]

# type: query
project: agentforce-actions
query_kind: splunk | soql | sql | argus | graphql | curl | <other-kebab-case>
used_in: [W-123456, W-123777]

# type: person
role: "Staff Engineer"
team: "Platform Foundations"
expertise: [auth, rate-limiting]
```

## Routing Table

| `type:` | Destination |
|---|---|
| `scratch` | `inbox/<W-ID>/<slug>.md` |
| `retro` | `retros/<project>/YYYY-MM-DD-<W-ID>-<slug>.md` |
| `insight` | `insights/<topic>/<slug>.md` |
| `architecture` | `projects/<project>/architecture/<slug>.md` |
| `decision` | `projects/<project>/decisions/YYYY-MM-DD-<slug>.md` |
| `query` | `projects/<project>/queries/<query_kind>/<slug>.md` |
| `person` | `people/<firstname>-<lastname>-<role-slug>.md` |
| `reference` | `references/<kind>/<slug>.md` |

Slug rules: kebab-case, lowercase, ~6 words max, descriptive.

## Session ID

Read the current session id via this procedure (in order):

1. If `CLAUDE_CORTEX_SESSION_ID` is set in the environment, use it.
2. Else: find the most-recent `~/.claude/session-env/*/session-id.txt` and
   read it. Use this Bash:

   ```bash
   find ~/.claude/session-env -name session-id.txt -type f -exec stat -f '%m %N' {} \; \
     | sort -rn | head -1 | awk '{print $2}' | xargs cat
   ```

3. If neither yields a value, write `unknown` to `source_session:`. The
   system continues to function; only audit/forensics use cases degrade.

## Vault Path Discovery

Read the `Vault location: Path:` line of the cortex block in
`~/.claude/CLAUDE.md`. Authoritative copy is also at
`<vault>/.claude-cortex/config.yaml` under the `vault_path:` key.

## Default Project Resolution

When a flow needs a `project:` value and none was given:
1. If a `W-XXXXXX` is the active work item and a previous note in
   `inbox/<W-ID>/` carries `project:`, use that.
2. Else: read the basename of the user's current working directory
   (`pwd | xargs basename`). That's typically the repo name and is the
   right project unless told otherwise.
3. Else: ask the user.

## Inbox Staging Procedure

When writing to `inbox/<W-ID>/`:

1. Discover session id (§ Session ID).
2. If `inbox/<W-ID>/` does not exist:
   - `mkdir -p inbox/<W-ID>`
   - Create `inbox/<W-ID>/sessions.yaml`:
     ```yaml
     work_item: W-<ID>
     title: "<short title — ask user if unclear>"
     created: <now ISO-8601 UTC>
     last_touched: <now ISO-8601 UTC>
     sessions:
       - id: <session-id>
         started: <now ISO-8601 UTC>
         cwd: <pwd>
         summary: "<one-liner what this session is doing>"
         files_touched: [<the file you're about to write>]
     ```
   - Create `inbox/<W-ID>/_index.md` with `## Contents` listing the new file.
3. Else (folder exists):
   - Read `sessions.yaml`.
   - Update `last_touched` to now.
   - If this session id is already in `sessions:`, update its
     `files_touched` (append the new file) and refresh `summary` if it
     adds info. Else: append a new session entry.
   - Append the new file to `_index.md` under `## Contents`.
4. Write the staged note with full frontmatter (`type: scratch`) plus body.
5. Update `inbox/_index.md` "Active staging folders" with the W-ID and
   current `last_touched`.
6. Announce in chat: `Staged → inbox/<W-ID>/<slug>.md`

## `_index.md` Auto-Maintenance

When you create a new file in any folder:

1. Read parent folder's `_index.md` if it exists; create with the standard
   frontmatter if not.
2. Add an entry under `## Contents`:
   ```
   - [<slug>] — <one-line description, 50-90 chars>
   ```
3. Update `last_updated:` in the frontmatter to today's date (UTC).

## Retro Synthesis (`/retro <W-ID>`)

The full algorithm. Run this when the user invokes `/retro` or a natural-
language equivalent.

### 1. Load

- If no W-ID arg: list `inbox/W-*/` sorted by `last_touched` and pick (or
  prompt the user if multiple).
- Read `inbox/<W-ID>/sessions.yaml`.
- Read every staged file (skip `sessions.yaml`, `_index.md`).

### 2. Plan

For each staged file, decide one of:

- **PROMOTE** — content is a single durable note. Pick destination by `type:`
  (or by content if `type: scratch`). Plan a write to a new file at the
  routed destination.
- **EXTRACT** — content has both transient and durable parts. Plan to write
  the durable part as a new file at the routed destination, summarizing the
  transient part into the synthesized retro.
- **APPEND** — content adds context to an existing durable file (rare).
  Plan to append a clearly-delimited section.
- **DISCARD** — transient. Don't promote; mention in the retro for
  completeness.

Plan the synthesized retro at:

```
retros/<project>/YYYY-MM-DD-W-<ID>-<slug>.md
```

The retro carries `type: retro`, `source_session: <current session id>`,
plus the `work_item:`, `project:`, `duration_days:`, `related:` fields.

Plan the archive operation:

```
inbox/<W-ID>/  →  inbox/.archive/<W-ID>/
```

Plan all `_index.md` updates:

- Each new file at a routed destination → its parent `_index.md`.
- The retro file → `retros/<project>/_index.md`.
- Removed `inbox/<W-ID>/` entry → `inbox/_index.md`.

### 3. Present plan as a unified diff

Show the user, in one message:

```
Retro plan for W-<ID> — "<title from sessions.yaml>"

  PROMOTE:
    inbox/<W-ID>/decision-cache-ttl-30m.md
      → projects/<project>/decisions/2026-05-12-cache-ttl.md
    inbox/<W-ID>/soql-failing-rows.md
      → projects/<project>/queries/soql/find-failing-rows.md

  EXTRACT:
    inbox/<W-ID>/splunk-trace.md
      → insights/debugging/splunk-pagination-gotcha.md (durable lesson)
      summary into retro (transient details)

  APPEND:
    (none)

  DISCARD:
    inbox/<W-ID>/question-ask-jane.md (transient — mentioned in retro)

  SYNTHESIZE:
    retros/<project>/2026-05-12-W-<ID>-<slug>.md (new)

  ARCHIVE:
    inbox/<W-ID>/ → inbox/.archive/<W-ID>/

  INDEX UPDATES:
    projects/<project>/decisions/_index.md
    projects/<project>/queries/soql/_index.md
    insights/debugging/_index.md
    retros/<project>/_index.md
    inbox/_index.md

Apply this plan? [y/edit/n]
```

If the user picks `edit`, ask which entries to change and re-present.

### 4. Apply atomically

- Create all new files (promotes, extracts, retro).
- Update all `_index.md` files.
- Move `inbox/<W-ID>/` to `inbox/.archive/<W-ID>/` (use `mv`, not copy+delete).
- Save the dispatch plan as
  `inbox/.archive/<W-ID>/dispatch-plan.md` for auditability.

If any step fails, roll back: delete any new files written this run and
restore `inbox/<W-ID>/` from the archive (it's a `mv` away).

### 5. Report

```
Retro complete.
  1 retro written: retros/<project>/2026-05-12-W-<ID>-<slug>.md
  2 promotions, 1 extraction, 0 appends, 1 discarded.
  Archive: inbox/.archive/<W-ID>/
```

## Resume Brief (`/resume-work <W-ID>`)

Produce a single message that reorients the user.

1. Read `inbox/<W-ID>/sessions.yaml`.
2. Read every staged file's frontmatter (skip body — keep this fast).
3. Present:

```
Work item:   W-<ID> — "<title>"
Started:     2026-04-20 (22 days ago)
Last touched: 2026-04-25 (17 days ago)

Sessions:
  • <id1> (2026-04-20) — "<summary>"
  • <id2> (2026-04-25) — "<summary>"

Staged notes:
  • notes.md                 — running task list
  • soql-query-failing-rows.md — query found 2400 bad rows
  • decision-cache-ttl-30m.md — cache TTL choice + rationale

Open questions (extracted from notes' frontmatter and headings):
  - rate limit per-org vs per-user?
  - rollback path if cache TTL too short?

Suggested next actions:
  (a) Continue here with staged notes as context.
  (b) `claude --resume <id2>` for richer last-session context.
  (c) Run /retro <W-ID> if work is actually done.
```

## Stale Detection

At session start, if any `inbox/W-*/sessions.yaml` has
`last_touched` > {{stale_staging_days}} days ago: surface a one-line notice
in your first response of the session:

```
You have N stale staging folder(s) (>14d). Run /triage-inbox to handle them.
```

Don't block the user's actual question.

## Refresh Index

When the user invokes `/refresh-index <folder>`:

1. Read existing `<folder>/_index.md` if present, preserving every section
   that isn't `## Contents`.
2. List all files in `<folder>` (top-level only, not recursive).
3. For each file, read its frontmatter `title:` and produce a one-liner.
4. Rewrite `## Contents` with the fresh listing.
5. Show the diff. Apply on approval.

## Credentials Rule

Never write a literal credential value into any vault file. If the user
asks, refuse and offer a reference instead:

> I can't write `<value>` into the vault — Cortex's safety rule forbids
> literal secrets even for mocked/test creds. Want me to write a reference
> like `op://Engineering/agentforce-test-user/password`, or a keychain
> item name, instead?

## Pitfalls

- Two sessions writing to the same `inbox/<W-ID>/sessions.yaml` can race.
  Mitigation: re-read the file just before writing; if the contents on disk
  changed since you last read, merge your changes in (append your session,
  union `files_touched`) before writing.
- Don't recurse into `_index.md` updates: only update the *direct* parent
  folder of the file you wrote.
- `_index.md` autogeneration must preserve hand-written prose sections
  (purpose, "Read this folder when", "See also").
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/skills/claude-cortex.md
git commit -m "feat: add consolidated claude-cortex skill file"
```

---

## Task 9: Author `/save-to-inbox` slash command

**Why:** Zero-friction staging is the most-used capture flow. Implementing it first because it's the simplest and validates the slash-command + skill-file integration.

**Files:**
- Create: `presets/karpathy-lite/commands/save-to-inbox.md`

- [ ] **Step 1: Write the slash command**

```markdown
---
description: "Stage scratch into inbox/<W-ID>/ — zero-friction capture, no routing decisions until /retro"
argument-hint: "[W-ID] [title=...]"
source: claude-cortex
---

You are running the `/save-to-inbox` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: stage one or more scratch notes into `<vault>/inbox/<W-ID>/` with
the staging procedure documented in the claude-cortex skill.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`
   if you haven't already this session. You need § Inbox Staging Procedure,
   § Frontmatter Schema, § Session ID, § Default Project Resolution.

2. **Resolve the W-ID:**
   - If `$ARGUMENTS` starts with `W-` followed by 6+ digits, use that.
   - Else: scan recent conversation for `W-\d{6,}`; if exactly one matches,
     use it.
   - Else: ask the user: "Which work item? (W-XXXXXX, or 'none' for unclassified)"
   - "none" → use `inbox/_unclassified/` instead of `inbox/<W-ID>/`.

3. **Resolve the title:**
   - If `$ARGUMENTS` includes `title=...` (quoted), use that.
   - Else: derive a kebab-case slug from the most recent meaningful exchange.
   - The slug becomes the filename: `<slug>.md`.

4. **Determine what to stage:** if the user explicitly said "stage this" or
   similar after a specific message, that message's content is the body.
   Otherwise, ask: "What should I stage? Paste it here or describe it."

5. **Resolve the project** per § Default Project Resolution.

6. **Apply the Inbox Staging Procedure** from the skill.

7. **Announce the result in one line:**

   ```
   Staged → <vault>/inbox/<W-ID>/<slug>.md
   ```

## Constraints

- Do not promote to a durable folder. This is staging only.
- Do not skip the `sessions.yaml` update or the `_index.md` update.
- Do not write literal credentials per § Credentials Rule.
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/commands/save-to-inbox.md
git commit -m "feat: add /save-to-inbox slash command"
```

---

## Task 10: Author `/save-insight` slash command

**Why:** Single-note durable capture. Routes by `type:` to the right destination.

**Files:**
- Create: `presets/karpathy-lite/commands/save-insight.md`

- [ ] **Step 1: Write the slash command**

```markdown
---
description: "Save a single durable note (insight, architecture, decision, query, reference) — auto-routed by type"
argument-hint: "[type=insight|architecture|decision|query|reference] [title=...]"
source: claude-cortex
---

You are running the `/save-insight` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: write one durable note to its routed destination, update the parent
folder's `_index.md`, and report the path.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`.
   You need § Frontmatter Schema, § Routing Table, § Session ID,
   § Default Project Resolution, § `_index.md` Auto-Maintenance.

2. **Resolve `type`:**
   - If `$ARGUMENTS` includes `type=...`, use that.
   - Else: ask the user: "Type? (insight | architecture | decision | query | reference)"
   - Validate against the routing table. If invalid, ask again.

3. **Determine what to save:** if there's clear context from the conversation
   for what the user wants captured, use it. Otherwise, ask.

4. **Resolve type-specific fields per the schema:**
   - For `insight`: `topic` (subfolder under `insights/`).
   - For `architecture` / `decision` / `query`: `project`.
   - For `query`: also `query_kind` (splunk | soql | sql | argus | graphql | curl | other).
   - For `decision`: `status` (accepted by default).
   - For `person`: `role`, `team`, `expertise`.
   - For `reference`: `kind` (article | book | other).
   - Ask only for fields you can't derive from context.

5. **Compute the destination path** from the routing table.

6. **Compute the slug** from the title (kebab-case, ~6 words max).

7. **Show a preview to the user:**

   ```
   Will save:
     <abs path>

   ---
   <full file content with frontmatter>
   ---

   Apply? [y/edit/n]
   ```

8. **On approval, write the file and update parent `_index.md`** per the
   skill's § `_index.md` Auto-Maintenance.

9. **Report:**

   ```
   Saved → <abs path>
   ```

## Constraints

- One file per invocation. If the user wants to capture multiple things,
  invoke `/save-insight` again or use `/retro` for a batch.
- Apply § Credentials Rule before writing.
- If the destination already exists with the same slug, ask: append to
  existing, write with a different slug, or cancel.
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/commands/save-insight.md
git commit -m "feat: add /save-insight slash command"
```

---

## Task 11: Author `/retro` slash command

**Why:** The workhorse. Ties together synthesis, dispatch, and archive.

**Files:**
- Create: `presets/karpathy-lite/commands/retro.md`

- [ ] **Step 1: Write the slash command**

```markdown
---
description: "Synthesize and dispatch a staged inbox/<W-ID>/ folder — promotes notes to durable destinations and writes a fresh retrospective"
argument-hint: "[W-ID]"
source: claude-cortex
---

You are running the `/retro` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: read the staged folder, propose a dispatch plan as a unified diff,
apply it atomically on approval, and report.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`,
   specifically § Retro Synthesis. Follow it to the letter.

2. **Resolve the W-ID:**
   - If `$ARGUMENTS` is a W-ID, use it.
   - Else: list `inbox/W-*/` folders sorted by `last_touched` desc. If
     exactly one exists, pick it. Else: ask the user which.

3. **Execute § Retro Synthesis steps 1-5** from the skill.

4. **Atomicity rule:** if any file write or `mv` fails partway through,
   restore: delete files written this run, `mv inbox/.archive/<W-ID>/
   inbox/<W-ID>/` if archived. Report the failure to the user.

## Constraints

- Never delete files. Archive only.
- The retro is a fresh synthesis — do not just rename or copy a staged file.
- Save the dispatch plan as `inbox/.archive/<W-ID>/dispatch-plan.md` for
  auditability before doing the moves.
- Apply § Credentials Rule to every promoted/extracted note.
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/commands/retro.md
git commit -m "feat: add /retro slash command"
```

---

## Task 12: Author `/resume-work` slash command

**Why:** Post-vacation context recovery. The brief is the value.

**Files:**
- Create: `presets/karpathy-lite/commands/resume-work.md`

- [ ] **Step 1: Write the slash command**

```markdown
---
description: "Brief the user on a work item from the inbox — sessions, staged notes, open questions, next actions"
argument-hint: "[W-ID]"
source: claude-cortex
---

You are running the `/resume-work` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: produce a single brief that reorients the user on a paused work item.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`,
   specifically § Resume Brief.

2. **Resolve the W-ID:**
   - If `$ARGUMENTS` is a W-ID, use it.
   - Else: list `inbox/W-*/` sorted by `last_touched` desc. Show the user
     the list with one-line summaries from each `sessions.yaml`. Ask which.

3. **Execute § Resume Brief** from the skill.

## Constraints

- Read frontmatter, not full bodies. Bodies are large; the brief is short.
- The brief is the only response. Don't auto-act on the suggestions —
  wait for the user to pick.
- "Open questions" extracted from notes: scan for headings/bullets matching
  `## Open questions`, `## Questions`, or list items starting with `?`.
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/commands/resume-work.md
git commit -m "feat: add /resume-work slash command"
```

---

## Task 13: Author `/triage-inbox` slash command

**Why:** Periodic stale cleanup. Surfaces forgotten work.

**Files:**
- Create: `presets/karpathy-lite/commands/triage-inbox.md`

- [ ] **Step 1: Write the slash command**

```markdown
---
description: "Scan inbox for stale staging folders (>N days) and offer per-folder actions: retro, resume, defer, discard"
argument-hint: "[--stale-days=14] [--purge]"
source: claude-cortex
---

You are running the `/triage-inbox` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: surface stale `inbox/W-*/` folders and let the user act on each.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`,
   specifically § Stale Detection and § Retro Synthesis.

2. **Parse arguments:**
   - `--stale-days=N` (default 14, sprint-aligned)
   - `--purge` (also clean `.archive/` entries older than 90 days)

3. **Scan `inbox/W-*/sessions.yaml`** for `last_touched` older than the
   threshold.

4. **For each stale folder, present a brief** (per § Resume Brief, abbreviated)
   and offer:
   ```
   (a) Retro now — invoke /retro <W-ID>.
   (b) Resume an originating session and retro there.
   (c) Defer — touch the folder so it isn't flagged for another sprint.
   (d) Discard — move to inbox/.archive/<W-ID>/ without synthesis.
   ```

5. **If `--purge`:** list every `inbox/.archive/<W-ID>/` with mtime > 90d.
   Show the list. Ask: "Remove these N folders permanently? [y/N]"
   On `y`, `rm -rf` each. On anything else, skip.

6. **If no stale folders found:** report `Inbox is clean (no folders > N days).`

## Constraints

- "Defer" must actually update `last_touched` in `sessions.yaml` so the
  next scan won't re-flag.
- "Discard" archives — never deletes the staged files (that's `--purge`'s job
  much later).
- `--purge` requires explicit `y` — `--purge --yes` shorthand is not allowed.
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/commands/triage-inbox.md
git commit -m "feat: add /triage-inbox slash command"
```

---

## Task 14: Author `/refresh-index` slash command

**Why:** Drift recovery for `_index.md` files after manual moves in Obsidian.

**Files:**
- Create: `presets/karpathy-lite/commands/refresh-index.md`

- [ ] **Step 1: Write the slash command**

```markdown
---
description: "Regenerate a folder's _index.md from its actual contents — preserves hand-written prose"
argument-hint: "<relative-path-from-vault-root>"
source: claude-cortex
---

You are running the `/refresh-index` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: rebuild `<folder>/_index.md` from the actual files in `<folder>`, while
preserving hand-written prose sections.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`,
   specifically § Refresh Index.

2. **Validate input:**
   - If `$ARGUMENTS` is empty, ask: "Which folder? (path relative to vault root)"
   - Resolve the absolute path against the vault path from `~/.claude/CLAUDE.md`.
   - If the folder doesn't exist, error and exit.

3. **Read existing `<folder>/_index.md`** if present. Identify and preserve
   every section that isn't `## Contents` (e.g., `# <heading>` prose,
   `## Read this folder when`, `## See also`).

4. **List files in the folder** (top-level, non-recursive). For each, read
   the frontmatter `title:` and produce one line:

   ```
   - [<basename-without-ext>] — <title or first H1 if no title>
   ```

   Skip `_index.md` itself, skip `.gitkeep`, skip dotfiles.

5. **Rewrite the file:**
   - Keep the frontmatter, update `last_updated:` to today (UTC date).
   - Keep all preserved sections.
   - Replace the `## Contents` section with the fresh listing.

6. **Show the diff** of the proposed new content against the current file.

7. **On approval, write the file. Report:**

   ```
   Refreshed → <folder>/_index.md
   ```

## Constraints

- Recursive refresh is out of scope. One folder per invocation. If the user
  wants every folder, they can invoke this once per folder or write a wrapper.
- Don't touch any file other than the target `_index.md`.
- If the folder has no `_index.md` at all, create one with default frontmatter
  and prose `## Contents` only — no fabricated `purpose:` or "Read this when"
  sections.
```

- [ ] **Step 2: Commit**

```bash
git add presets/karpathy-lite/commands/refresh-index.md
git commit -m "feat: add /refresh-index slash command"
```

---

## Task 15: Author `install.md`

**Why:** The script Claude reads and executes when the user pastes the README block. The single largest user-visible artifact in the repo.

**Files:**
- Create: `install.md`

- [ ] **Step 1: Write the installer**

````markdown
# Claude Cortex Installer

You are Claude Code, executing the Claude Cortex installer. The user pasted
a prompt instructing you to read this file and follow it step by step.

The repo lives at `https://github.com/orkeren21/claude-cortex`. Treat that
URL prefix + the path to a file as the way to fetch any preset/skill/skeleton
file you need to copy. (Use `curl` or `WebFetch` to read individual files;
or `git clone` into a tmp dir for an atomic batch copy.)

## Goal

Lay down Claude Cortex on the user's machine: vault skeleton, skills, slash
commands, SessionStart hook, CLAUDE.md block, and persistent config.

## Posture

**Show every action before taking it.** Install is a privileged operation.
For every file you'll create/modify, present the path and the diff/content,
and wait for explicit "apply" before writing.

## §0 — Preflight

Run these checks. If any fail, bail with a clear message.

1. **OS check.**

   ```bash
   uname -s
   ```

   - If `Darwin`: continue.
   - If anything else: print `Claude Cortex v0.1.0 supports macOS only. Aborting.` and stop.

2. **Obsidian check.**

   ```bash
   test -d /Applications/Obsidian.app
   ```

   - If found: continue.
   - If not: ask the user: "Obsidian.app not found. Install it via Homebrew?"
     - On yes: run `brew install --cask obsidian`. If `brew` is missing,
       point them at https://brew.sh and bail.
     - On no: bail. Cortex requires Obsidian.

3. **Claude Code config dir check.**

   ```bash
   test -d ~/.claude
   ```

   - If yes: continue.
   - If no: print `~/.claude not found — install Claude Code first.` and bail.

## §1 — Vault discovery

1. Search common vault paths:

   ```bash
   ls -d ~/Documents/Obsidian/*/.obsidian 2>/dev/null \
   ; ls -d ~/Obsidian/*/.obsidian 2>/dev/null \
   ; ls -d ~/vault/.obsidian 2>/dev/null
   ```

   Each `.obsidian` directory's parent is a vault candidate.

2. **If candidates found:** present them numbered, default to the first:

   ```
   Found Obsidian vaults:
     1. /Users/.../Documents/Obsidian/WorkOS  (default)
     2. /Users/.../Documents/Obsidian/Personal
   Use which? (1-2 or absolute path)
   ```

3. **If none found:** ask: "No vault found. Provide an absolute path, or I
   can create one at `~/Documents/Obsidian/Cortex`. Which?"

   On `create`: `mkdir -p` the path and create a minimal `.obsidian/` dir
   with empty `app.json`, `appearance.json`, `core-plugins.json` so
   Obsidian recognizes it on first open.

4. Store the chosen path in a variable conceptually called `<vault_path>`.

## §2 — Preset selection

Currently only `karpathy-lite` ships in v0.1.0. Tell the user:

```
Preset: karpathy-lite (the only preset shipped in v0.1.0).
PARA preset is a planned future option.
```

No question to ask.

## §3 — Auto-capture mode

Ask:

```
Auto-capture mode? Controls how aggressive Claude is about auto-staging.
  (a) aggressive — auto-stage every detected pattern.
  (b) balanced  — auto-stage queries/scratch; offer for decisions/insights. (default)
  (c) minimal   — no auto-stage; offers only at session end.
  (d) off       — slash commands and natural language only.
```

Store the answer as `<auto_capture_mode>`.

## §4 — Optional features

Ask each, one at a time:

1. `Enable a daily/ folder for daily notes? [y/N]` → `<daily_notes>`
2. `Stale-staging warning threshold in days? [default: 14]` → `<stale_days>`
3. `Enable _index.md auto-maintenance? [Y/n]` → `<index_auto_maintenance>`

## §5 — Plan & confirm

Show the user a complete plan:

```
Plan:

  Vault path:       <vault_path>
  Preset:           karpathy-lite
  Auto-capture:     <auto_capture_mode>
  Stale threshold:  <stale_days> days
  Index auto-maint: <index_auto_maintenance>
  Daily notes:      <daily_notes>

Will:
  - Create vault skeleton at <vault_path>/ (skipping any folder that exists).
  - Write <vault_path>/.claude-cortex/config.yaml.
  - Copy skills to ~/.claude/skills/claude-cortex/claude-cortex.md.
  - Copy 6 slash commands to ~/.claude/commands/.
  - Install SessionStart hook to ~/.claude/hooks/claude-cortex-session-start.sh.
  - Add SessionStart hook entry to ~/.claude/settings.json.
  - Append the cortex block to ~/.claude/CLAUDE.md (or create if missing).

Proceed? [y/N]
```

Wait for `y`. On anything else, bail with `Install cancelled.`.

## §6 — Apply

Execute in this order. After each block, report `✓ <what>`.

1. **Skeleton.** For each path in `presets/karpathy-lite/preset.yaml`'s
   `skeleton_folders:`, `mkdir -p <vault_path>/<folder>`. Then for each file
   in `presets/karpathy-lite/skeleton/`, copy to `<vault_path>/` only if the
   destination doesn't exist.

2. **Vault config.**

   ```bash
   mkdir -p <vault_path>/.claude-cortex
   ```

   Write `<vault_path>/.claude-cortex/config.yaml`:

   ```yaml
   preset: karpathy-lite
   version: 0.1.0
   vault_path: <vault_path>
   auto_capture_mode: <auto_capture_mode>
   stale_staging_days: <stale_days>
   index_auto_maintenance: <index_auto_maintenance>
   daily_notes: <daily_notes>
   installed_at: <ISO-8601 UTC now>
   ```

3. **Skill.**

   ```bash
   mkdir -p ~/.claude/skills/claude-cortex
   cp presets/karpathy-lite/skills/claude-cortex.md ~/.claude/skills/claude-cortex/
   ```

4. **Slash commands.**

   ```bash
   mkdir -p ~/.claude/commands
   cp presets/karpathy-lite/commands/*.md ~/.claude/commands/
   ```

   Six files: `save-insight.md`, `save-to-inbox.md`, `retro.md`,
   `resume-work.md`, `triage-inbox.md`, `refresh-index.md`.

5. **Hook script.**

   ```bash
   mkdir -p ~/.claude/hooks
   cp presets/karpathy-lite/hooks/session-start.sh \
     ~/.claude/hooks/claude-cortex-session-start.sh
   chmod +x ~/.claude/hooks/claude-cortex-session-start.sh
   ```

6. **`~/.claude/settings.json` hook entry.**

   Read the file. Find or create `hooks.SessionStart` array. Append:

   ```json
   {
     "hooks": [
       { "type": "command", "command": "/Users/<user>/.claude/hooks/claude-cortex-session-start.sh" }
     ]
   }
   ```

   Use `jq` to do this safely:

   ```bash
   tmp="$(mktemp)"
   jq --arg cmd "$HOME/.claude/hooks/claude-cortex-session-start.sh" \
     '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$cmd}]}])' \
     ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
   ```

   Show the diff before applying.

7. **CLAUDE.md block.** Render
   `presets/karpathy-lite/CLAUDE.md.tmpl` with these substitutions:

   - `{{VAULT_PATH}}` → `<vault_path>`
   - `{{AUTO_CAPTURE_MODE}}` → `<auto_capture_mode>`
   - `{{STALE_STAGING_DAYS}}` → `<stale_days>`
   - `{{INDEX_AUTO_MAINTENANCE}}` → `<index_auto_maintenance>`
   - `{{CORTEX_VERSION}}` → contents of `shared/version.txt`

   Then:

   - If `~/.claude/CLAUDE.md` exists and already has the cortex block: bail
     with `Cortex block already present. Use update.md (not yet shipped) or
     uninstall first.`
   - Else if exists: append the rendered block, wrapped in
     `<!-- claude-cortex:begin v1 -->` / `<!-- claude-cortex:end -->`.
   - Else: create the file with just the wrapped block.

   Show the diff.

## §7 — Verify

1. **Sanity-check the install:**

   ```bash
   test -f ~/.claude/CLAUDE.md && grep -q '<!-- claude-cortex:begin v1 -->' ~/.claude/CLAUDE.md
   test -f ~/.claude/skills/claude-cortex/claude-cortex.md
   test -f ~/.claude/commands/save-to-inbox.md
   test -x ~/.claude/hooks/claude-cortex-session-start.sh
   test -f <vault_path>/.claude-cortex/config.yaml
   test -f <vault_path>/_index.md
   ```

   Each must pass. If any fails, surface it.

2. **Smoke test:** stage a test note.

   - Create `<vault_path>/inbox/W-000000/` manually with a `notes.md`
     containing `frontmatter type: scratch, title: install smoke test`.
   - Verify `inbox/_index.md` and `inbox/W-000000/_index.md` exist after.
   - Then delete `inbox/W-000000/` (this is just smoke; it should not
     pollute the vault).

3. **Report success:**

   ```
   ✓ Claude Cortex v0.1.0 installed.

   Try:
     - Mention W-XXXXXX in a session — Cortex sets it as the active work item.
     - Run /save-to-inbox in a Claude Code session to stage a note.
     - Run /retro <W-ID> to synthesize and dispatch staged notes.

   Vault:    <vault_path>
   Config:   <vault_path>/.claude-cortex/config.yaml
   Rules:    ~/.claude/CLAUDE.md (between cortex delimiters)

   Restart Claude Code or open a new session for the SessionStart hook to fire.

   See docs/troubleshooting.md if something looks off.
   ```

## §8 — Errors

- **Anywhere a step fails:** stop; report the failing step; tell the user
  what state the system is in (which steps succeeded, which didn't).
- **Do not auto-rollback.** A partial install is recoverable; auto-undo is
  more dangerous. Tell the user to either fix the issue and re-run, or to
  manually clean up the listed paths.
````

- [ ] **Step 2: Commit**

```bash
git add install.md
git commit -m "feat: add install.md installer for Claude Cortex v0.1.0"
```

---

## Task 16: Author `uninstall.md` stub

**Why:** Users won't paste an installer they can't reverse. The stub is a real, working uninstaller — it removes everything Cortex put down, and asks separately about the vault. Even though we're not shipping `update.md` in v1, `uninstall.md` is essential.

**Files:**
- Create: `uninstall.md`

- [ ] **Step 1: Write the uninstaller**

````markdown
# Claude Cortex Uninstaller

You are Claude Code, executing the Claude Cortex uninstaller. Reverse the
install while preserving the user's vault data.

## Posture

Show every action before taking it. Uninstalls feel safer when the user sees
exactly what's about to disappear.

## §1 — Locate the install

1. Look for `~/.claude/CLAUDE.md` and grep for the cortex delimiter:

   ```bash
   grep -F '<!-- claude-cortex:begin v1 -->' ~/.claude/CLAUDE.md
   ```

   - If not found: ask the user: "No cortex block in ~/.claude/CLAUDE.md.
     Continue anyway and remove cortex skills/commands/hook?" Default no.

2. Read the vault path from the cortex block (the `Path:` line under
   `## Vault location`). Save as `<vault_path>`.

   - If unparseable: ask the user for the vault path manually.

3. Check `<vault_path>/.claude-cortex/config.yaml` exists and matches.

## §2 — Confirm

Show the user the plan:

```
Will remove:
  - <!-- claude-cortex:begin v1 --> ... <!-- claude-cortex:end --> block
    from ~/.claude/CLAUDE.md
  - ~/.claude/skills/claude-cortex/
  - ~/.claude/commands/{save-insight,save-to-inbox,retro,resume-work,triage-inbox,refresh-index}.md
  - ~/.claude/hooks/claude-cortex-session-start.sh
  - SessionStart hook entry from ~/.claude/settings.json
  - <vault_path>/.claude-cortex/

Will NOT touch (asked separately):
  - <vault_path>/inbox/
  - <vault_path>/inbox/.archive/
  - <vault_path>/retros/
  - <vault_path>/insights/
  - <vault_path>/projects/
  - <vault_path>/people/
  - <vault_path>/references/
  - any other vault content

Proceed with the removals above? [y/N]
```

## §3 — Apply

1. **Remove the block.** Use the same delimiter-aware procedure as the
   installer's append:

   ```bash
   awk -v b='<!-- claude-cortex:begin v1 -->' \
       -v e='<!-- claude-cortex:end -->' '
     BEGIN { in_block = 0 }
     !in_block && index($0, b) { in_block = 1; next }
     in_block && index($0, e) { in_block = 0; getline; if ($0 != "") print; next }
     !in_block { print }
   ' ~/.claude/CLAUDE.md > /tmp/CLAUDE.md.new && \
     mv /tmp/CLAUDE.md.new ~/.claude/CLAUDE.md
   ```

   Show diff before the move.

2. **Remove skills.** `rm -rf ~/.claude/skills/claude-cortex/`

3. **Remove slash commands.** Filter by frontmatter `source: claude-cortex`:

   ```bash
   for f in ~/.claude/commands/*.md; do
     if head -10 "$f" | grep -q '^source: claude-cortex$'; then
       rm "$f"
     fi
   done
   ```

4. **Remove hook script.** `rm -f ~/.claude/hooks/claude-cortex-session-start.sh`

5. **Remove the SessionStart hook entry from settings.json:**

   ```bash
   tmp="$(mktemp)"
   jq --arg cmd "$HOME/.claude/hooks/claude-cortex-session-start.sh" \
     '.hooks.SessionStart |= map(select(.hooks[0].command != $cmd))' \
     ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
   ```

   Show diff.

6. **Remove vault metadata:** `rm -rf <vault_path>/.claude-cortex/`

## §4 — Vault content (separate prompt)

Ask:

```
Cortex itself has been uninstalled. What about the vault content?

  (a) Keep everything in <vault_path>/ exactly as it is. (default)
  (b) Remove only the inbox archive at <vault_path>/inbox/.archive/.
  (c) Remove the entire vault folder at <vault_path>/.

Choose (a/b/c):
```

On `a`: do nothing — report `Vault preserved.`
On `b`: `rm -rf <vault_path>/inbox/.archive/` (after showing what's inside).
On `c`: `rm -rf <vault_path>/` (after explicit second `Are you sure? Type the absolute path:`).

## §5 — Done

```
✓ Claude Cortex uninstalled.

The system has been removed from ~/.claude/. Restart Claude Code (or open a
new session) for changes to take effect.

If you change your mind, reinstall by pasting the README prompt from
https://github.com/orkeren21/claude-cortex.
```
````

- [ ] **Step 2: Commit**

```bash
git add uninstall.md
git commit -m "feat: add uninstall.md (clean reversal, vault content preserved by default)"
```

---

## Task 17: Author the README

**Why:** First impression. The paste-prompt is the single CTA; everything else is supporting.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read the existing README**

```bash
cat README.md
```

The current content is a single description line. We're replacing.

- [ ] **Step 2: Rewrite the README**

```markdown
# Claude Cortex

An Obsidian-backed second brain for Claude Code — auto-routed retros, insights, and project notes with a paste-and-run installer.

Inspired by [Andrej Karpathy's locally-curated Obsidian-vault practice](https://x.com/karpathy), with the productization twist of letting Claude Code stage notes mid-flight, synthesize them into well-organized destinations at retro time, and remember which sessions touched what so you can resume after a break.

## What you get

- A vault folder structure tuned for engineers managing many parallel projects.
- Six slash commands: `/save-to-inbox`, `/save-insight`, `/retro`, `/resume-work`, `/triage-inbox`, `/refresh-index`.
- Auto-capture: Claude detects working queries, decisions, and gotchas and stages them with a one-line announcement.
- Stale-staging detection: forgotten work items get surfaced after a sprint.
- Session tracking: every staging folder remembers which Claude Code sessions contributed to it, so post-vacation resume is instant.
- Cleanly delimited additions to `~/.claude/CLAUDE.md` — uninstall removes them without touching anything else.

## Install (macOS only in v0.1.0)

Open Claude Code in any directory and paste this prompt:

> Read the install.md from
> https://raw.githubusercontent.com/orkeren21/claude-cortex/main/install.md
> and follow it step by step. It will guide me through choosing a vault
> location, picking an auto-capture mode, and setting up the second-brain
> system.

Claude will:
1. Check Obsidian.app is installed (offer Homebrew install if not).
2. Find your existing Obsidian vault, or offer to create one.
3. Ask which auto-capture mode (`aggressive` / `balanced` / `minimal` / `off`).
4. Lay down the vault skeleton, skills, commands, hook, and CLAUDE.md block.
5. Smoke-test the install.

Estimated time: 2-3 minutes.

## Uninstall

Open Claude Code and paste:

> Read the uninstall.md from
> https://raw.githubusercontent.com/orkeren21/claude-cortex/main/uninstall.md
> and follow it. It will remove the cortex block, skills, commands, hook,
> and ask separately what to do with my vault content.

Vault content is preserved by default — your notes are yours.

## Configuration

Settings live in two places:
- `~/.claude/CLAUDE.md` — runtime contract loaded into every Claude Code session, between `<!-- claude-cortex:begin v1 -->` delimiters.
- `<vault>/.claude-cortex/config.yaml` — persistent install metadata (preset, version, vault_path, settings).

Edit either file directly to change settings. The CLAUDE.md block is the runtime source of truth; the YAML config is the install record.

## How it works

See [docs/specs/2026-05-12-second-brain-design.md](docs/specs/2026-05-12-second-brain-design.md) for the full design.

The short version:
- Claude reads the vault freely as ambient context.
- During work, Claude auto-stages notes into `inbox/<W-ID>/` (announced in one line).
- At retro time (`/retro <W-ID>`), Claude synthesizes a retro and dispatches staged notes to durable destinations (`projects/`, `insights/`, `decisions/`, etc.).
- Vault notes carry YAML frontmatter with `type:`, `title:`, `source_session:`, etc. The `type:` field drives all routing.
- Every folder has a `_index.md` so Claude (and you) can scan the contents without opening every file.

## Status

**v0.1.0 — early.** The system works end-to-end on macOS, but you're an early user. Bugs and rough edges are expected. Issues and PRs welcome at https://github.com/orkeren21/claude-cortex.

## License

MIT. See [LICENSE](LICENSE).
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: replace placeholder README with full v0.1.0 landing page"
```

---

## Task 18: Author `docs/troubleshooting.md`

**Why:** Recovery guide for the common failure modes.

**Files:**
- Create: `docs/troubleshooting.md`

- [ ] **Step 1: Write the troubleshooting doc**

````markdown
# Troubleshooting

Common issues, in rough order of likelihood.

## Install issues

### "Obsidian.app not found"

The installer looks for `/Applications/Obsidian.app`. If you have it
elsewhere (e.g. installed by another package manager into `/opt/homebrew/`),
either symlink it or install it via Homebrew:

```bash
brew install --cask obsidian
```

### "~/.claude not found"

Claude Code hasn't been run on this machine yet. Run `claude` once to
initialize, then re-run the installer.

### "Cortex block already present"

You're trying to install on top of an existing install. v0.1.0 doesn't ship
an `update.md`. Workaround: run `uninstall.md`, then re-run `install.md`.
Vault content is preserved across this.

### "jq: command not found" during install

The installer uses `jq` to edit `~/.claude/settings.json` safely. Install:

```bash
brew install jq
```

## Runtime issues

### Slash commands "not found"

Restart Claude Code or open a new session. Slash commands are loaded at
session start.

### `source_session:` shows `unknown`

The SessionStart hook didn't fire, or it fired but the marker file is
missing. Check:

```bash
ls -la ~/.claude/hooks/claude-cortex-session-start.sh
ls ~/.claude/session-env/
```

If the hook isn't registered in `~/.claude/settings.json`, add it manually
or re-run the installer from §6 step 6 onwards.

### Auto-stage isn't happening

1. Check your auto-capture mode. Open `~/.claude/CLAUDE.md`, find the cortex
   block, and look at the `Auto-capture mode:` line. `off` and `minimal`
   suppress auto-staging.
2. The heuristics are pattern-based and conservative. Try the explicit
   `/save-to-inbox` first to verify the install works, then loosen the mode.

### Stale-staging warning fires every session

The "Defer" option in `/triage-inbox` should bump `last_touched`. If it
isn't: open the relevant `inbox/<W-ID>/sessions.yaml` and update the
`last_touched:` field manually to today's UTC timestamp.

### A retro went sideways and I want to undo

The `/retro` flow archives the staging folder rather than deleting it. To
restore:

```bash
mv <vault>/inbox/.archive/W-XXXXXX <vault>/inbox/W-XXXXXX
```

The promoted/extracted notes that the retro wrote are still in their durable
destinations — delete them manually if you want a clean restart, then
re-run `/retro <W-ID>`.

## Vault issues

### Obsidian sync conflicts

Cortex doesn't resolve sync conflicts between Obsidian and any cloud sync
(iCloud, Dropbox, Obsidian Sync). Resolve via Obsidian's UI or the cloud
provider's interface, then re-run `/refresh-index` on any affected folders.

### Manual file moves break `_index.md`

Run `/refresh-index <folder>` to regenerate the index from the actual
contents.

## Reporting other issues

Open an issue at https://github.com/orkeren21/claude-cortex with:
- macOS version (`sw_vers`)
- Claude Code version (`claude --version`)
- Cortex version (`cat <vault>/.claude-cortex/config.yaml | grep version`)
- Steps to reproduce
````

- [ ] **Step 2: Commit**

```bash
git add docs/troubleshooting.md
git commit -m "docs: add troubleshooting guide"
```

---

## Task 19: End-to-end smoke test

**Why:** Verify the full install flow works against a throwaway vault before tagging a release. This is the test that catches "the docs say X but the installer does Y" drift.

**Files:**
- Create: `tests/smoke/run-smoke.sh`
- Create: `tests/smoke/README.md`

This is a manual smoke test (the installer is interactive — Claude reads it). The script provisions and tears down a sandbox.

- [ ] **Step 1: Write the smoke test scaffolding**

Create `tests/smoke/README.md`:

```markdown
# Smoke test

Manual end-to-end verification. The installer is interactive (Claude reads it),
so this can't be fully automated, but the scaffolding here provisions a clean
sandbox.

## Run

```bash
bash tests/smoke/run-smoke.sh provision
```

This creates:
- `tests/smoke/.sandbox/HOME/` — fake home dir
- `tests/smoke/.sandbox/HOME/.claude/` — fake Claude config
- `tests/smoke/.sandbox/HOME/Documents/Obsidian/Test/` — fake vault

Then in a separate terminal, set:

```bash
export HOME=/full/path/to/tests/smoke/.sandbox/HOME
cd $HOME/Documents/Obsidian/Test
claude
```

Paste the install prompt from the README, run through the installer.

After install, verify with:

```bash
bash tests/smoke/run-smoke.sh verify
```

Tear down:

```bash
bash tests/smoke/run-smoke.sh teardown
```
```

Create `tests/smoke/run-smoke.sh`:

```bash
#!/usr/bin/env bash
# tests/smoke/run-smoke.sh
# Provision/verify/teardown a sandbox for end-to-end smoke testing.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SANDBOX="$REPO_ROOT/tests/smoke/.sandbox"
FAKE_HOME="$SANDBOX/HOME"
VAULT="$FAKE_HOME/Documents/Obsidian/Test"

case "${1:-}" in
  provision)
    rm -rf "$SANDBOX"
    mkdir -p "$FAKE_HOME/.claude/skills" "$FAKE_HOME/.claude/commands" \
             "$FAKE_HOME/.claude/hooks" "$VAULT/.obsidian"
    printf '{}\n' > "$FAKE_HOME/.claude/settings.json"
    printf '{}\n' > "$VAULT/.obsidian/app.json"
    echo "Sandbox at: $SANDBOX"
    echo "Set HOME=$FAKE_HOME and run claude in $VAULT to install."
    ;;
  verify)
    fail=0
    check() {
      if eval "$2"; then
        printf '✓ %s\n' "$1"
      else
        printf '✗ %s\n' "$1"
        fail=1
      fi
    }
    check "CLAUDE.md cortex block present" \
      "grep -qF '<!-- claude-cortex:begin v1 -->' '$FAKE_HOME/.claude/CLAUDE.md'"
    check "skill installed" \
      "test -f '$FAKE_HOME/.claude/skills/claude-cortex/claude-cortex.md'"
    check "/save-to-inbox installed" \
      "test -f '$FAKE_HOME/.claude/commands/save-to-inbox.md'"
    check "/retro installed" \
      "test -f '$FAKE_HOME/.claude/commands/retro.md'"
    check "hook installed" \
      "test -x '$FAKE_HOME/.claude/hooks/claude-cortex-session-start.sh'"
    check "settings.json has SessionStart hook" \
      "jq -e '.hooks.SessionStart[].hooks[].command' '$FAKE_HOME/.claude/settings.json' | grep -q claude-cortex"
    check "vault skeleton present" \
      "test -f '$VAULT/_index.md' && test -d '$VAULT/inbox' && test -d '$VAULT/projects'"
    check "vault config present" \
      "test -f '$VAULT/.claude-cortex/config.yaml'"
    check "vault config has karpathy-lite preset" \
      "grep -q '^preset: karpathy-lite$' '$VAULT/.claude-cortex/config.yaml'"
    check "vault config has version" \
      "grep -q '^version: 0.1.0$' '$VAULT/.claude-cortex/config.yaml'"
    if [ $fail -eq 0 ]; then
      echo
      echo "All smoke checks passed."
    else
      echo
      echo "Some checks failed. Investigate."
      exit 1
    fi
    ;;
  teardown)
    rm -rf "$SANDBOX"
    echo "Sandbox removed."
    ;;
  *)
    echo "Usage: $0 {provision|verify|teardown}"
    exit 1
    ;;
esac
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x tests/smoke/run-smoke.sh
```

- [ ] **Step 3: Provision the sandbox**

```bash
bash tests/smoke/run-smoke.sh provision
```

Expected: prints the sandbox path and instructions.

- [ ] **Step 4: Run the install in the sandbox**

In a separate terminal, with the prompt that mirrors the README CTA:

```bash
export HOME="$(pwd)/tests/smoke/.sandbox/HOME"
cd "$HOME/Documents/Obsidian/Test"
claude
```

Paste this into the Claude session:

```
Read the install.md from <repo-root>/install.md and follow it step by step.
For testing: use this directory as the vault, accept all defaults, mode=balanced.
```

Step through the installer to completion.

- [ ] **Step 5: Run the verify**

```bash
bash tests/smoke/run-smoke.sh verify
```

Expected: every check passes.

- [ ] **Step 6: Manual feature test in the sandbox**

Still in the sandboxed Claude session, run:

```
W-999000 — building a smoke-test bulk action.

Now save this to the inbox: "Test note: the smoke test reached this point."
```

Verify Claude announces a stage. Then:

```bash
ls "$HOME/Documents/Obsidian/Test/inbox/W-999000/"
```

Expected: `sessions.yaml`, `_index.md`, and one `.md` staged note.

- [ ] **Step 7: Tear down**

```bash
bash tests/smoke/run-smoke.sh teardown
```

- [ ] **Step 8: Commit**

```bash
git add tests/smoke/
git commit -m "test: add e2e smoke test scaffolding (manual install + scripted verify)"
```

---

## Task 20: Tag and push v0.1.0

**Why:** Ship it. The release tag is what the README's paste-prompt references via the `main` branch, but a tag lets future versions exist.

**Files:**
- (None — this is git work.)

- [ ] **Step 1: Verify the working tree is clean**

```bash
git status
```

Expected: `nothing to commit, working tree clean`.

- [ ] **Step 2: Verify all bats tests pass**

```bash
bats tests/test_installer_helpers.bats
bats tests/test_session_start_hook.bats
```

Expected: all green.

- [ ] **Step 3: Verify the smoke test passes (one more time, clean)**

```bash
bash tests/smoke/run-smoke.sh provision
# (run install in sandbox)
bash tests/smoke/run-smoke.sh verify
bash tests/smoke/run-smoke.sh teardown
```

- [ ] **Step 4: Tag**

```bash
git tag -a v0.1.0 -m "Claude Cortex v0.1.0

Initial release.

- Karpathy-lite preset (default and only preset in v0.1.0).
- macOS-only paste-and-run installer.
- Six slash commands: /save-to-inbox, /save-insight, /retro,
  /resume-work, /triage-inbox, /refresh-index.
- SessionStart hook for session-id capture.
- Delimited CLAUDE.md block (clean install/uninstall).
- Uninstaller preserves vault content by default.

PARA preset, update.md, and a Linux installer are planned for future
releases."
```

- [ ] **Step 5: Push (with confirmation)**

Stop and ask the user:

```
Ready to push branch and tag to origin?
  - main: <N> commits ahead of origin
  - v0.1.0 tag

Push? [y/N]
```

On `y`:

```bash
git push origin main
git push origin v0.1.0
```

- [ ] **Step 6: Verify the release on GitHub**

```bash
gh release view v0.1.0 || echo "No release object — tag only. Optional next step: gh release create v0.1.0 --notes-from-tag"
```

(A formal release object is optional. The tag is enough for the README paste-prompt to work, since it pulls from `main`.)

---

## Self-Review

I read this plan against the spec. Findings:

**Spec coverage:**

| Spec section | Plan task |
|---|---|
| §4 Architecture | Tasks 5, 6, 7, 8, 15 |
| §5 Vault Taxonomy (karpathy-lite) | Task 7 |
| §5 PARA preset | OUT OF SCOPE for v1 (documented in plan header) |
| §6 Frontmatter Schema | Task 8 (skill) + Task 6 (CLAUDE.md ref) |
| §7 `_index.md` Convention | Tasks 7, 8, 14 |
| §8 Slash Commands | Tasks 9-14 (one each) |
| §9 Triggers / Auto-capture | Task 6 (CLAUDE.md heuristics + mode) |
| §10 Session Tracking | Tasks 3, 4, 8 (procedure in skill) |
| §11 CLAUDE.md Block | Tasks 6, 15 (template + render) |
| §12 Distribution Repo Layout | Tasks 5-18 (the whole repo) |
| §13.1 Credentials | Task 6 (CLAUDE.md), Task 8 (skill § Credentials Rule) |
| §13.2 Data Preservation | Tasks 11, 13, 16 (archive-not-delete; --purge gates) |
| §13.3 CLAUDE.md merge safety | Task 2 (helper functions), Task 15 (installer) |
| §13.4 Concurrent sessions race | Task 8 (§ Pitfalls — re-read-before-write) |
| §14 Out of Scope | Honored (PARA, Linux, embeddings, multi-vault, plugin, telemetry) |
| §15 Open Implementation Questions | Q1 session-id → Tasks 3, 4. Q2 race → Task 8 § Pitfalls. Q3 heuristic precision → ships in v1, tuned later. Q4 retro UI → Task 11 + Task 8. Q5 .obsidian preservation → Task 7/15 (skip-if-exists). Q6 multi-project → Task 8 § Default Project Resolution + Q deferred to v1.x. Q7 default project → Task 8 § Default Project Resolution. |
| §16 Success Criteria | Task 19 smoke test verifies install in <5min and end-to-end staging works. |

**Placeholder scan:** No `TBD`, `TODO`, `implement later`, `add appropriate error handling`, "similar to Task N", or empty steps. Every code block contains literal content.

**Type/name consistency:**
- `cortex_yaml_get` / `cortex_yaml_set` / `cortex_claude_md_*` / `cortex_render_template` / `cortex_log` — used consistently across Task 2 (define), Task 15 (consume).
- `~/.claude/skills/claude-cortex/claude-cortex.md` — same path everywhere (Tasks 6, 8, 15, 16, 18).
- `~/.claude/hooks/claude-cortex-session-start.sh` — same path everywhere (Tasks 3, 15, 16).
- `<vault>/.claude-cortex/config.yaml` — same path everywhere (Tasks 5, 8, 15, 16).
- `<!-- claude-cortex:begin v1 -->` / `<!-- claude-cortex:end -->` — same delimiter everywhere (Tasks 2, 6, 15, 16).
- Routing table is identical in CLAUDE.md (Task 6) and skill (Task 8).
- `auto_capture_mode` values (`aggressive` / `balanced` / `minimal` / `off`) consistent across CLAUDE.md, installer prompts, and config.
- `query_kind` values consistent (`splunk | soql | sql | argus | graphql | curl | <other>`).
- `source_session` field name consistent with `sessions.yaml`'s `id:` field.

**Scope check:** PARA, update.md, and Linux installer are explicitly deferred. v1 produces a working, testable, releasable system on its own. ✓

No issues found that need fixing. Plan is ready.
