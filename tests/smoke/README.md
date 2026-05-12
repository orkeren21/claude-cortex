# Smoke test

Manual end-to-end verification. The installer is interactive (Claude reads it),
so this can't be fully automated, but the scaffolding here provisions a clean
sandbox.

## Run

```bash
bash tests/smoke/run-smoke.sh provision
```

This creates:
- `tests/smoke/.sandbox/HOME/` — fake home dir
- `tests/smoke/.sandbox/HOME/.claude/` — fake Claude config
- `tests/smoke/.sandbox/HOME/Documents/Obsidian/Test/` — fake vault

Then in a separate terminal, set:

```bash
export HOME=/full/path/to/tests/smoke/.sandbox/HOME
cd $HOME/Documents/Obsidian/Test
claude
```

Paste the install prompt from the README, run through the installer.

After install, verify with:

```bash
bash tests/smoke/run-smoke.sh verify
```

Tear down:

```bash
bash tests/smoke/run-smoke.sh teardown
```
