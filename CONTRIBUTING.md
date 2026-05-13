# Contributing to Claude Cortex

Thanks for your interest. This is a v0.1.0 project; the bar for
contributions is low, and small fixes (wording, naturalness, doc nits)
are very welcome.

## Setup

You'll need:

- bash or zsh
- `jq`         (`brew install jq`)         -- required for safe settings.json edits
- `bats-core`  (`brew install bats-core`)  -- required to run unit tests
- `shellcheck` (`brew install shellcheck`) -- recommended for shell-script changes

## Tests

```bash
bats tests/*.bats              # unit tests for installer helpers + hook
bash tests/smoke/run-smoke.sh  # manual end-to-end install in a sandbox
```

The smoke test is interactive (the installer is a Claude prompt, not a
script). See `tests/smoke/README.md` for the workflow.

## What changes are welcome

- **Bug fixes** and **wording / naturalness polish**: open a PR.
- **New presets** (PARA, custom taxonomies): open an issue first so we
  can align on the shape of the preset before you write it.
- **Behavior changes** to capture, retro, or auto-stage flows: open an
  issue first -- these touch user trust and we want to talk through the
  intent before code.

## Commit style

Match the existing log: `fix(skill): ...`, `feat(installer): ...`,
`docs(readme): ...`. Conventional-commits-ish, scoped to the area
changed. Keep the subject under ~70 chars.

## Code of conduct

Be kind. Assume good faith. If something feels off, file an issue and
we'll talk.
