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
