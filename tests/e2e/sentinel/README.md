# Sentinel E2E scenarios (manual)

These scenarios validate Sentinel against a real Claude Code session.
They cost real money (LLM tokens). They are not run in CI.

To run a scenario:

1. Open a fresh Claude Code session in a clean test repo.
2. Confirm `~/.claude/sentinel/log/` is empty for the new session id.
3. Paste the prompt sequence from the scenario file, one prompt per
   turn.
4. After the final prompt, run `/observer-status`.
5. Compare the output against the "Expected" section.

Set `CORTEX_E2E=1` if you want to mark the run in your shell history.
