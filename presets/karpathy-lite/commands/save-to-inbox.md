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
