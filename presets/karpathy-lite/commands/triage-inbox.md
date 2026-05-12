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
