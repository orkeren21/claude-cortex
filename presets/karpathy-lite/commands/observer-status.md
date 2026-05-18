---
description: "Show what Sentinel observers did this session"
source: claude-cortex
---

You are running the `/observer-status` slash command from Claude Cortex.
The user wants a summary of what Sentinel observers did in the current
or past sessions.

## What to do

Find the session id from `~/.claude/session-env/`. Read the JSONL log
at `~/.claude/sentinel/log/<session-id>.jsonl`.

Count and summarize:

- Total `event_emitted` lines per observer.
- Total `dispatch_completed` per outcome (`captured`, `no_capture`,
  `proposal`).
- Any `event_emitted` lines without a matching `dispatch_completed`
  (these are "events the main agent received a reminder for but did
  not dispatch" -- the Path A residual failure mode).
- Any `cap_reached` lines (the cap stopped further dispatches).
- Any `dispatch_failed` lines (with the failure reason).
- Any `event_deduped` lines.

Print, in plain ASCII (no box-drawing, no smart quotes):

```
Session: <sid> (started <human duration> ago)

Events emitted:    <N>
Dispatched:        <N>
No-capture:        <N>
Captures written:  <N>
Proposals queued:  <N>
Failed:            <N>
Cap reached:       <yes|no>

Captures this session:
  <vault path>  (<type>)
  ...

Failures:
  event-id <eid> (<hook>): <reason>
  ...

Replay a failure: /observer-status --replay <event-id>
```

## Flags

- `--replay <eid>`: read the event payload at
  `~/.claude/sentinel/events/<sid>/<eid>.json` and re-dispatch the
  observer (same path the hook would take). Then re-run this status.
- `--week` / `--day`: aggregate across all session JSONLs in the log
  dir whose `ts` falls in the window.
- `--raw`: cat the JSONL.

If there is no JSONL for the session yet, print:

```
Sentinel hasn't fired yet this session. Either no events have triggered
captures, or hooks aren't installed -- check ~/.claude/settings.json.
```

Then stop.
