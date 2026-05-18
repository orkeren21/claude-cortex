# Scenario 02: Cap and dedup

Validates that the per-session cap stops further dispatches and that
identical events get deduped within the dedup window.

## Setup

Edit `~/.claude/sentinel/observers.yaml` and set
`per_session_cap: 5` for `cortex-capture`. Restart your session.

## Prompts

1-7. Make 7 distinct decisional statements ("Going with Redis",
   "Switching the test framework to vitest", etc.).

8. `/observer-status`

## Expected

- `Events emitted: 5`.
- `Cap reached: yes`.
- The 6th and 7th decisions are not in the JSONL `event_emitted` count;
  instead each appears as a `cap_reached` line.

## Dedup sub-test

Repeat the same statement twice in a row. Run `/observer-status`.

Expected: `event_deduped: 1`.
