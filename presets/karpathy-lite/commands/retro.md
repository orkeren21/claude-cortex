---
description: "Synthesize and dispatch a staged inbox/<W-ID>/ folder -- promotes notes to durable destinations and writes a fresh retrospective"
argument-hint: "[W-ID]"
source: claude-cortex
---

You are running the `/retro` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: read the staged folder, propose a dispatch plan as a unified diff,
apply it atomically on approval, and report.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`,
   specifically the "Retro Synthesis" section. Follow it to the letter.

2. **Resolve the W-ID:**
   - If `$ARGUMENTS` is a W-ID, use it.
   - Else: list `inbox/W-*/` folders sorted by `last_touched` desc. If
     exactly one exists, pick it. Else: ask the user which.

3. **Execute the "Retro Synthesis" section, steps 1-5,** from the skill.

4. **Atomicity rule:** if any file write or `mv` fails partway through,
   restore: delete files written this run, `mv inbox/.archive/<W-ID>/
   inbox/<W-ID>/` if archived. Report the failure to the user.

## Constraints

- Never delete files. Archive only.
- The retro is a fresh synthesis -- do not just rename or copy a staged file.
- Save the dispatch plan as `inbox/.archive/<W-ID>/dispatch-plan.md` for
  auditability before doing the moves.
- Apply the "Credentials Rule" section to every promoted/extracted note.
