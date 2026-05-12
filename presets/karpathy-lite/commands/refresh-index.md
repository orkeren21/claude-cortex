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
