#!/usr/bin/env bash
# tests/smoke/run-smoke.sh
# Provision/verify/teardown a sandbox for end-to-end smoke testing.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SANDBOX="$REPO_ROOT/tests/smoke/.sandbox"
FAKE_HOME="$SANDBOX/HOME"
VAULT="$FAKE_HOME/Documents/Obsidian/Test"

case "${1:-}" in
  provision)
    rm -rf "$SANDBOX"
    mkdir -p "$FAKE_HOME/.claude/skills" "$FAKE_HOME/.claude/commands" \
             "$FAKE_HOME/.claude/hooks" "$VAULT/.obsidian"
    printf '{}\n' > "$FAKE_HOME/.claude/settings.json"
    printf '{}\n' > "$VAULT/.obsidian/app.json"
    echo "Sandbox at: $SANDBOX"
    echo "Set HOME=$FAKE_HOME and run claude in $VAULT to install."
    ;;
  verify)
    fail=0
    check() {
      if eval "$2"; then
        printf '✓ %s\n' "$1"
      else
        printf '✗ %s\n' "$1"
        fail=1
      fi
    }
    check "CLAUDE.md cortex block present" \
      "grep -qF '<!-- claude-cortex:begin v1 -->' '$FAKE_HOME/.claude/CLAUDE.md'"
    check "skill installed" \
      "test -f '$FAKE_HOME/.claude/skills/claude-cortex/claude-cortex.md'"
    check "/save-to-inbox installed" \
      "test -f '$FAKE_HOME/.claude/commands/save-to-inbox.md'"
    check "/retro installed" \
      "test -f '$FAKE_HOME/.claude/commands/retro.md'"
    check "hook installed" \
      "test -x '$FAKE_HOME/.claude/hooks/claude-cortex-session-start.sh'"
    check "settings.json has SessionStart hook" \
      "jq -e '.hooks.SessionStart[].hooks[].command' '$FAKE_HOME/.claude/settings.json' | grep -q claude-cortex"
    check "vault skeleton present" \
      "test -f '$VAULT/_index.md' && test -d '$VAULT/inbox' && test -d '$VAULT/projects'"
    check "vault config present" \
      "test -f '$VAULT/.claude-cortex/config.yaml'"
    check "vault config has karpathy-lite preset" \
      "grep -q '^preset: karpathy-lite$' '$VAULT/.claude-cortex/config.yaml'"
    check "vault config has version" \
      "grep -q '^version: 0.1.0$' '$VAULT/.claude-cortex/config.yaml'"
    check "sentinel hooks dir present" \
      "test -d '$FAKE_HOME/.claude/sentinel/hooks'"
    check "sentinel _lib.sh present" \
      "test -f '$FAKE_HOME/.claude/sentinel/hooks/_lib.sh'"
    for h in session-start user-prompt-submit post-tool-use stop session-end; do
      check "sentinel hook $h.sh executable" \
        "test -x '$FAKE_HOME/.claude/sentinel/hooks/$h.sh'"
    done
    check "sentinel _lib.sh not executable" \
      "! test -x '$FAKE_HOME/.claude/sentinel/hooks/_lib.sh'"
    check "sentinel observers.yaml present" \
      "test -f '$FAKE_HOME/.claude/sentinel/observers.yaml'"
    check "sentinel config.yaml present" \
      "test -f '$FAKE_HOME/.claude/sentinel/config.yaml'"
    check "sentinel cortex-capture system-prompt present" \
      "test -f '$FAKE_HOME/.claude/sentinel/observers/cortex-capture/system-prompt.md'"
    check "observers.yaml VAULT_PATH substituted" \
      "! grep -q '{{VAULT_PATH}}' '$FAKE_HOME/.claude/sentinel/observers.yaml'"
    for ev in SessionStart UserPromptSubmit PostToolUse Stop SessionEnd; do
      check "sentinel $ev hook in settings.json" \
        "jq -e '.hooks.$ev[]?.hooks[]? | select(.command | contains(\"sentinel/hooks/\"))' '$FAKE_HOME/.claude/settings.json' >/dev/null"
    done
    check "sentinel/log permission entry present" \
      "jq -e '.permissions.allow | any(. == \"Read(~/.claude/sentinel/log/**)\")'  '$FAKE_HOME/.claude/settings.json' >/dev/null"
    check "sentinel/events permission entry present" \
      "jq -e '.permissions.allow | any(. == \"Read(~/.claude/sentinel/events/**)\")'  '$FAKE_HOME/.claude/settings.json' >/dev/null"
    if [ $fail -eq 0 ]; then
      echo
      echo "All smoke checks passed."
    else
      echo
      echo "Some checks failed. Investigate."
      exit 1
    fi
    ;;
  teardown)
    rm -rf "$SANDBOX"
    echo "Sandbox removed."
    ;;
  *)
    echo "Usage: $0 {provision|verify|teardown}"
    exit 1
    ;;
esac
