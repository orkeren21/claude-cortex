---
description: "Save a single durable note (insight, architecture, decision, query, reference) -- auto-routed by type"
argument-hint: "[type=insight|architecture|decision|query|reference] [title=...]"
source: claude-cortex
---

You are running the `/save-insight` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: write one durable note to its routed destination, update the parent
folder's `_index.md`, and report the path.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`.
   You need the "Frontmatter Schema", "Routing Table", "Session ID",
   "Default Project Resolution", and "`_index.md` Auto-Maintenance" sections.

2. **Resolve `type`:**
   - If `$ARGUMENTS` includes `type=...`, use that.
   - Else: ask the user verbatim:

     ```
     What kind of note is this?
       1. insight       (a lesson that applies beyond one project)
       2. architecture  (how a system is structured, for one project)
       3. decision      (a choice and the reasoning, for one project)
       4. query         (a working query worth saving, for one project)
       5. reference     (something distilled from external reading)
     Pick a number, or type the name.
     ```

   - Validate against the routing table. If invalid, ask again.

3. **Determine what to save:** if there's clear context from the conversation
   for what the user wants captured, use it. Otherwise, ask.

4. **Resolve type-specific fields per the schema:**
   - For `insight`: `topic` (subfolder under `insights/`).
   - For `architecture` / `decision` / `query`: `project`.
   - For `query`: also `query_kind` (splunk | soql | sql | argus | graphql | curl | other).
   - For `decision`: `status` (accepted by default).
   - For `person`: `role`, `team`, `expertise`.
   - For `reference`: `kind` (article | book | other).
   - Ask only for fields you can't derive from context.

5. **Compute the destination path** from the routing table.

6. **Compute the slug** from the title (kebab-case, ~6 words max).

7. **Show a preview to the user:**

   ```
   Will save:
     <abs path>

   ---
   <full file content with frontmatter>
   ---

   Apply this? [y]es, [n]o, or [e]dit to change something first.
   ```

8. **On approval, write the file and update parent `_index.md`** per the
   skill's "`_index.md` Auto-Maintenance" section.

9. **Report:**

   ```
   Saved: <abs path>
   ```

## Constraints

- One file per invocation. If the user wants to capture multiple things,
  invoke `/save-insight` again or use `/retro` for a batch.
- Apply the "Credentials Rule" section before writing.
- If the destination already exists with the same slug, ask: append to
  existing, write with a different slug, or cancel.
