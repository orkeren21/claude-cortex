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

The single Plan-and-confirm gate in §5 authorizes the overall install, but
each individual write step in §6 still presents its diff before applying so
the user sees exactly what is changing on disk at each step.

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

4. **`jq` check.** macOS does not ship `jq`, and §6 needs it for safe
   `settings.json` edits.

   ```bash
   command -v jq >/dev/null
   ```

   - If found: continue.
   - If not: ask: "`jq` not found. Install via Homebrew? (required for safe
     settings.json edits)"
     - On yes: run `brew install jq`. If `brew` is missing, point them at
       https://brew.sh and bail.
     - On no: bail. The settings.json edit step requires `jq`.

5. **Clone the repo.** All subsequent paths in this installer are relative to
   a freshly-cloned copy of the repo. Clone it into a temp directory and
   export `CORTEX_REPO` so every later step can reference files by absolute
   path.

   ```bash
   CORTEX_REPO="$(mktemp -d)/claude-cortex"
   git clone --depth 1 https://github.com/orkeren21/claude-cortex "$CORTEX_REPO"
   ```

   From here on, paths like `presets/karpathy-lite/...` should be read as
   `"$CORTEX_REPO/presets/karpathy-lite/..."`.

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
   with `app.json`, `appearance.json`, `core-plugins.json` whose content is
   the literal `{}` (an empty JSON object) so Obsidian recognizes the vault
   on first open.

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

This confirmation authorizes the overall install. Per §Posture, each write
step in §6 still shows its diff before applying.

## §6 — Apply

**Source the installer helpers first.** They handle the subtle bits
(newline normalization, delimiter-safe block append, idempotent yaml
writes, regex-metachar handling, EOF-block bugs) that Task 2 already tested.
Re-deriving them inline at install time is exactly where bugs live.

```bash
source "$CORTEX_REPO/shared/installer-helpers.sh"
```

This exposes `cortex_render_template`, `cortex_claude_md_has_block`,
`cortex_claude_md_append_block`, `cortex_yaml_get`, `cortex_yaml_set`, and
`cortex_log`.

Execute the steps below in order. After each block, report `✓ <what>`.

1. **Skeleton.** For each path in
   `"$CORTEX_REPO/presets/karpathy-lite/preset.yaml"`'s `skeleton_folders:`,
   `mkdir -p <vault_path>/<folder>`. Then for each file in
   `"$CORTEX_REPO/presets/karpathy-lite/skeleton/"`, copy to `<vault_path>/`
   using non-destructive copy so existing user files are never clobbered:

   ```bash
   cp -n "$CORTEX_REPO/presets/karpathy-lite/skeleton/"<file> <vault_path>/<file>
   ```

   `cp -n` skips any destination that already exists. If something is
   skipped, log it so the user knows to inspect manually.

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

3. **Skill.** Copy non-destructively so a pre-existing user skill of the same
   name is not clobbered:

   ```bash
   mkdir -p ~/.claude/skills/claude-cortex
   src="$CORTEX_REPO/presets/karpathy-lite/skills/claude-cortex.md"
   dest=~/.claude/skills/claude-cortex/claude-cortex.md
   if [ -e "$dest" ]; then
     echo "  ! $dest exists; skipping. Inspect manually."
   else
     cp "$src" "$dest"
   fi
   ```

4. **Slash commands.** Six files: `save-insight.md`, `save-to-inbox.md`,
   `retro.md`, `resume-work.md`, `triage-inbox.md`, `refresh-index.md`. Copy
   each non-destructively so pre-existing user slash commands of the same
   name are never overwritten:

   ```bash
   mkdir -p ~/.claude/commands
   for f in "$CORTEX_REPO"/presets/karpathy-lite/commands/*.md; do
     base="$(basename "$f")"
     dest=~/.claude/commands/$base
     if [ -e "$dest" ]; then
       echo "  ! $dest exists; skipping. Inspect manually."
     else
       cp "$f" "$dest"
     fi
   done
   ```

5. **Hook script.**

   ```bash
   mkdir -p ~/.claude/hooks
   cp "$CORTEX_REPO/presets/karpathy-lite/hooks/session-start.sh" \
     ~/.claude/hooks/claude-cortex-session-start.sh
   chmod +x ~/.claude/hooks/claude-cortex-session-start.sh
   ```

6. **`~/.claude/settings.json` hook entry.**

   The goal: append a `SessionStart` hook that runs our script. This must be
   safe across three failure modes:

   - `~/.claude/settings.json` may not exist on a fresh Claude Code install.
   - `hooks.SessionStart` may be a single object (not an array) in some
     versions of Claude Code.
   - The user may re-run the installer; we must not duplicate the entry.

   ```bash
   # Ensure settings.json exists with at least an empty object.
   test -f ~/.claude/settings.json || echo '{}' > ~/.claude/settings.json

   cmd_path="$HOME/.claude/hooks/claude-cortex-session-start.sh"
   tmp="$(mktemp)"

   jq --arg cmd "$cmd_path" '
     # Normalize SessionStart to an array.
     .hooks.SessionStart = (
       if (.hooks.SessionStart // [] | type) == "array"
       then (.hooks.SessionStart // [])
       else [.hooks.SessionStart]
       end
     )
     # Add our hook only if not already present.
     | if any(.hooks.SessionStart[]?.hooks[]?; .command == $cmd)
       then .
       else .hooks.SessionStart += [{"hooks":[{"type":"command","command":$cmd}]}]
       end
   ' ~/.claude/settings.json > "$tmp"

   # Show diff and confirm BEFORE applying.
   diff -u ~/.claude/settings.json "$tmp" || true
   # Wait for user confirmation, then:
   mv "$tmp" ~/.claude/settings.json
   ```

   The `// []` + array-type check normalizes `null` and single-object shapes
   into an array. The `any(...; .command == $cmd)` predicate makes the edit
   idempotent — re-running the installer is a no-op if our hook is already
   registered. Show the diff to the user and wait for explicit confirmation
   before the `mv`.

7. **CLAUDE.md block.** Render the template and append it via the helpers.
   The helpers already handle the create-if-missing case, trailing-newline
   normalization, and delimiter wrapping that Task 2 tested.

   ```bash
   # Render the CLAUDE.md template into a tmp file.
   rendered="$(mktemp)"
   cortex_render_template "$CORTEX_REPO/presets/karpathy-lite/CLAUDE.md.tmpl" \
     VAULT_PATH="$VAULT_PATH" \
     AUTO_CAPTURE_MODE="$AUTO_CAPTURE_MODE" \
     STALE_STAGING_DAYS="$STALE_STAGING_DAYS" \
     INDEX_AUTO_MAINTENANCE="$INDEX_AUTO_MAINTENANCE" \
     CORTEX_VERSION="$(cat "$CORTEX_REPO/shared/version.txt")" \
     > "$rendered"

   # Bail if cortex block is already present.
   if cortex_claude_md_has_block ~/.claude/CLAUDE.md; then
     echo "Cortex block already present in ~/.claude/CLAUDE.md."
     echo "Use uninstall.md first, then re-run install."
     exit 1
   fi

   # Append the rendered block (handles file-doesn't-exist, trailing newlines,
   # delimiter wrapping). Show diff before applying.
   preview="$(mktemp)"
   cp ~/.claude/CLAUDE.md "$preview" 2>/dev/null || : > "$preview"
   cortex_claude_md_append_block "$preview" "$rendered"
   diff -u ~/.claude/CLAUDE.md "$preview" 2>/dev/null || cat "$preview"
   # Wait for user confirmation, then:
   mv "$preview" ~/.claude/CLAUDE.md
   ```

   `VAULT_PATH`, `AUTO_CAPTURE_MODE`, `STALE_STAGING_DAYS`, and
   `INDEX_AUTO_MAINTENANCE` are the values gathered in §1, §3, and §4.

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

2. **Hook smoke test.** Invoke the SessionStart hook directly with a synthetic
   session id and verify the per-session marker appears. This actually
   exercises the hook end-to-end, unlike a vault-side check that nothing in
   the install path creates.

   ```bash
   # Smoke test: invoke the hook directly with a synthetic session id.
   fake_id="00000000-0000-0000-0000-cortexsmoketest"
   echo "{\"session_id\":\"$fake_id\",\"hook_event_name\":\"SessionStart\"}" \
     | bash ~/.claude/hooks/claude-cortex-session-start.sh
   test -f ~/.claude/session-env/$fake_id/session-id.txt \
     && [ "$(cat ~/.claude/session-env/$fake_id/session-id.txt)" = "$fake_id" ] \
     && echo "Hook smoke test: OK" \
     || echo "Hook smoke test: FAILED"
   # Clean up:
   rm -rf ~/.claude/session-env/$fake_id
   ```

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
