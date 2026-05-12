---
title: Claude Cortex — Obsidian-backed Second Brain Design
date: 2026-05-12
status: approved
authors: [orkeren21]
preset_default: karpathy-lite
auto_capture_default: balanced
---

# Claude Cortex — Design Spec

## 1. Purpose

A persistent, Obsidian-backed knowledge layer ("second brain") that every Claude Code session reads and selectively writes to. The system reduces the mental load of context management across many parallel projects by:

- Reading the vault freely as ambient context.
- Auto-staging mid-flight notes (queries, decisions, gotchas) into a per-work-item inbox with announcement.
- Synthesizing retrospectives that promote staged notes into durable, well-organized destinations.
- Tracking the Claude Code session IDs that contributed to each staging folder so a user returning from a break can resume with full context.

Inspired by Andrej Karpathy's locally-curated Obsidian-vault practice; productized with auto-routing, session tracking, and a paste-and-run installer so it can be shared with others.

## 2. Goals & Non-Goals

### Goals
- Every Claude Code session, regardless of working directory, knows the vault exists, where it is, what's in it, and the rules for reading and writing.
- Capture has near-zero friction during flow; classification happens at retro time, not capture time.
- The vault remains human-curated. Claude never silently scribbles on existing notes.
- Vault is portable: the vault itself is independent of Claude Code; the integration lives in `~/.claude/`.
- The system is shareable: a public GitHub repo with a paste-and-run installer that asks the user a few questions, then lays everything down.
- Two presets supported (karpathy-lite default, PARA alternative); both share the same frontmatter schema and slash command set.
- Stale-staging detection (>14 days, sprint-aligned) to catch forgotten work items.

### Non-Goals
- Not a task tracker. Status fields like `priority:` are deliberately absent; ADRs get `status:` because it's intrinsic to ADRs.
- Not a credential store. Vault stores *references* to secrets (1Password, keychain), never literal values.
- Not a Claude Code plugin (yet). Distribution v1 is paste-and-run; plugin packaging is a future evolution after the shape stabilizes.
- macOS only in v1. Linux and Windows are out of scope.

## 3. Glossary

| Term | Meaning |
|---|---|
| **Vault** | The user's Obsidian vault at `<vault_path>`. Default: `~/Documents/Obsidian/WorkOS`. |
| **Preset** | Full bundle of CLAUDE.md template, folder skeleton, skills, and commands. Two ship: `karpathy-lite`, `para`. |
| **Capture flow** | Any path by which Claude writes to the vault: slash command, natural-language equivalent, auto-stage, offer-and-approve, session-end batched offer. |
| **Staging** | The `inbox/W-XXXXXX/` per-work-item folders where mid-flight notes accumulate. |
| **Retro** | The synthesis-and-dispatch operation that promotes staged notes into durable destinations and writes a synthesized retrospective. |
| **Auto-capture mode** | One of `aggressive`, `balanced` (default), `minimal`, `off`. Controls how aggressive auto-staging and offers are. |
| **`_index.md`** | A folder-level navigation file Claude reads first to limit context when descending into a folder. Auto-maintained. |
| **`sessions.yaml`** | Per-staging-folder record of which Claude Code sessions contributed to it. Powers post-vacation resume and stale-staging detection. |

## 4. System Architecture

Three components, three responsibility lines.

```
┌──────────────────────────────────────────────────────────────────────┐
│  THE DISTRIBUTION REPO  (github.com/orkeren21/claude-cortex)         │
│  ─────────────────────────────────────────────────────────────────   │
│   README.md          ← landing page + paste-this-into-Claude block   │
│   install.md         ← the script Claude reads & executes            │
│   update.md          ← in-place upgrade                              │
│   uninstall.md       ← clean reversal                                │
│   presets/                                                            │
│     karpathy-lite/   ← default preset                                │
│       preset.yaml                                                     │
│       CLAUDE.md.tmpl ← global routing rules                          │
│       skeleton/      ← folder skeleton with _index.md files          │
│       skills/        ← skill markdown files                          │
│       commands/      ← slash command definitions                     │
│     para/            ← alternative preset                             │
│   shared/            ← preset-agnostic assets                         │
│   docs/              ← specs, manual setup, troubleshooting           │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              │  install.md (Claude reads it, asks
                              │   questions, copies files)
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  THE USER'S MACHINE                                                  │
│  ─────────────────────────────────────────────────────────────────   │
│                                                                      │
│  ~/.claude/                                                           │
│    CLAUDE.md          ← global rules: vault path, contract, routing  │
│                         table, heuristics, triggers                  │
│    skills/                                                            │
│      claude-cortex/   ← skill files                                  │
│    commands/                                                          │
│      save-insight.md                                                  │
│      save-to-inbox.md                                                 │
│      retro.md                                                         │
│      resume-work.md                                                   │
│      triage-inbox.md                                                  │
│      refresh-index.md                                                 │
│                                                                      │
│  <vault_path>/                  ← the Obsidian vault                 │
│    _index.md         ← top-level vault map                           │
│    .claude-cortex/                                                    │
│      config.yaml     ← preset, version, vault_path, settings         │
│    inbox/                                                             │
│      _index.md                                                        │
│      W-XXXXXX/       ← per-work-item staging                         │
│        sessions.yaml                                                  │
│        <staged notes>                                                 │
│      .archive/       ← post-retro snapshots                          │
│    retros/                                                            │
│    insights/                                                          │
│    projects/                                                          │
│    people/                                                            │
│    references/                                                        │
│    daily/            ← optional                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### 4.1 Responsibility Lines

| Component | Owns |
|---|---|
| **The repo** | Templates, rules, presets, install scripts. Is the source of truth for upgrades. Does not assume vault path. |
| **`~/.claude/CLAUDE.md`** | Global runtime contract loaded into every Claude Code session, regardless of cwd. The single document that makes "every session knows the vault" true. |
| **`~/.claude/skills/claude-cortex/`** | Procedural depth — full frontmatter schema, retro synthesis algorithm, etc. Referenced from CLAUDE.md, loaded on demand. |
| **`~/.claude/commands/`** | Slash command definitions. Each declares `source: claude-cortex` in frontmatter for ownership identification at update/uninstall. |
| **The vault** | The user's knowledge. Claude reads freely; writes only via capture flows. Portable — opens fine on a machine without Claude Code. |
| **`<vault>/.claude-cortex/config.yaml`** | Persistent state about the install (preset, version, vault_path, settings). Travels with the vault if moved. Used by `update.md` to detect what to upgrade. |

### 4.2 Why these boundaries

- **Skills + commands in `~/.claude/`, not in the vault.** Vault portability matters. A user could open the vault on a phone, on a different machine, or share it with someone — Claude-specific machinery shouldn't pollute the knowledge.
- **Vault config travels with vault.** If the user moves the vault folder, the config goes with it. If they reinstall Claude Code, the vault still knows what preset and version it was last set up with.
- **Repo updates flow through the same paths the install used.** No magic — `update.md` reads the same config, writes to the same `~/.claude/` paths.

## 5. Vault Taxonomy

### 5.1 Karpathy-lite (default preset)

```
<vault_path>/
├── _index.md                      ← top-level map of the whole vault
├── .claude-cortex/
│   └── config.yaml                ← preset, version, vault_path, settings
│
├── inbox/                         ← STAGING ONLY
│   ├── _index.md                  ← lists active staging folders + ages
│   ├── W-123456/                  ← per-work-item staging
│   │   ├── sessions.yaml          ← session log (auto-written)
│   │   ├── notes.md
│   │   ├── soql-query-failing-rows.md
│   │   └── decision-cache-ttl-30m.md
│   └── .archive/
│       └── W-122000/              ← post-retro snapshot (read-only)
│
├── retros/
│   ├── _index.md
│   └── <project>/
│       ├── _index.md
│       └── 2026-05-12-W-123456-bulk-action-api.md
│
├── insights/                      ← durable cross-project lessons
│   ├── _index.md
│   ├── debugging/
│   │   └── _index.md
│   ├── architecture/
│   │   └── _index.md
│   ├── tooling/
│   │   └── _index.md
│   └── salesforce-platform/
│       └── _index.md
│
├── projects/                      ← per-project canonical knowledge
│   ├── _index.md
│   └── <project-name>/
│       ├── _index.md
│       ├── README.md              ← project overview
│       ├── architecture/
│       │   └── _index.md
│       ├── decisions/             ← ADR-style
│       │   └── _index.md
│       ├── queries/               ← canonical queries, one file per query
│       │   ├── _index.md
│       │   ├── splunk/
│       │   │   ├── _index.md
│       │   │   ├── auth-debugging-401-spike.md
│       │   │   └── rate-limit-by-org.md
│       │   ├── soql/
│       │   │   └── _index.md
│       │   ├── argus/
│       │   │   └── _index.md
│       │   └── graphql/
│       │       └── _index.md
│       ├── org-ids.md
│       ├── secrets.md             ← REFERENCES only (op://, keychain)
│       └── open-questions.md
│
├── people/
│   └── _index.md
│
├── references/
│   ├── _index.md
│   ├── articles/
│   └── books/
│
└── daily/                         ← optional, opt-in at install
    └── _index.md
```

### 5.2 Routing table (Karpathy-lite)

| `type:` | Destination |
|---|---|
| `scratch` | `inbox/<W-ID>/<slug>.md` |
| `retro` | `retros/<project>/YYYY-MM-DD-<W-ID>-<slug>.md` |
| `insight` | `insights/<topic>/<slug>.md` |
| `architecture` | `projects/<project>/architecture/<slug>.md` |
| `decision` | `projects/<project>/decisions/YYYY-MM-DD-<slug>.md` |
| `query` | `projects/<project>/queries/<query_kind>/<slug>.md` (one file per query) |
| `person` | `people/<firstname>-<lastname>-<role-slug>.md` |
| `reference` | `references/<kind>/<slug>.md` |

### 5.3 PARA (alternative preset)

Same frontmatter schema (so `type:` still drives routing), different folder map, plus a `lifecycle: active|archived` field on project notes and a `para_zone:` field on routed notes. Routing differs:

| `type:` | PARA destination |
|---|---|
| `scratch`, `retro`, `architecture`, `decision`, `query` (active) | `1-projects/<project>/...` |
| `architecture`, `query`, runbook (ongoing service) | `2-areas/<service-ownership>/...` |
| `insight`, `reference` | `3-resources/<topic>/...` |
| Anything when project archived | `4-archive/<project>/...` |
| `person` | `2-areas/1-1s/<firstname>-<lastname>-...md` |

PARA is documented as requiring more manual curation; auto-triage success rate is lower than karpathy-lite because Project/Area/Resource is a judgment call where retro/insight/decision is mechanical.

### 5.4 Filename conventions

| Note kind | Pattern |
|---|---|
| Retro | `YYYY-MM-DD-<W-ID>-<slug>.md` |
| Decision (ADR) | `YYYY-MM-DD-<slug>.md` |
| Insight | `<slug>.md` (no date — durable) |
| Daily | `YYYY-MM-DD.md` |
| Person | `<firstname>-<lastname>-<role-slug>.md` |
| Project file | descriptive name, no date |
| Inbox staging | `<slug>.md` inside `W-XXXXXX/` |

Slugs are kebab-case, lowercase, ~6 words max.

## 6. Frontmatter Schema

Every Claude-written note carries YAML frontmatter. This is what makes auto-routing, auto-indexing, and cross-references work.

### 6.1 Universal fields (all notes)

```yaml
---
type: insight | retro | architecture | decision | query | person | reference | scratch
title: "Splunk pagination silently drops rows past 10k"
created: 2026-05-12T11:30:00Z
updated: 2026-05-12T11:30:00Z
tags: [splunk, debugging, pagination]
source_session: 0193ab51-991c-7d40-...
---
```

### 6.2 Type-specific fields

```yaml
# type: retro
work_item: W-123456
project: agentforce-actions
duration_days: 4
related: [insights/debugging/splunk-pagination-gotcha.md]

# type: insight
topic: debugging                       # subfolder under insights/
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

### 6.3 PARA-only extension

```yaml
lifecycle: active | archived
para_zone: 1-projects | 2-areas | 3-resources | 4-archive
```

### 6.4 Deliberate omissions

- **No tags taxonomy.** Tags are free-form. Discovery comes from folder structure + `_index.md`; tags are bonus.
- **No `priority:` or `status:` (except ADRs).** This is a knowledge base, not a tracker.
- **`source_session:` is captured everywhere, not just in inbox.** Cheap; occasionally invaluable for "which session produced this insight three months ago?".

## 7. `_index.md` Convention

Every folder has an auto-maintained `_index.md` so Claude can scan a folder map before deciding which files to open — limiting context to what's needed.

### 7.1 Shape

```markdown
---
folder: insights/debugging
purpose: Durable debugging gotchas and patterns
last_updated: 2026-05-12
---

# Debugging insights

One-paragraph what-belongs-here / what-doesn't.

## Contents
- [splunk-pagination-gotcha.md] — Splunk pagination silently drops rows past 10k
- [stacktrace-line-offsets.md] — Bazel's line offsets are off-by-one in JVM stacks

## Read this folder when
- Investigating a flaky log query
- Reading a stack trace that doesn't match source

## See also
- ../tooling/_index.md
- ../../projects/<repo>/queries/splunk/_index.md
```

### 7.2 Two-tier read pattern

> Before reading any file inside a vault folder, read that folder's `_index.md` if present. Use it to choose which files (or subfolders) are worth opening. Recurse: if descending into a subfolder, read its `_index.md` first too.

### 7.3 Auto-maintenance

- Whenever Claude writes a new file into a folder via a capture flow, also update that folder's `_index.md`: add a one-line entry under "Contents", bump `last_updated:`.
- `/refresh-index <folder>` regenerates an index from actual contents (preserves hand-written prose sections; only the file listing is regenerated).
- Vault root has its own `_index.md` — top-level map of the whole vault.

### 7.4 Trade-off

Every capture flow is a two-file write (the note + the index update). Slightly slower at write time, but the read-time savings on every future query pay it back many times over.

## 8. Capture Flows & Slash Commands

### 8.1 Command map

| Command | Purpose |
|---|---|
| `/save-insight` | Single-note durable capture, auto-routed by `type:`. |
| `/save-to-inbox` | Zero-friction staging into `inbox/<W-ID>/`. |
| `/retro [W-ID]` | Synthesize + dispatch a staged folder. |
| `/resume-work [W-ID]` | Read inbox + `sessions.yaml`, brief the user. |
| `/triage-inbox` | Scan staging for stale + unclassified; offer paths forward. |
| `/refresh-index <dir>` | Regenerate an `_index.md` from actual folder contents. |

### 8.2 `/save-insight` — single-note durable capture

```
/save-insight [type=...] [title=...]

What it does:
  1. Reads current session context for the insight to capture.
  2. Asks (one question, only if ambiguous): "Type: insight | architecture |
     decision | query | reference?"  (skipped if `type=...` provided.)
  3. Writes to the routed destination per the routing table.
  4. Updates parent folder's _index.md.
  5. Reports: "Saved → <abs path>"
```

Natural-language equivalents: "save this to the vault", "save this lesson", "log this insight".

### 8.3 `/save-to-inbox` — staging

```
/save-to-inbox [W-ID] [title=...]

What it does:
  1. Determine W-ID:
       - From slash arg if given.
       - Else from a recently-mentioned W-XXXXXX in the session.
       - Else asks: "Which work item? (W-XXXXXX, or 'none' for unclassified)"
  2. Creates inbox/W-<ID>/ if missing; touches sessions.yaml.
  3. Writes the staged note as a fresh file with frontmatter type: scratch.
  4. Appends/updates this session's entry in sessions.yaml.
  5. Updates inbox/_index.md and inbox/W-<ID>/_index.md (lightweight).
  6. Reports: "Staged → inbox/W-<ID>/<slug>.md"
```

Natural-language equivalents: "stage this", "save to inbox", "park this for the retro".

### 8.4 `/retro [W-ID]` — synthesis-and-dispatch

```
/retro [W-ID]

What it does:
  1. If no W-ID, list all inbox/W-*/ folders with last_touched, offer picker
     (or pick the only one if there's only one).
  2. Read inbox/W-<ID>/sessions.yaml + every staged file.
  3. Optionally read originating sessions' context (per stale-inbox flow).
  4. PROPOSE A DISPATCH PLAN:
       For each staged file, pick one of:
         - PROMOTE   → write to projects/<project>/decisions/<...> (new file)
         - APPEND    → append a section to an existing file (rare; e.g. additional context to an existing decision or query note)
         - EXTRACT   → factor a portion into insights/<topic>/<slug>.md
         - DISCARD   → transient, drop
       Then SYNTHESIZE retros/<project>/YYYY-MM-DD-W-<ID>-<slug>.md
       (a fresh write, not a copy).
       Then ARCHIVE inbox/W-<ID>/ → inbox/.archive/W-<ID>/.
       Then UPDATE every touched _index.md.
  5. Present the unified diff. User approves / edits / rejects in one pass.
  6. Apply atomically (all-or-nothing).
  7. Report a summary.

Safety:
  - Original staging folder is ARCHIVED, never deleted.
  - Dispatch plan stored as inbox/.archive/W-<ID>/dispatch-plan.md (auditable).
```

Natural-language equivalents: "let's retro W-123456", "I'm done with this work item, retro it", "wrap up W-123456".

### 8.5 `/resume-work [W-ID]` — post-vacation resume

```
/resume-work [W-ID]

What it does:
  1. If no W-ID, list all inbox/W-*/ sorted by last_touched.
  2. For chosen W-ID, read sessions.yaml + every staged file.
  3. Produce a brief: title, started, last_touched, sessions list (id +
     date + summary), staged notes list, open questions, suggested next
     actions:
       (a) Continue in this session with staged notes as context.
       (b) `claude --resume <session-id>` for richer context.
       (c) Run /retro if work is actually done.
  4. Wait for user to pick.
```

Natural-language equivalents: "where was I on W-123456?", "resume W-123456".

### 8.6 `/triage-inbox` — periodic cleanup

```
/triage-inbox [--stale-days=14] [--purge]

What it does:
  - Scan inbox/W-*/ for last_touched > stale-days ago (default 14, sprint-aligned).
  - For each stale folder, present resume brief + offer:
      (a) Retro now.
      (b) Resume an originating session and retro there.
      (c) Defer (touch the folder).
      (d) Discard staging without retro (move to .archive/, no synthesis).
  - --purge: clean up inbox/.archive/ entries older than 90 days
    (with confirmation showing what'll be removed).
```

Triggered automatically when:
- Claude detects stale folders at session start (one-line surface, non-blocking).
- User asks "anything stale in the inbox?".

### 8.7 `/refresh-index <folder>` — drift recovery

Regenerates `<folder>/_index.md` from actual folder contents. Preserves hand-written prose sections; only file listing is regenerated. Reports diff before applying. Use after manual file moves in Obsidian.

## 9. Triggers

The `auto_capture_mode` setting (one of `aggressive`, `balanced` (default), `minimal`, `off`) controls how aggressive auto-staging and offers are.

### 9.1 Auto-capture heuristics (mode = balanced)

| Pattern | Example phrases | Action |
|---|---|---|
| Query confirmed working | "that worked", "yep returns the rows", "this query gives me…" | Auto-stage to `inbox/<W-ID>/`, type: query |
| Decision made | "we decided", "going with X", "let's use X over Y" | Queue for session-end batch, type: decision |
| Generalizable gotcha | "turns out", "gotcha is", "next time remember" | Queue for session-end batch, type: insight |
| Architecture explained | extended explanation of repo/system structure | Queue for session-end batch, type: architecture |
| Person context | "Jane is the owner of…", "ask John about…" | Queue for session-end batch, type: person |
| W-XXXXXX mentioned | any `W-\d{6,}` pattern | Set as active work item; future stages target this folder |

### 9.2 Mode behaviors

| Mode | Auto-stage | Offers |
|---|---|---|
| `aggressive` | Every detected pattern | Batched at session end |
| `balanced` (default) | Queries, scratch only | Decisions/insights offered at end |
| `minimal` | Never | Only at session end / completion signals |
| `off` | Never | Never (slash + natural-language only) |

### 9.3 Trigger paths

| Trigger | When it fires | What Claude does |
|---|---|---|
| Slash command | `/retro`, `/save-insight`, etc. | Runs the command. |
| Natural language | "save this to the vault", "stage this", "let's retro W-XXXXXX" | Maps to corresponding command. |
| Auto-stage | Heuristic match per mode | Stages and announces in one line. |
| Session-end offer | Long session (>30 min activity) AND captures made | Asks once: "Save these N items?" |
| Completion signal | PR merged via `gh`, "shipped it", work-item closed | Asks: "Run /retro for W-<ID>?" |
| Stale-staging | At session start: any `inbox/W-*/` `last_touched` > 14 days | One-line surface; offers `/triage-inbox`. |

### 9.4 Contract

Claude *offers*; the user always says yes/edit/no. Auto-staging is the one exception — it acts and announces, because the destination is reversible (inbox, archived not deleted).

## 10. Session Tracking

### 10.1 `sessions.yaml` schema

Each `inbox/W-XXXXXX/` carries a `sessions.yaml`:

```yaml
work_item: W-123456
title: "Bulk action API rate limits"
created: 2026-05-12T09:14:00Z
last_touched: 2026-05-12T11:30:00Z
sessions:
  - id: 0193ab4f-7c2e-7a8b-...
    started: 2026-05-12T09:14:00Z
    cwd: /Users/okeren/Projects/agentforce-actions
    summary: "Initial scaffolding; hit auth middleware bug; documented in notes.md"
    files_touched: [notes.md, decision-cache-ttl-30m.md]
  - id: 0193ab51-991c-7d40-...
    started: 2026-05-12T10:55:00Z
    cwd: /Users/okeren/Projects/agentforce-actions
    summary: "Splunk investigation of failing rows; saved trace + query"
    files_touched: [splunk-trace-2026-05-12.md, soql-query-failing-rows.md]
```

### 10.2 Session ID source

Claude obtains its session id from a per-session marker file written by a `SessionStart` hook installed by `install.md`. Hook target path: `~/.claude/session-env/<id>/session-id.txt`. (Implementation details for the hook deferred to the implementation plan.)

### 10.3 Lifecycle

- **Created** — first time Claude writes into `inbox/W-<ID>/`.
- **Updated** — every subsequent write touches `last_touched` and current session's entry.
- **Archived** — at retro, `sessions.yaml` is moved into `inbox/.archive/W-<ID>/` alongside the staged files. Promoted/extracted notes retain their original `source_session:` frontmatter, but are no longer tracked in any `sessions.yaml` (the per-folder log lives only in the archive). The synthesized retro carries `source_session:` for the session that ran `/retro`.

### 10.4 Use cases

- **Resume after a break.** `/resume-work W-<ID>` reads sessions.yaml and reports last-touched, summaries, and ids. User picks: continue here, or `claude --resume <id>` for richer context.
- **Stale-staging proactive prompt.** Trigger on `last_touched` > 14 days. Claude offers retro options and lists originating sessions inline so the user can pick which session to resume from before retro-ing.
- **Audit / forensics.** "Which session wrote this?" — even after retro, the answer is in `inbox/.archive/W-<ID>/sessions.yaml`.

## 11. The `~/.claude/CLAUDE.md` Block

Loaded into every Claude Code session at start. Delimited so updates and uninstalls can target it cleanly without touching the user's other CLAUDE.md content.

### 11.1 Delimiter convention

```
<!-- claude-cortex:begin v1 -->
…rules…
<!-- claude-cortex:end -->
```

If the user has no `~/.claude/CLAUDE.md`, `install.md` creates one with just this block. If one exists, the block is appended (after a blank line); the rest of the file is untouched.

### 11.2 Block contents

The block contains:

1. **Vault location** — absolute path, preset, auto-capture mode, stale threshold, index auto-maintenance flag.
2. **Read/write contract** — what Claude may read, write, and never do.
3. **Auto-capture heuristics** — the table from §9.1, parameterized by current mode.
4. **Trigger paths** — the table from §9.3.
5. **Routing table** — §5.2 (or §5.3 for PARA).
6. **Frontmatter requirement** — universal fields (§6.1).
7. **Index files convention** — §7.2 read pattern + auto-update rule.
8. **Session tracking** — pointer to `sessions.yaml` schema and session-id source.
9. **When in doubt** — ask the user.

The full frontmatter schema, retro synthesis algorithm, and other procedural depth live in `~/.claude/skills/claude-cortex/`, referenced by name from the block.

### 11.3 Why one block, not modular

Considered splitting into multiple delimited sections for partial uninstall. Rejected: partial uninstall isn't a real use case, single block is simpler to update, and the cost of one slightly larger block in every session's context is small relative to the wins (no skill-file lookup needed for routine writes).

## 12. Distribution Repo Layout

```
claude-cortex/
├── README.md                      ← landing page + paste-this-into-Claude block
├── LICENSE                        ← MIT
├── .gitignore
├── .github/
│   ├── CODEOWNERS                 ← *  @orkeren21
│   └── ISSUE_TEMPLATE/
│
├── install.md                     ← Claude reads & executes
├── update.md                      ← in-place upgrade
├── uninstall.md                   ← clean reversal
│
├── presets/
│   ├── karpathy-lite/
│   │   ├── preset.yaml            ← name, version, description
│   │   ├── CLAUDE.md.tmpl         ← global rules block (with placeholders)
│   │   ├── skeleton/              ← folder skeleton with _index.md files
│   │   ├── skills/                ← copied to ~/.claude/skills/claude-cortex/
│   │   └── commands/              ← copied to ~/.claude/commands/
│   └── para/
│       ├── preset.yaml
│       ├── CLAUDE.md.tmpl
│       ├── skeleton/
│       ├── skills/
│       └── commands/
│
├── shared/
│   ├── frontmatter-schema.md
│   ├── routing-table.md
│   └── version.txt                ← installed-version marker (semver)
│
├── docs/
│   ├── specs/
│   │   └── 2026-05-12-second-brain-design.md  ← THIS DOC
│   ├── troubleshooting.md
│   ├── presets-comparison.md
│   ├── frontmatter-reference.md
│   └── architecture.md
│
└── examples/
    ├── sample-vault/
    ├── sample-retro.md
    ├── sample-insight.md
    └── sample-decision.md
```

### 12.1 README paste-prompt

The README's primary CTA is one block users copy:

```markdown
## Install

Open Claude Code in any directory and paste this prompt:

> Read the install.md from
> https://raw.githubusercontent.com/orkeren21/claude-cortex/main/install.md
> and follow it step by step. It will guide me through choosing a preset,
> picking a vault location, and setting up the second-brain system.

Claude will:
1. Check if Obsidian is installed (and offer to install via Homebrew if not).
2. Ask where your Obsidian vault lives (or offer to create one).
3. Ask which preset you want (karpathy-lite or para).
4. Ask which auto-capture mode (aggressive | balanced | minimal | off).
5. Lay down the folder skeleton, skills, commands, and CLAUDE.md rules.
6. Verify with a smoke test.

Estimated time: 2–3 minutes.
```

### 12.2 `install.md` flow

```
§0  Preflight
    - Check OS: macOS only. Bail with "not supported" otherwise.
    - Check Obsidian.app present; if not, offer `brew install --cask obsidian`
    - Check ~/.claude/ exists (if not, prompt to install Claude Code first)

§1  Vault discovery
    - Search ~/Documents/Obsidian/*, ~/Obsidian/*, ~/vault
    - Confirm with user; if none found, ask absolute path or offer to create

§2  Preset selection
    - Show karpathy-lite vs para comparison; default karpathy-lite

§3  Auto-capture mode
    - Show four options; default balanced

§4  Optional features
    - Daily notes folder? (y/N)
    - Stale-staging warning threshold (days, default 14)
    - _index.md auto-maintenance (y/N, default y)

§5  CLAUDE.md merge
    - If exists: append delimited block
    - If not: create
    - Show diff, confirm

§6  Skeleton + skills + commands install
    - Copy skeleton/ into <vault_path>/ (skip if exists)
    - Copy skills/ into ~/.claude/skills/claude-cortex/
    - Copy commands/ into ~/.claude/commands/
    - Write <vault_path>/.claude-cortex/config.yaml

§7  Verification
    - Re-read CLAUDE.md to confirm rules loaded
    - Smoke test: stage a test note via /save-to-inbox, then /retro --dry-run
    - Print summary

§8  Reporting
    - Summary of what changed (paths)
    - Pointer to docs/troubleshooting.md
```

Each section shows the action it's about to take and waits for confirmation. Install is a privileged operation; the user sees every write before it happens.

### 12.3 `update.md` — version-aware upgrade

- Reads `<vault_path>/.claude-cortex/config.yaml` for installed version + preset.
- Compares against `shared/version.txt`. If newer:
  - Diffs new `CLAUDE.md.tmpl` against current block (between delimiters); applies on approval.
  - Refreshes skills + commands.
  - Migrates skeleton if needed (per `migrations/<from>-to-<to>.md`).
  - Bumps `config.yaml` version.

### 12.4 `uninstall.md` — clean reversal

- Removes delimited block from `~/.claude/CLAUDE.md` (rest untouched).
- Removes `~/.claude/skills/claude-cortex/`.
- Removes claude-cortex-owned slash commands from `~/.claude/commands/` (identified by `source: claude-cortex` frontmatter).
- Asks separately about vault contents and `inbox/.archive/`. Default: keep both. Vault data never destroyed without explicit second confirmation.
- Removes `<vault>/.claude-cortex/`.
- Reports summary.

### 12.5 Three deliberate distribution choices

1. **Skills go to `~/.claude/skills/claude-cortex/`, not as a Claude Code plugin.** Distribution v1 is paste-and-run; plugin packaging is a future evolution after the shape stabilizes through real use.
2. **Presets share most slash command bodies.** Branching logic lives in the CLAUDE.md routing table, not in commands. `presets/karpathy-lite/commands/` and `presets/para/commands/` are ~95% identical — clarity over deduplication.
3. **`shared/version.txt` is one line, semver, from day one.** `install.md` writes it into the vault config; `update.md` compares.

## 13. Threat Model & Safety

### 13.1 Credentials

- Vault stores **references** to secrets (1Password CLI URIs, keychain item names), never literal values.
- CLAUDE.md rules forbid Claude from writing literal credentials to the vault even if asked. Claude refuses and suggests a reference.
- This rule applies to "mocked" / "test" credentials too — they tend to drift toward real values.

### 13.2 Data preservation

- The retro flow archives, never deletes. `inbox/.archive/W-<ID>/` is read-only by convention.
- `uninstall.md` defaults to keeping vault contents.
- `--purge` operations require explicit user confirmation showing exactly what'll be removed.

### 13.3 CLAUDE.md merge

- Append-with-delimiters means `update.md` and `uninstall.md` operate on a known block, never the user's other content.
- If delimiters are corrupted/missing on update, the tool refuses and asks the user to inspect.

### 13.4 Concurrent sessions writing to the same `sessions.yaml`

- Two sessions writing simultaneously could race. Mitigation deferred to implementation plan; likely a simple advisory file lock with retry.

## 14. Out of Scope (v1)

- **Embeddings / semantic search over the vault.** Future enhancement; v1 relies on grep + `_index.md` navigation.
- **Multi-vault support.** v1 supports one vault per Claude Code install. Multi-vault could come via per-project `CLAUDE.md` overrides later.
- **Vault sync conflicts.** If the user runs Obsidian Sync / iCloud / Dropbox on the vault, conflicts are the user's problem. v1 documents the recommendation; it doesn't resolve.
- **Linux and Windows.** Not supported in v1. macOS only.
- **Plugin packaging.** v1 is paste-and-run; plugin packaging is a future evolution.
- **Telemetry / usage analytics.** None.

## 15. Open Implementation Questions

These are decisions to make during the implementation plan, not now:

1. **Session-id capture mechanism.** A `SessionStart` hook is the cleanest path. Exact contract (env var? file?) deferred.
2. **Race-free `sessions.yaml` updates.** Simple advisory lock vs. atomic-rename vs. append-only log. Pick during implementation.
3. **Auto-capture detection precision.** The heuristic table is a starting point; tuning happens against real usage. v1 ships with the table and the four modes; tuning is a v1.x problem.
4. **`/retro` UI presentation.** "Unified diff" is the design intent; the exact rendering (markdown table? Claude Code's diff view? plain text plan?) is an implementation choice.
5. **Where Obsidian's own `.obsidian/` folder fits.** Vault root has `.obsidian/`; the skeleton must not clobber it. Likely just an "if exists, leave it" rule.
6. **Multi-project work items.** A single `W-<ID>/` may produce notes spanning two projects (e.g. an integration touching `agentforce-actions` and `api-gateway`). Retro routing currently assumes one project per work item. Likely resolution: per-staged-file `project:` frontmatter overrides a folder-level default; the dispatch plan splits accordingly.
7. **Default project resolution.** When `/save-to-inbox` runs with no project context, what's the project? Likely: infer from `cwd` (the basename of the current working directory), with override on retro.

## 16. Success Criteria

The v1 system is successful if:

- A user can paste the README block into a fresh Claude Code session and have a working install in under 5 minutes.
- During a 30-minute coding session on a tracked work item, ≥3 useful captures land in `inbox/W-<ID>/` without the user typing a slash command.
- After a 2-week vacation, `/resume-work W-<ID>` produces a brief that gets the user back to productive context in under 2 minutes.
- A `/retro` on a folder of 8 staged notes produces a dispatch plan the user accepts (or accepts-with-light-edits) without rejecting outright.
- A second user can install the system from the public repo without asking the original author for help.

## 17. Decision Log

| Decision | Choice | Why |
|---|---|---|
| Read/write semantics | Read free, write only via capture flows (option B) | Vault stays human-curated; capture has structured paths. |
| Vault structure default | Karpathy-lite | Auto-triage success rate; concrete artifact-kind folders vs. PARA's judgment-call zones. |
| Vault structure alternative | PARA preset offered, with manual-curation warning | User choice; both presets share frontmatter schema. |
| Capture trigger model | Slash + natural language + Claude-initiated offers (option C) | Reduces mental load; user no longer has to remember to capture. |
| Inbox staging strategy | Per-`W-<ID>/` folder with `sessions.yaml`; promoted at retro | Zero-friction during flow; consolidation at retro. |
| Retro review mode | Single unified diff (option B.a) | Per-item prompts get exhausting after 8 staged notes. |
| Session tracking | `sessions.yaml` per staging folder; archived on promotion | Powers post-vacation resume and stale-staging detection. |
| Stale threshold | 14 days (sprint-aligned) | User's stated cadence. |
| Distribution shape | Plain GitHub repo + paste-this-into-Claude installer (option A) | Ships fast; plugin packaging deferred until shape stabilizes. |
| `_index.md` auto-maintenance | Enabled by default; auto-update on every capture write | Hand-maintained indexes always rot. |
| CLAUDE.md install posture | Delimited append (`<!-- claude-cortex:begin v1 -->`) | Clean updates and uninstalls; doesn't touch user's other content. |
| Auto-capture default mode | `balanced` | Aggressive enough to be useful, conservative enough to not surprise. |
| Skill directory name | `~/.claude/skills/claude-cortex/` | Matches repo name. |
| Vault internal config dir | `<vault>/.claude-cortex/` | Diagnostic of which tool wrote it; consistent with skill name. |
