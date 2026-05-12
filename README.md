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
