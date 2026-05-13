# Claude Cortex Uninstaller

You are Claude Code, executing the Claude Cortex uninstaller. Reverse the
install while preserving the user's vault data.

## Posture

Show every action before taking it. Uninstalls feel safer when the user sees
exactly what's about to disappear. The section 3 confirmation gate authorizes the
removals listed under "Will remove"; each removal still shows its diff or
target before applying.

## 0. Preflight

1. **OS check.**

   ```bash
   uname -s
   ```

   - If `Darwin`: continue. Otherwise print `Claude Cortex v0.1.0 supports macOS only. Aborting.` and stop.

2. **Claude Code config dir check.**

   ```bash
   test -d ~/.claude
   ```

   - If absent: print `~/.claude not found — nothing to uninstall.` and stop.

3. **`jq` check.**

   ```bash
   command -v jq >/dev/null
   ```

   - If found: continue.
   - If not: ask the user verbatim:

     ```
     jq is not installed. The uninstaller needs it to safely edit
     settings.json. Install it via Homebrew now? [Y/n]

     Without jq, the uninstaller cannot remove the SessionStart hook entry,
     and the uninstall will stop here.
     ```

     On yes: run `brew install jq`. On no: bail with `jq required to continue. Install it manually (https://jqlang.github.io/jq/), then re-run the uninstaller.`.

4. **Clone the cortex repo into a temp dir** so the helpers are available:

   ```bash
   CORTEX_REPO="$(mktemp -d)/claude-cortex"
   git clone --depth 1 https://github.com/orkeren21/claude-cortex "$CORTEX_REPO"
   source "$CORTEX_REPO/shared/installer-helpers.sh"
   ```

   The helpers contain `cortex_claude_md_has_block` and
   `cortex_claude_md_remove_block` which we use below.

## 1. Locate the install

1. Look for the cortex block in `~/.claude/CLAUDE.md`:

   ```bash
   if [ -f ~/.claude/CLAUDE.md ] && cortex_claude_md_has_block ~/.claude/CLAUDE.md; then
     echo "Cortex block found in ~/.claude/CLAUDE.md."
   else
     echo "No cortex block in ~/.claude/CLAUDE.md."
   fi
   ```

   - If absent: ask the user: "No cortex block in ~/.claude/CLAUDE.md.
     Continue anyway and remove cortex skills/commands/hook?" Default no.

2. **Read the vault path** from the cortex block (the `Path:` line under
   `## Vault location`):

   ```bash
   if [ -f ~/.claude/CLAUDE.md ]; then
     VAULT_PATH="$(awk '
       /<!-- claude-cortex:begin v1 -->/ { in_block = 1; next }
       /<!-- claude-cortex:end -->/ { in_block = 0; next }
       in_block && /^- Path:/ {
         # strip "- Path: `" prefix and trailing "`"
         sub(/^- Path:[[:space:]]*`/, "", $0)
         sub(/`[[:space:]]*$/, "", $0)
         print
         exit
       }
     ' ~/.claude/CLAUDE.md)"
   fi
   ```

   - If unparseable or empty: ask the user for the vault path manually.

3. Verify the recorded vault path matches `$VAULT_PATH/.claude-cortex/config.yaml`:

   ```bash
   if [ -f "$VAULT_PATH/.claude-cortex/config.yaml" ]; then
     recorded="$(cortex_yaml_get "$VAULT_PATH/.claude-cortex/config.yaml" vault_path)"
     if [ "$recorded" != "$VAULT_PATH" ]; then
       echo "Warning: vault_path in CLAUDE.md ($VAULT_PATH) does not match config.yaml ($recorded). Continuing with $VAULT_PATH."
     fi
   fi
   ```

## 2. Confirm

Show the user the plan:

```
Will remove:
  - <!-- claude-cortex:begin v1 --> ... <!-- claude-cortex:end --> block
    from ~/.claude/CLAUDE.md
  - ~/.claude/skills/claude-cortex/
  - ~/.claude/commands/{save-insight,save-to-inbox,retro,resume-work,triage-inbox,refresh-index}.md
  - ~/.claude/hooks/claude-cortex-session-start.sh
  - SessionStart hook entry from ~/.claude/settings.json (only the entry whose command points at our hook)
  - <vault_path>/.claude-cortex/

Will NOT touch:
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

Wait for `y`. On anything else, bail with `Uninstall cancelled.`.

## 3. Apply

Execute in this order. After each step, report `[ok] <what>`.

1. **Remove the cortex block from `~/.claude/CLAUDE.md`** using the helpers
   (which handle the EOF edge case correctly):

   ```bash
   if cortex_claude_md_has_block ~/.claude/CLAUDE.md; then
     # Show diff first.
     preview="$(mktemp)"
     cp ~/.claude/CLAUDE.md "$preview"
     cortex_claude_md_remove_block "$preview"
     diff -u ~/.claude/CLAUDE.md "$preview" || true
     # Wait for user confirmation, then:
     mv "$preview" ~/.claude/CLAUDE.md
   fi
   ```

   - If the file is now empty (no other content), it's still fine to leave —
     a zero-byte CLAUDE.md is valid. Don't delete it; the user may add their
     own content later.

2. **Remove the skill directory:**

   ```bash
   rm -rf ~/.claude/skills/claude-cortex/
   ```

3. **Remove cortex-owned slash commands.** Identify by frontmatter
   `source: claude-cortex`:

   ```bash
   for f in ~/.claude/commands/*.md; do
     [ -f "$f" ] || continue
     if head -10 "$f" | grep -q '^source: claude-cortex$'; then
       echo "  removing $f"
       rm "$f"
     fi
   done
   ```

   This is robust if a user has renamed our commands or added their own —
   it removes only files that explicitly mark themselves as ours.

4. **Remove the hook script:**

   ```bash
   rm -f ~/.claude/hooks/claude-cortex-session-start.sh
   ```

5. **Remove the SessionStart hook entry from `settings.json`** (only ours,
   not other people's hooks):

   ```bash
   if [ -f ~/.claude/settings.json ]; then
     cmd_path="$HOME/.claude/hooks/claude-cortex-session-start.sh"
     tmp="$(mktemp)"

     jq --arg cmd "$cmd_path" '
       # Normalize SessionStart to an array (in case Claude Code accepted
       # a single object form).
       if (.hooks.SessionStart // [] | type) == "array" then
         .hooks.SessionStart = (.hooks.SessionStart // []
           | map(
               .hooks |= (. // [] | map(select(.command != $cmd)))
             )
           | map(select((.hooks // []) | length > 0))
         )
       elif .hooks.SessionStart != null then
         # Single-object form: convert to filtered array.
         .hooks.SessionStart = [.hooks.SessionStart]
           | .hooks.SessionStart |= (
               map(.hooks |= (. // [] | map(select(.command != $cmd))))
               | map(select((.hooks // []) | length > 0))
             )
       else
         .
       end
     ' ~/.claude/settings.json > "$tmp"

     diff -u ~/.claude/settings.json "$tmp" || true
     # Wait for user confirmation, then:
     mv "$tmp" ~/.claude/settings.json
   fi
   ```

   This filter:
   - Normalizes single-object form to an array.
   - Removes only the entry whose command matches our hook path.
   - Removes any now-empty hook group.
   - Leaves all unrelated SessionStart entries intact.

6. **Remove the vault internal config dir** (this is metadata about the
   install, NOT vault content):

   ```bash
   rm -rf "$VAULT_PATH/.claude-cortex/"
   ```

## 4. Vault content

Claude Cortex is uninstalled. Your vault at `<vault_path>` is untouched.

If you'd like to clean up the staged-archive folder Cortex created at
`<vault_path>/inbox/.archive/`, you can remove it yourself. Cortex won't
touch anything inside your vault on uninstall.

## 5. Done

```
[ok] Claude Cortex uninstalled.

The system has been removed from ~/.claude/. Restart Claude Code (or open a
new session) for changes to take effect.

If you change your mind, reinstall by pasting the README prompt from
https://github.com/orkeren21/claude-cortex.
```
