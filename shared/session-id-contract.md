# Session ID Discovery Contract

This is how a Claude Code session learns its own id at runtime, for use in
`source_session:` frontmatter and `sessions.yaml` updates.

## The contract

The Claude Cortex SessionStart hook (`~/.claude/hooks/claude-cortex-session-start.sh`)
runs at every session start. It reads JSON from stdin, extracts `session_id`, and
writes the id to:

```
~/.claude/session-env/<session_id>/session-id.txt
```

## How callers find their session id

There is no straightforward way for a Claude Code session to know its own id
without external help. The hook above writes a marker file per session. Callers
discover the id via this strategy:

1. **If `CLAUDE_CORTEX_SESSION_ID` is in the environment, use it.** (Set this
   in your wrapper or via Claude Code env settings if you control the launch.)

2. **Otherwise, find the most-recent session-id.txt in `~/.claude/session-env/`.**
   Useful for the bootstrapped case where no env var exists. The most recently
   modified session marker is the current session.

   ```bash
   find ~/.claude/session-env -name session-id.txt -type f -exec stat -f '%m %N' {} \; \
     | sort -rn | head -1 | awk '{print $2}' | xargs cat
   ```

3. **If neither works, fall back to writing `unknown` for `source_session:`.**
   The system continues to function; only the audit/forensics use case degrades.

## Why this approach

- Claude Code's hook protocol is the only reliable signal for session boundaries.
- A per-session marker file means the id is queryable from any later moment in
  the session (slash commands, capture flows) without re-parsing hook stdin.
- Marker files in `session-env/` are already a Claude Code convention; we are
  not introducing a novel directory.
- Concurrent sessions don't collide because each gets its own subdirectory.
