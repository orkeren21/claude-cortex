# Claude Cortex

An Obsidian-backed second brain for Claude Code -- auto-routed retros, insights, and project notes with a paste-and-run installer.

Inspired by [Andrej Karpathy's locally-curated Obsidian-vault practice](https://x.com/karpathy), with the productization twist of letting Claude Code stage notes mid-flight, synthesize them into well-organized destinations at retro time, and remember which sessions touched what so you can resume after a break.

## What you get

- A vault folder structure tuned for engineers managing many parallel projects.
- Seven slash commands for explicit capture and review (see [Slash commands](#slash-commands) below).
- Quick capture: when Claude notices something worth keeping (a query that
  worked, a decision, a gotcha), it drops a quick note in the inbox and
  tells you in one line. You can always say "don't bother" and turn it down
  or off.
- Forgotten-work nudge: if you stop touching a work item for a while,
  Claude reminds you at the start of your next session so you can wrap it
  up or move on.
- Resume after a break: each work item remembers which past sessions touched
  it, so when you come back you can recap or rewind in one command.
- Cleanly delimited additions to `~/.claude/CLAUDE.md` -- uninstall removes them without touching anything else.

## Slash commands

| Command          | What it does                                            |
|------------------|---------------------------------------------------------|
| `/save-to-inbox` | Stage a quick note for the current work item.          |
| `/save-insight`  | Save a durable note (lesson, decision, query, etc.).   |
| `/retro <W-ID>`  | Wrap up a work item: file staged notes, write a retro. |
| `/resume-work`   | Catch you up on a work item you stepped away from.     |
| `/triage-inbox`  | Handle work items that have gone stale.                |
| `/refresh-index` | Rebuild a folder's contents listing.                   |
| `/cortex`        | Show this menu (in case you forget what's available).  |

You don't need to memorize these. Cortex offers them at the right
moments, and you can also just talk to Claude -- "save this", "retro
W-123456", "what was I working on?" all work.

## Install (macOS only in v0.1.0)

Open Claude Code in any directory and paste this prompt:

> Read the install.md from
> https://raw.githubusercontent.com/orkeren21/claude-cortex/main/install.md
> and follow it step by step. Ask me one question at a time, in plain
> English, and show me what's about to change before changing anything.
> It will take 2-3 minutes.

Claude will:
1. Check Obsidian.app is installed (offer Homebrew install if not).
2. Find your existing Obsidian vault, or offer to create one.
3. Ask how proactive Cortex should be about saving notes during work
   (aggressive / balanced / minimal / off).
4. Lay down the vault skeleton, skills, commands, hook, and CLAUDE.md block.
5. Smoke-test the install.

## Uninstall

Open Claude Code and paste:

> Read the uninstall.md from
> https://raw.githubusercontent.com/orkeren21/claude-cortex/main/uninstall.md
> and follow it. It won't touch anything inside my vault -- only the Cortex
> side (skill, commands, hook, and the CLAUDE.md block).

Your vault content stays exactly as it is -- Cortex never deletes anything inside it.

## Configuration

Settings live in two places:
- `~/.claude/CLAUDE.md` -- the rules Cortex follows in every Claude Code
  session. Cortex's section is bounded by `<!-- claude-cortex:begin v1 -->`
  / `<!-- claude-cortex:end -->` delimiters; the rest of your CLAUDE.md is
  untouched.
- `<vault>/.claude-cortex/config.yaml` -- a record of your install choices
  (vault path, save behavior, etc.) so the uninstaller and any future
  upgrade know what you picked.

Edit either file directly to change settings. The CLAUDE.md block is the runtime source of truth; the YAML config is the install record.

## How it works

The short version:
- Claude reads the vault freely as ambient context.
- During work, Claude auto-stages notes into `inbox/<W-ID>/` (announced in one line).
- At retro time (`/retro <W-ID>`), Claude synthesizes a retro and dispatches staged notes to durable destinations (`projects/`, `insights/`, `decisions/`, etc.).
- Each note Claude writes carries a small YAML header (`type:`, `title:`,
  `source_session:`, etc.). The `type:` field is what tells Cortex where
  to file the note when you `/retro`.
- Each folder has a `_index.md` -- a one-page table of contents Claude
  reads first so it can find what's relevant without opening every file.

## Status

**v0.1.0 -- macOS only.** The install flow, capture flows, retro
synthesis, and uninstall are all working end-to-end. Issues and PRs
welcome at https://github.com/orkeren21/claude-cortex.

Your vault is yours: Cortex never deletes files inside it, and uninstall
removes only the Cortex side (skill, commands, hook, the CLAUDE.md block).

## License

MIT. See [LICENSE](LICENSE).
