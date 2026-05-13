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

## How this installer behaves

**Show every action before taking it.** Install is a privileged operation.
For every file you'll create/modify, present the path and the diff/content,
and wait for explicit confirmation before writing.

**Ask exactly one question per turn.** Do not batch questions across sections.
Do not present multiple prompts and ask the user to "reply with your picks".
Wait for the user's answer before asking the next question. This applies to
every prompt in sections 1, 3, and 4. The user-facing experience must be a
real conversation, one question at a time, in order.

**Use plain ASCII for terminal output.** Prefer `-` (hyphen) and `--`
(double hyphen) to em-dashes (`—`) and en-dashes (`–`) in any text you read
out to the user. Do not use box-drawing characters or smart quotes. Plain
ASCII renders consistently across every terminal.

## 0. Preflight

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
   - If no: print `~/.claude not found -- install Claude Code first.` and bail.

4. **`jq` check.** macOS does not ship `jq`, and section 6 needs it for safe
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

5. **Clone the repo (or use a local checkout).** All subsequent paths in this
   installer are relative to a copy of the repo. Two branches:

   **Detection.** If your current working directory has the marker file
   `presets/karpathy-lite/preset.yaml`, you're inside the repo already
   (contributor / smoke-tester case). Take the local-checkout branch.
   Otherwise take the clone branch.

   ```bash
   if [ -f "$(pwd)/presets/karpathy-lite/preset.yaml" ]; then
     # Local checkout: use the repo we're already in.
     CORTEX_REPO="$(pwd)"
   else
     # Fresh install: clone to a temp dir.
     CORTEX_REPO="$(mktemp -d)/claude-cortex"
     git clone --depth 1 https://github.com/orkeren21/claude-cortex "$CORTEX_REPO"
   fi
   ```

   From here on, paths like `presets/karpathy-lite/...` should be read as
   `"$CORTEX_REPO/presets/karpathy-lite/..."`.

## 1. Pick where Claude Cortex will live

This is the first user prompt. Ask it on its own; wait for the answer; then
move on to section 2.

1. Search common Obsidian vault paths:

   ```bash
   ls -d ~/Documents/Obsidian/*/.obsidian 2>/dev/null \
   ; ls -d ~/Obsidian/*/.obsidian 2>/dev/null \
   ; ls -d ~/vault/.obsidian 2>/dev/null
   ```

   Each `.obsidian` directory's parent is a vault candidate.

2. **If candidates found:** present them with the framing below. Send this as
   a single message and stop. Renumber the options so the existing vaults are
   1..N and "create a new one" is N+1. Show the absolute paths exactly as
   `find` returned them (do not abbreviate, do not redact):

   ```
   Where would you like Claude Cortex to live? This is the folder Cortex will
   read from and (in limited cases) write to during your work -- think of it
   as a notebook the assistant shares with you.

   I found these existing Obsidian vault(s) on this machine:
     1. /Users/<full-path>/Documents/Obsidian/WorkOS         (recommended)
     2. /Users/<full-path>/Documents/Obsidian/Personal
     3. Create a new vault at ~/Documents/Obsidian/Cortex
     4. Use a different folder (you'll provide the absolute path)

   Pick a number, or paste an absolute path to use that folder directly.
   ```

   - On a number: use the corresponding path. For "Create a new vault",
     `mkdir -p` the path and create a minimal `.obsidian/` dir with
     `app.json`, `appearance.json`, `core-plugins.json` whose content is the
     literal `{}` (an empty JSON object) so Obsidian recognizes the vault on
     first open. For "Use a different folder", ask: `Absolute path?` and wait
     for a single string.
   - On an absolute path that doesn't exist yet: confirm `Create <path>? [Y/n]`
     before `mkdir -p` and `.obsidian/` setup as above.
   - On an absolute path that exists but has no `.obsidian/`: warn
     `<path> doesn't look like an Obsidian vault. Initialize it as one? [Y/n]`
     before creating `.obsidian/`.

3. **If no candidates found:** send this as a single message and stop:

   ```
   Where would you like Claude Cortex to live? This is the folder Cortex will
   read from and (in limited cases) write to during your work -- think of it
   as a notebook the assistant shares with you.

   I couldn't find an existing Obsidian vault on this machine. Pick one:
     1. Create a new vault at ~/Documents/Obsidian/Cortex
     2. Use a different folder (you'll provide the absolute path)

   Pick a number, or paste an absolute path to use that folder directly.
   ```

4. Store the chosen path in a variable conceptually called `<vault_path>`.

**After the user answers section 1, proceed to section 2. Do not ask any other questions
until you have a vault path.**

## 2. Folder structure

This is the SECOND user prompt. Send the message below as a single
message and stop. Wait for the user's answer; then move on to section 3.

Cortex uses a folder structure inspired by Andrej Karpathy's locally-
curated Obsidian-vault practice -- folders by kind of artifact, so
routing decisions are mechanical. PARA and custom layouts are not
shipped in v0.1.0; if you'd like a different layout, you can rearrange
folders any time after install -- Cortex won't fight you.

Send this message verbatim:

```
Cortex will lay down the following folder structure inside your vault.
Folders by kind of artifact -- routing is mechanical and reliable.

  <vault>/
  |-- inbox/         -- temp staging for mid-flight notes (one folder per W-ID)
  |   `-- .archive/  -- where retro'd folders go
  |-- retros/        -- one write-up per work item, by project
  |-- insights/      -- cross-project lessons
  |   |-- debugging/
  |   |-- architecture/
  |   `-- tooling/
  |-- projects/      -- one subfolder per project
  |-- people/        -- collaborator notes, 1:1s
  `-- references/    -- distilled external reading
      |-- articles/
      `-- books/

  Existing files in your vault are never touched.

----------------------------------------
Looks good? [Y/n]
```

Default on empty input is `Y`. On Y/yes/empty: confirm in one line and
proceed to section 3:

```
[ok] Folder structure: Karpathy-lite.
```

On n/no: bail with `Install cancelled.`. Do not offer alternatives;
there are no alternatives in v0.1.0.

**After the user answers section 2, proceed to section 3.**

## 3. How proactive should Cortex be?

Ask the following as a single message and stop. Do not include section 4 questions in
the same message. Wait for the user's answer before continuing.

The "auto-capture mode" controls how aggressively Cortex saves notes for you
during work. "Auto-stage" means dropping a quick note into the inbox folder
without asking first (Cortex tells you when it does); "offer" means Cortex
asks you first before saving.

```
How proactive should Cortex be about saving notes during your work?

  1. Aggressive -- save every pattern Cortex detects (queries, decisions,
     gotchas) into the inbox folder. Most notes captured. Heaviest hand.
  2. Balanced   -- (recommended) save queries and quick scratch notes
     automatically, but ask first before saving anything more durable
     (decisions, lessons learned).
  3. Minimal    -- save nothing automatically. Cortex only offers to save
     a batch at the end of a long session.
  4. Off        -- save nothing automatically and do not offer. Notes are
     saved only when you explicitly use a slash command or ask Cortex to.

Pick one (1/2/3/4).
```

Accept `1`, `2`, `3`, `4` or the full word (`aggressive`, `balanced`, `minimal`,
`off`). On any other input, restate the options and ask again.

Store the answer as `<auto_capture_mode>`. Then proceed to section 4.

## 4. A few small choices

Two separate prompts. Ask each one as its own message, wait for the answer,
then ask the next. Do NOT batch them. Do NOT ask the user to "answer all of
the below". Each prompt should explain itself; don't assume the user knows
the jargon.

**4.1 -- "Stale" reminder threshold.** Send this
as a single message and stop:

```
After how many days should Cortex remind you about a forgotten work item?

When you start working on something tracked by a work-item ID (e.g. W-123456),
Cortex stages quick notes into inbox/W-123456/. If you stop touching that
folder for a while, Cortex flags it at session start with a one-line nudge
to either run /retro on it or clean it up.

The default is 14 days (one sprint). Pick a number of days, or press enter
for the default.

[default: 14]
```

Default on empty input is `14`. Accept any positive integer. Store as
`<stale_days>`.

**4.2 -- Auto-update the folder index files.** Only after 4.1 is answered,
send this as a single message and stop:

```
Should Cortex keep folder index files (_index.md) up to date automatically?

Each folder in your vault gets a small _index.md file that lists what's
inside it. Cortex reads these first before opening individual notes -- it's
how the assistant navigates your vault efficiently. If yes, Cortex will
update these index files for you whenever it adds a note. If no, you'd
update them manually (or run /refresh-index <folder> later).

[Y/n] (default: yes -- recommended)
```

Default on empty input is `Y`. Store as `<index_auto_maintenance>`.

After 4.2 is answered, proceed to section 5.

## 5. Plan & confirm

Show the user a complete plan. Use plain ASCII; explain each line briefly so
the user understands what they are confirming:

```
Here's the plan:

  Vault folder:        <vault_path>
  Folder structure:    Karpathy-lite
  Save behavior:       <auto_capture_mode>  (e.g. balanced, minimal, off)
  Stale reminder:      <stale_days> days
  Auto-update indexes: <index_auto_maintenance>

This will:
  - Set up the folder skeleton inside <vault_path>/ (skipping any folder
    that already exists, so existing notes are not touched).
  - Save your settings at <vault_path>/.claude-cortex/config.yaml.
  - Install the Cortex skill at ~/.claude/skills/claude-cortex/.
  - Install 7 slash commands at ~/.claude/commands/ (save-to-inbox,
    save-insight, retro, resume-work, triage-inbox, refresh-index,
    cortex).
  - Install a session-start hook at ~/.claude/hooks/.
  - Register the hook in ~/.claude/settings.json (only adding our entry --
    your other hooks are untouched).
  - Allow Cortex to read and write inside the vault folder without
    prompting for every operation. Adds 17 vault-scoped permissions
    entries to ~/.claude/settings.json (the same file we add the
    SessionStart hook to). You can remove them any time -- ask Claude
    to edit the file, or run the uninstaller.
  - Append the Cortex block to ~/.claude/CLAUDE.md (between dedicated
    delimiters; the rest of your CLAUDE.md is untouched). If CLAUDE.md
    doesn't exist yet, it will be created.

----------------------------------------
Continue? [Y/n]
See every diff before applying? [y/N]
```

Wait for the answer to `Continue?`. On `n`/`no`, bail with `Install
cancelled.`. On `y`/`yes`/empty: continue.

Then read the answer to `See every diff before applying?`. On `y`/`yes`,
set verbose mode ON. On `n`/`no`/empty (the default), set verbose mode
OFF.

In verbose mode (ON): every step in section 6 shows its diff and asks
`Continue? [Y/n]` before applying.

In quiet mode (OFF, the default): non-privileged steps (skeleton, vault
config, skill, slash commands, hook script) print one-line `[ok]`
summaries and proceed without a per-step gate. The three privileged
writes (the SessionStart hook entry in `~/.claude/settings.json`, the
permissions allowlist in `~/.claude/settings.json`, and the Cortex
block in `~/.claude/CLAUDE.md`) ALWAYS show their diff and ask
`Proceed? [y/N]`, regardless of verbose mode.

## 6. Apply

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

Execute the steps below in order. In quiet mode (the default), each
non-privileged step (1-5) prints `[ok] <what>` and proceeds. In verbose
mode, each non-privileged step also shows a diff/preview and asks
`Continue? [Y/n]` before applying. Steps 6, 6.5, and 7 (settings.json
hook entry, settings.json permissions allowlist, CLAUDE.md) are
privileged and ALWAYS show diff + ask `Proceed? [y/N]`, regardless of
mode.

1. **Skeleton.** Announce, then apply.

   In quiet mode (the default), only the announce block prints; the
   skeleton is created and a one-line `[ok]` summary follows. In
   verbose mode, after the announce block, ask `Continue? [Y/n]` and
   wait for the answer before creating folders.

   Announce:

   ```
   About to create the folder skeleton inside <vault_path>:
     - inbox/             (with .archive/ subfolder for retro'd work)
     - retros/
     - insights/          (debugging/, architecture/, tooling/)
     - projects/
     - people/
     - references/        (articles/, books/)

   I'll also drop a small _index.md into each of the top-level folders so
   I can scan it later without opening every file. If any of these already
   exist in your vault, I'll skip them and leave your existing notes alone.
   ```

   Then for each path in
   `"$CORTEX_REPO/presets/karpathy-lite/preset.yaml"`'s `skeleton_folders:`,
   `mkdir -p <vault_path>/<folder>`. Then for each file in
   `"$CORTEX_REPO/presets/karpathy-lite/skeleton/"`, copy to `<vault_path>/`
   using non-destructive copy so existing user files are never clobbered:

   ```bash
   cp -n "$CORTEX_REPO/presets/karpathy-lite/skeleton/"<file> <vault_path>/<file>
   ```

   `cp -n` skips any destination that already exists. If something is
   skipped, log it so the user knows to inspect manually.

   After: compute the list of pre-existing vault-root files (so the
   user knows Cortex saw them and chose to leave them alone):

   ```bash
   preexisting_root_files="$(
     find "$VAULT_PATH" -maxdepth 1 -type f \
       ! -name '_index.md' \
       ! -name '.*' \
       -exec basename {} \;
   )"
   # If empty, render the report as "none". Otherwise comma-separate.
   if [ -z "$preexisting_root_files" ]; then
     preexisting_summary="none"
   else
     preexisting_summary="$(echo "$preexisting_root_files" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')"
   fi
   ```

   Then report:

   ```
   [ok] Skeleton in place.
        Skipped (already existed): <list, or "none">.
        Pre-existing vault root files (left untouched): <preexisting_summary>.
   ```

   `find` is BSD-find compatible -- v0.1.0 is macOS-only.

2. **Vault config.** Announce, then apply.

   Quiet mode: announce + write + `[ok]`. Verbose mode: also show the
   YAML content that's about to be written and ask `Continue? [Y/n]`
   before writing.

   Announce:

   ```
   About to save your install settings to:
     <vault_path>/.claude-cortex/config.yaml

   This file records the choices you just made (preset, save behavior, stale
   threshold, etc.) so I can read them back later. Only Cortex looks at this
   file -- it doesn't affect Obsidian.
   ```

   Then run:

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
   installed_at: <ISO-8601 UTC now>
   ```

   After:

   ```
   [ok] Config written to <vault_path>/.claude-cortex/config.yaml.
   ```

3. **Skill.** Announce, then apply.

   Quiet mode: announce + copy + `[ok]`. Verbose mode: also note the
   source path and the destination path side-by-side and ask
   `Continue? [Y/n]` before copying.

   Announce:

   ```
   About to install the Cortex skill at:
     ~/.claude/skills/claude-cortex/claude-cortex.md

   What this skill is: the procedural manual I read whenever you run a
   Cortex slash command or I'm about to write into the vault. About 350
   lines covering frontmatter schema, routing rules, retro synthesis,
   session ID lookup, and the credentials-safety rule. Lives at the path
   above; doesn't run automatically -- I read it on demand.

   If a skill already exists at that path, I'll skip it and tell you so
   you can inspect manually.
   ```

   Then copy non-destructively so a pre-existing user skill of the same
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

   After:

   ```
   [ok] Skill installed.
   ```

   (Or, if the destination already existed: `[ok] Skill already present -- skipped.`)

4. **Slash commands.** Announce, then apply.

   Quiet mode: announce + copy loop + `[ok]`. Verbose mode: list the
   seven destination paths and ask `Continue? [Y/n]` before the loop
   runs.

   Announce:

   ```
   About to install 7 slash commands at ~/.claude/commands/:
     - save-to-inbox.md   -- stage a quick note for the active work item
     - save-insight.md    -- save a durable lesson
     - retro.md           -- wrap up a work item and file its notes
     - resume-work.md     -- catch you up on a work item you stepped away from
     - triage-inbox.md    -- handle work items that have gone stale
     - refresh-index.md   -- rebuild a folder's _index.md listing
     - cortex.md          -- show this menu in case you forget what's available

   If you already have a command of the same name, I'll skip that one and
   tell you, so your existing setup is never overwritten.
   ```

   Then copy each non-destructively so pre-existing user slash commands of
   the same name are never overwritten:

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

   After:

   ```
   [ok] Slash commands installed. Skipped: <list, or "none">.
   ```

5. **Hook script.** Announce, then apply.

   Quiet mode: announce + copy + chmod + `[ok]`. Verbose mode: also
   show the source path and ask `Continue? [Y/n]` before the copy.

   Announce:

   ```
   About to install the session-start hook at:
     ~/.claude/hooks/claude-cortex-session-start.sh

   This runs once when you start a Claude Code session. It records the
   session ID so I can later say "this note came from that session" --
   helpful when you come back to a work item days later. The next step
   (settings.json) is where I actually register the hook to run; this step
   just lays down the script.
   ```

   Then run:

   ```bash
   mkdir -p ~/.claude/hooks
   cp "$CORTEX_REPO/presets/karpathy-lite/hooks/session-start.sh" \
     ~/.claude/hooks/claude-cortex-session-start.sh
   chmod +x ~/.claude/hooks/claude-cortex-session-start.sh
   ```

   After:

   ```
   [ok] Hook script installed.
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

   # Stage:
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

   # Show:
   diff -u ~/.claude/settings.json "$tmp" || true

   # Gate: present the diff above to the user. Privileged write.
   # Prompt: Proceed? [y/N] (default no)
   # On y: continue to Apply.
   # On anything else: rm -f "$tmp" and bail with "Install cancelled."

   # Apply:
   mv "$tmp" ~/.claude/settings.json
   ```

   The `// []` + array-type check normalizes `null` and single-object shapes
   into an array. The `any(...; .command == $cmd)` predicate makes the edit
   idempotent — re-running the installer is a no-op if our hook is already
   registered. Show the diff to the user and wait for explicit confirmation
   before the `mv`.

6.5. **Vault permissions allowlist.** This is one of the three privileged
   writes -- diff always shown, regardless of verbose mode.

   The goal: add 17 vault-scoped allowlist entries to
   `~/.claude/settings.json` under `permissions.allow` so Cortex flows
   don't trigger a prompt for every read/write inside the vault.

   ```bash
   # Stage:
   # Strip any trailing slash so the glob is well-formed (path//** would
   # match nothing).
   VAULT_PATH="${VAULT_PATH%/}"
   tmp="$(mktemp)"
   jq --arg vault "$VAULT_PATH" '
     ($vault + "/**") as $glob
     | [
         "Read(" + $glob + ")",
         "Write(" + $glob + ")",
         "Edit(" + $glob + ")",
         "Bash(grep:" + $glob + ")",
         "Bash(find:" + $glob + ")",
         "Bash(cat:" + $glob + ")",
         "Bash(head:" + $glob + ")",
         "Bash(tail:" + $glob + ")",
         "Bash(wc:" + $glob + ")",
         "Bash(ls:" + $glob + ")",
         "Bash(awk:" + $glob + ")",
         "Bash(mkdir:" + $glob + ")",
         "Bash(mv:" + $glob + " " + $glob + ")",
         "Bash(cp:" + $glob + " " + $glob + ")",
         "Bash(touch:" + $glob + ")",
         "Bash(tee:" + $glob + ")",
         "Bash(sed:" + $glob + ")"
       ] as $cortex_entries
     | .permissions.allow = (
         ((.permissions.allow // []) + $cortex_entries) | unique
       )
   ' ~/.claude/settings.json > "$tmp"

   # Show:
   diff -u ~/.claude/settings.json "$tmp" || true

   # Gate: present the diff above to the user. Privileged write.
   # Prompt: Proceed? [y/N] (default no)
   # On y: continue to Apply.
   # On anything else: rm -f "$tmp" and bail with "Install cancelled."

   # Apply:
   mv "$tmp" ~/.claude/settings.json
   ```

   The `unique` filter makes the edit idempotent -- re-running the
   installer is a no-op if the entries are already present.

   Path B note: this allowlist deliberately omits `rm`, `rmdir`, and
   `unlink`. Cortex never deletes inside the vault; if a flow ever
   tries, the prompt fires and the user sees it.

   Known limitation: `Bash(find:<vault>/**)` permits `find <vault>/...
   -delete`, which mutates. Claude Code's allowlist matchers don't
   support flag-level granularity. Cortex's flows do not call
   `find -delete`; this is a documented limitation, not a workaround.

7. **CLAUDE.md block.** Render the template and append it via the helpers.
   The helpers already handle the create-if-missing case, trailing-newline
   normalization, and delimiter wrapping that Task 2 tested.

   Announce:

   ```
   About to append the Cortex block to ~/.claude/CLAUDE.md.

   What this block is: the runtime contract I follow in every Claude
   Code session -- read/write rules for the vault, auto-capture
   heuristics, the trigger table, the frontmatter requirement. About 90
   lines, wrapped between dedicated delimiters
   (<!-- claude-cortex:begin v1 --> ... <!-- claude-cortex:end -->) so
   the rest of your CLAUDE.md is untouched. Diff below.
   ```

   ```bash
   # Stage:
   rendered="$(mktemp)"
   cortex_render_template "$CORTEX_REPO/presets/karpathy-lite/CLAUDE.md.tmpl" \
     VAULT_PATH="$VAULT_PATH" \
     AUTO_CAPTURE_MODE="$AUTO_CAPTURE_MODE" \
     STALE_STAGING_DAYS="$STALE_STAGING_DAYS" \
     INDEX_AUTO_MAINTENANCE="$INDEX_AUTO_MAINTENANCE" \
     CORTEX_VERSION="$(cat "$CORTEX_REPO/shared/version.txt")" \
     > "$rendered"

   # Skip if cortex block is already present (idempotent re-run).
   if cortex_claude_md_has_block ~/.claude/CLAUDE.md; then
     echo "[ok] Cortex block already present in ~/.claude/CLAUDE.md -- skipping append."
   else
     preview="$(mktemp)"
     cp ~/.claude/CLAUDE.md "$preview" 2>/dev/null || : > "$preview"
     cortex_claude_md_append_block "$preview" "$rendered"

     # Show:
     diff -u ~/.claude/CLAUDE.md "$preview" 2>/dev/null || cat "$preview"

     # Gate: present the diff above. Privileged write.
     # Prompt: Proceed? [y/N] (default no)
     # On y: continue to Apply.
     # On anything else: rm -f "$preview" and bail with "Install cancelled."

     # Apply:
     mv "$preview" ~/.claude/CLAUDE.md
   fi
   ```

   `VAULT_PATH`, `AUTO_CAPTURE_MODE`, `STALE_STAGING_DAYS`, and
   `INDEX_AUTO_MAINTENANCE` are the values gathered in sections 1, 3, and 4.

## 7. Verify

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
   [ok] Claude Cortex v0.1.0 installed.

   You're set. Cortex will work naturally as you do -- staging notes when
   it notices something worth keeping, asking before saving anything
   durable, and reminding you about work items you've stepped away from.

   If you ever want to trigger something explicitly:
     /save-to-inbox     stage a quick note for the current work item
     /save-insight      save a durable lesson, decision, or query
     /retro <W-ID>      wrap up a work item and file its notes
     /resume-work       get caught up on a paused work item
     /triage-inbox      handle stale staging folders
     /refresh-index     rebuild a folder's contents listing
     /cortex            show this menu again

   Forget what's available? Type /cortex for the menu, or just ask me --
   "what cortex commands do I have?" works too.

   To get started, just work normally. Mention a work item by ID
   (W-XXXXXX) and Cortex will pick it up from there.

   Vault:    <vault_path>
   Config:   <vault_path>/.claude-cortex/config.yaml
   Rules:    ~/.claude/CLAUDE.md (between cortex delimiters)

   Restart Claude Code or open a new session for the SessionStart hook
   to fire.
   ```

## 8. Errors

If any check or apply step fails, stop and tell the user what happened in
plain English. Use this template (printed as plain text, not as a code
block, so it renders in Claude Code's chat):

    Install stopped at step <N>: <one-line description of failure>.

    What worked so far:
      - <step, step, ...>

    What didn't:
      - <failing step + the specific error in one sentence>

    To recover, you can:
      1. Re-run the install. The early steps (skeleton, config, skill,
         commands, hook script) skip anything already in place. The
         settings.json and CLAUDE.md edits also no-op if Cortex is already
         registered, so a re-run will pick up where it stopped.
      2. Or manually clean up: <list the exact files/dirs the partial
         install created, by absolute path>.

    Happy to walk through either path.

Specific common failures to handle gracefully:

- `/Applications/Obsidian.app` not found and user declined Homebrew: tell
  them where to download Obsidian (https://obsidian.md/download) and
  offer to resume after they install.
- `brew` not found: link https://brew.sh and stop. Don't try to install
  Homebrew implicitly.
- `~/.claude/settings.json` is invalid JSON: show the parse error and
  refuse to edit. Ask the user to fix it manually.
- Vault path doesn't exist and user declined to create it: ask once more
  for a different path.

Do not auto-rollback. A partial install is recoverable; auto-undo is more
dangerous.
