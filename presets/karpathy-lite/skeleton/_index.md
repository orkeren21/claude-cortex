---
folder: /
purpose: Top-level map of the Claude Cortex vault
last_updated: 2026-05-12
---

# Vault root

This is your second brain. Claude Code reads it freely and writes only via
explicit capture flows defined in `~/.claude/CLAUDE.md`.

## Top-level folders
- [inbox/](inbox/_index.md) — STAGING ONLY. Per-work-item folders that get
  promoted at retro. Don't put things here you intend to keep.
- [retros/](retros/_index.md) — synthesized retrospectives produced by
  `/retro`, organized by project.
- [insights/](insights/_index.md) — durable cross-project lessons. Debugging
  gotchas, architecture patterns, tooling tips.
- [projects/](projects/_index.md) — per-project canonical knowledge.
  Each project has a `README.md`, `architecture/`, `decisions/`,
  `queries/`, `org-ids.md`, etc.
- [people/](people/_index.md) — collaborators, expertise, 1:1 notes.
- [references/](references/_index.md) — distilled external reading.

## Conventions
- Every Claude-written note has YAML frontmatter with at least `type:`,
  `title:`, `created:`, `updated:`, and `source_session:`.
- Every folder has a `_index.md` listing its contents.
- Filenames are kebab-case, ~6 words max.
- Dates in filenames are `YYYY-MM-DD`.
- Credentials are never literals — only references (`op://...`, keychain
  item names).
