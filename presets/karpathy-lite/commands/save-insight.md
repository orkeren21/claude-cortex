---
description: "Save a single durable note (insight, architecture, decision, query, reference) — auto-routed by type"
argument-hint: "[type=insight|architecture|decision|query|reference] [title=...]"
source: claude-cortex
---

You are running the `/save-insight` slash command from Claude Cortex.

**Arguments received:** $ARGUMENTS

Goal: write one durable note to its routed destination, update the parent
folder's `_index.md`, and report the path.

## Steps

1. **Read the cortex skill at** `~/.claude/skills/claude-cortex/claude-cortex.md`.
   You need § Frontmatter Schema, § Routing Table, § Session ID,
   § Default Project Resolution, § `_index.md` Auto-Maintenance.

2. **Resolve `type`:**
   - If `$ARGUMENTS` includes `type=...`, use that.
   - Else: ask the user: "Type? (insight | architecture | decision | query | reference)"
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

   Apply? [y/edit/n]
   ```

8. **On approval, write the file and update parent `_index.md`** per the
   skill's § `_index.md` Auto-Maintenance.

9. **Report:**

   ```
   Saved → <abs path>
   ```

## Constraints

- One file per invocation. If the user wants to capture multiple things,
  invoke `/save-insight` again or use `/retro` for a batch.
- Apply § Credentials Rule before writing.
- If the destination already exists with the same slug, ask: append to
  existing, write with a different slug, or cancel.
