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
   specifically the "Resume Brief" section.

2. **Resolve the W-ID:**
   - If `$ARGUMENTS` is a W-ID, use it.
   - Else: list `inbox/W-*/` sorted by `last_touched` desc. Show the user
     the list with one-line summaries from each `sessions.yaml`. Ask which.

3. **Execute the "Resume Brief" section** from the skill.

## Constraints

- Read frontmatter, not full bodies. Bodies are large; the brief is short.
- The brief is the only response. Don't auto-act on the suggestions —
  wait for the user to pick.
- "Open questions" extracted from notes: scan for headings/bullets matching
  `## Open questions`, `## Questions`, or list items starting with `?`.
