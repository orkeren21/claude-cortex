---
name: claude-cortex
description: Use when running any Claude Cortex slash command (/save-insight, /save-to-inbox, /retro, /resume-work, /triage-inbox, /refresh-index), when auto-staging into the vault, when synthesizing retrospectives, or when resolving routing/frontmatter questions for vault writes.
---

# Claude Cortex Skill

The full procedural manual for the Claude Cortex second-brain system. The
top-level contract lives in `~/.claude/CLAUDE.md`; this file is the depth.

## Quick Pointers

- Vault location and runtime config — `~/.claude/CLAUDE.md` (between
  `<!-- claude-cortex:begin v1 -->` delimiters)
- Persistent install metadata — `<vault>/.claude-cortex/config.yaml`
- Session id discovery — § Session ID below

## Frontmatter Schema (full)

### Universal fields (every Claude-written note)

```yaml
---
type: insight | retro | architecture | decision | query | person | reference | scratch
title: "<required, human-readable>"
created: 2026-05-12T11:30:00Z      # ISO-8601 UTC
updated: 2026-05-12T11:30:00Z      # ISO-8601 UTC
tags: [<free-form list>]
source_session: <session-id>       # see § Session ID
---
```

### Type-specific fields

```yaml
# type: retro
work_item: W-123456
project: agentforce-actions
duration_days: 4
related: [insights/debugging/splunk-pagination-gotcha.md]

# type: insight
topic: debugging                   # subfolder under insights/
applies_to: [agentforce-actions, udd-entity-builder]

# type: architecture
project: agentforce-actions
component: rate-limiter

# type: decision
project: agentforce-actions
status: accepted | superseded | proposed
supersedes: [decisions/2026-04-01-old.md]

# type: query
project: agentforce-actions
query_kind: splunk | soql | sql | argus | graphql | curl | <other-kebab-case>
used_in: [W-123456, W-123777]

# type: person
role: "Staff Engineer"
team: "Platform Foundations"
expertise: [auth, rate-limiting]
```

## Routing Table

| `type:` | Destination |
|---|---|
| `scratch` | `inbox/<W-ID>/<slug>.md` |
| `retro` | `retros/<project>/YYYY-MM-DD-<W-ID>-<slug>.md` |
| `insight` | `insights/<topic>/<slug>.md` |
| `architecture` | `projects/<project>/architecture/<slug>.md` |
| `decision` | `projects/<project>/decisions/YYYY-MM-DD-<slug>.md` |
| `query` | `projects/<project>/queries/<query_kind>/<slug>.md` |
| `person` | `people/<firstname>-<lastname>-<role-slug>.md` |
| `reference` | `references/<kind>/<slug>.md` |

Slug rules: kebab-case, lowercase, ~6 words max, descriptive.

## Session ID

Read the current session id via this procedure (in order):

1. If `CLAUDE_CORTEX_SESSION_ID` is set in the environment, use it.
2. Else: find the most-recent `~/.claude/session-env/*/session-id.txt` and
   read it. Use this Bash:

   ```bash
   find ~/.claude/session-env -name session-id.txt -type f -exec stat -f '%m %N' {} \; \
     | sort -rn | head -1 | awk '{print $2}' | xargs cat
   ```

3. If neither yields a value, write `unknown` to `source_session:`. The
   system continues to function; only audit/forensics use cases degrade.

## Vault Path Discovery

Read the `Vault location: Path:` line of the cortex block in
`~/.claude/CLAUDE.md`. Authoritative copy is also at
`<vault>/.claude-cortex/config.yaml` under the `vault_path:` key.

## Default Project Resolution

When a flow needs a `project:` value and none was given:
1. If a `W-XXXXXX` is the active work item and a previous note in
   `inbox/<W-ID>/` carries `project:`, use that.
2. Else: read the basename of the user's current working directory
   (`pwd | xargs basename`). That's typically the repo name and is the
   right project unless told otherwise.
3. Else: ask the user.

## Inbox Staging Procedure

When writing to `inbox/<W-ID>/`:

1. Discover session id (§ Session ID).
2. If `inbox/<W-ID>/` does not exist:
   - `mkdir -p inbox/<W-ID>`
   - Create `inbox/<W-ID>/sessions.yaml`:
     ```yaml
     work_item: W-<ID>
     title: "<short title — ask user if unclear>"
     created: <now ISO-8601 UTC>
     last_touched: <now ISO-8601 UTC>
     sessions:
       - id: <session-id>
         started: <now ISO-8601 UTC>
         cwd: <pwd>
         summary: "<one-liner what this session is doing>"
         files_touched: [<the file you're about to write>]
     ```
   - Create `inbox/<W-ID>/_index.md` with `## Contents` listing the new file.
3. Else (folder exists):
   - Read `sessions.yaml`.
   - Update `last_touched` to now.
   - If this session id is already in `sessions:`, update its
     `files_touched` (append the new file) and refresh `summary` if it
     adds info. Else: append a new session entry.
   - Append the new file to `_index.md` under `## Contents`.
4. Write the staged note with full frontmatter (`type: scratch`) plus body.
5. Update `inbox/_index.md` "Active staging folders" with the W-ID and
   current `last_touched`.
6. Announce in chat: `Staged → inbox/<W-ID>/<slug>.md`

## `_index.md` Auto-Maintenance

When you create a new file in any folder:

1. Read parent folder's `_index.md` if it exists; create with the standard
   frontmatter if not.
2. Add an entry under `## Contents`:
   ```
   - [<slug>] — <one-line description, 50-90 chars>
   ```
3. Update `last_updated:` in the frontmatter to today's date (UTC).

## Retro Synthesis (`/retro <W-ID>`)

The full algorithm. Run this when the user invokes `/retro` or a natural-
language equivalent.

### 1. Load

- If no W-ID arg: list `inbox/W-*/` sorted by `last_touched` and pick (or
  prompt the user if multiple).
- Read `inbox/<W-ID>/sessions.yaml`.
- Read every staged file (skip `sessions.yaml`, `_index.md`).

### 2. Plan

For each staged file, decide one of:

- **PROMOTE** — content is a single durable note. Pick destination by `type:`
  (or by content if `type: scratch`). Plan a write to a new file at the
  routed destination.
- **EXTRACT** — content has both transient and durable parts. Plan to write
  the durable part as a new file at the routed destination, summarizing the
  transient part into the synthesized retro.
- **APPEND** — content adds context to an existing durable file (rare).
  Plan to append a clearly-delimited section.
- **DISCARD** — transient. Don't promote; mention in the retro for
  completeness.

Plan the synthesized retro at:

```
retros/<project>/YYYY-MM-DD-W-<ID>-<slug>.md
```

The retro carries `type: retro`, `source_session: <current session id>`,
plus the `work_item:`, `project:`, `duration_days:`, `related:` fields.

Plan the archive operation:

```
inbox/<W-ID>/  →  inbox/.archive/<W-ID>/
```

Plan all `_index.md` updates:

- Each new file at a routed destination → its parent `_index.md`.
- The retro file → `retros/<project>/_index.md`.
- Removed `inbox/<W-ID>/` entry → `inbox/_index.md`.

### 3. Present plan as a unified diff

Show the user, in one message:

```
Retro plan for W-<ID> — "<title from sessions.yaml>"

  PROMOTE:
    inbox/<W-ID>/decision-cache-ttl-30m.md
      → projects/<project>/decisions/2026-05-12-cache-ttl.md
    inbox/<W-ID>/soql-failing-rows.md
      → projects/<project>/queries/soql/find-failing-rows.md

  EXTRACT:
    inbox/<W-ID>/splunk-trace.md
      → insights/debugging/splunk-pagination-gotcha.md (durable lesson)
      summary into retro (transient details)

  APPEND:
    (none)

  DISCARD:
    inbox/<W-ID>/question-ask-jane.md (transient — mentioned in retro)

  SYNTHESIZE:
    retros/<project>/2026-05-12-W-<ID>-<slug>.md (new)

  ARCHIVE:
    inbox/<W-ID>/ → inbox/.archive/<W-ID>/

  INDEX UPDATES:
    projects/<project>/decisions/_index.md
    projects/<project>/queries/soql/_index.md
    insights/debugging/_index.md
    retros/<project>/_index.md
    inbox/_index.md

Apply this plan? [y/edit/n]
```

If the user picks `edit`, ask which entries to change and re-present.

### 4. Apply atomically

- Create all new files (promotes, extracts, retro).
- Update all `_index.md` files.
- Move `inbox/<W-ID>/` to `inbox/.archive/<W-ID>/` (use `mv`, not copy+delete).
- Save the dispatch plan as
  `inbox/.archive/<W-ID>/dispatch-plan.md` for auditability.

If any step fails, roll back: delete any new files written this run and
restore `inbox/<W-ID>/` from the archive (it's a `mv` away).

### 5. Report

```
Retro complete.
  1 retro written: retros/<project>/2026-05-12-W-<ID>-<slug>.md
  2 promotions, 1 extraction, 0 appends, 1 discarded.
  Archive: inbox/.archive/<W-ID>/
```

## Resume Brief (`/resume-work <W-ID>`)

Produce a single message that reorients the user.

1. Read `inbox/<W-ID>/sessions.yaml`.
2. Read every staged file's frontmatter (skip body — keep this fast).
3. Present:

```
Work item:   W-<ID> — "<title>"
Started:     2026-04-20 (22 days ago)
Last touched: 2026-04-25 (17 days ago)

Sessions:
  • <id1> (2026-04-20) — "<summary>"
  • <id2> (2026-04-25) — "<summary>"

Staged notes:
  • notes.md                 — running task list
  • soql-query-failing-rows.md — query found 2400 bad rows
  • decision-cache-ttl-30m.md — cache TTL choice + rationale

Open questions (extracted from notes' frontmatter and headings):
  - rate limit per-org vs per-user?
  - rollback path if cache TTL too short?

Suggested next actions:
  (a) Continue here with staged notes as context.
  (b) `claude --resume <id2>` for richer last-session context.
  (c) Run /retro <W-ID> if work is actually done.
```

## Stale Detection

At session start, if any `inbox/W-*/sessions.yaml` has
`last_touched` > {{stale_staging_days}} days ago: surface a one-line notice
in your first response of the session:

```
You have N stale staging folder(s) (>14d). Run /triage-inbox to handle them.
```

Don't block the user's actual question.

## Refresh Index

When the user invokes `/refresh-index <folder>`:

1. Read existing `<folder>/_index.md` if present, preserving every section
   that isn't `## Contents`.
2. List all files in `<folder>` (top-level only, not recursive).
3. For each file, read its frontmatter `title:` and produce a one-liner.
4. Rewrite `## Contents` with the fresh listing.
5. Show the diff. Apply on approval.

## Credentials Rule

Never write a literal credential value into any vault file. If the user
asks, refuse and offer a reference instead:

> I can't write `<value>` into the vault — Cortex's safety rule forbids
> literal secrets even for mocked/test creds. Want me to write a reference
> like `op://Engineering/agentforce-test-user/password`, or a keychain
> item name, instead?

## Pitfalls

- Two sessions writing to the same `inbox/<W-ID>/sessions.yaml` can race.
  Mitigation: re-read the file just before writing; if the contents on disk
  changed since you last read, merge your changes in (append your session,
  union `files_touched`) before writing.
- Don't recurse into `_index.md` updates: only update the *direct* parent
  folder of the file you wrote.
- `_index.md` autogeneration must preserve hand-written prose sections
  (purpose, "Read this folder when", "See also").
