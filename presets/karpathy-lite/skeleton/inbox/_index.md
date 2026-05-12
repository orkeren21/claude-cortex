---
folder: inbox
purpose: Staging area for mid-flight work. All files here are temporary.
last_updated: 2026-05-12
---

# Inbox — staging only

Work-item folders accumulate here during active work. Run `/retro <W-ID>` to
synthesize them into durable destinations.

## Active staging folders

(None yet — Claude will list them here as they're created.)

## Stale folders

If any folder here has `last_touched` > 14 days, Claude will flag it at session
start and offer `/triage-inbox`.

## Archive

Promoted staging folders move to `.archive/`. Read-only by convention; auditable
for "which session wrote this?" forensics.
