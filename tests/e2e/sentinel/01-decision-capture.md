# Scenario 01: Decision capture

Validates that a clear decisional statement results in a `decision`
capture.

## Prompts (paste one at a time, wait for response)

1. "I need to pick between three caching layers: Redis, in-memory LRU,
   and a Cloudflare KV. Which should I use for this?"
2. (after Claude responds with tradeoffs) "Let's go with Redis."
3. "Now write a hello-world test."
4. `/observer-status`

## Expected

- `Captures written: 1` (the Redis decision).
- A new file in `<vault>/projects/<inferred-project>/decisions/` whose
  frontmatter has `type: decision`.
- `Failed: 0`.
- `Cap reached: no`.
