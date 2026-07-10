#!/usr/bin/env bash
# Configure Claude Code's status line to use ccstatusline.
#
# Two independent pieces:
#   1. Point Claude Code at ccstatusline — write a `statusLine` command into the
#      user settings.json (~/.claude/settings.json). This is what actually makes
#      the status line appear.
#   2. (Optional) Seed ccstatusline's own config — if a curated
#      `.devcontainer/ccstatusline.settings.json` exists, copy it to
#      ~/.config/ccstatusline/settings.json. Without it, ccstatusline uses its
#      built-in defaults.
#
# Runs at postCreate for the same reason as 3-setup-claude-code.sh: the Claude
# settings live on the persisted ~/.claude volume, which only exists at runtime.
# ccstatusline's own config dir (~/.config/ccstatusline) is NOT on that volume,
# so piece 2 is re-applied on every container (re)create.
#
# Same design as 3-setup-claude-code.sh: idempotent, fault-tolerant, no `set -e`
# so every step is attempted. Runs as the `node` user, so no chown is needed —
# everything it creates is already node-owned.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Config ----------------------------------------------------------------
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CCSTATUSLINE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ccstatusline"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CCSTATUSLINE_SRC="$SCRIPT_DIR/ccstatusline.settings.json"

FAILURES=0

# --- Logging ---------------------------------------------------------------
log()  { printf '\033[0;36m[ccstatusline]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[ccstatusline] ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[ccstatusline] ! %s\033[0m\n' "$*" >&2; }
err()  { printf '\033[0;31m[ccstatusline] ✗ %s\033[0m\n' "$*" >&2; }

fail_step() { err "$1"; FAILURES=$((FAILURES + 1)); }

# --- Preflight -------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  err "\`jq\` not found on PATH — cannot edit settings.json safely."
  exit 1
fi

# --- 1. Enable ccstatusline in Claude Code settings ------------------------
# The command Claude Code runs to render the status line.
STATUSLINE_JSON='{"type":"command","command":"npx ccstatusline@latest","padding":0}'

enable_statusline() {
  log "Enabling ccstatusline in $SETTINGS_FILE…"

  if [ -f "$SETTINGS_FILE" ]; then
    if ! jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
      fail_step "settings.json is not valid JSON — leaving it untouched."
      return
    fi
    if [ "$(jq 'has("statusLine")' "$SETTINGS_FILE" 2>/dev/null)" = "true" ]; then
      log "statusLine already configured — leaving it as-is."
      return
    fi
    # Only overwrite the original once jq has produced valid output, so a jq
    # failure can never truncate an existing config.
    local tmp="$SETTINGS_FILE.tmp"
    if jq --argjson sl "$STATUSLINE_JSON" '.statusLine = $sl' "$SETTINGS_FILE" > "$tmp"; then
      mv "$tmp" "$SETTINGS_FILE"
      ok "Added statusLine to settings.json."
    else
      rm -f "$tmp"
      fail_step "Failed to update settings.json."
    fi
  else
    mkdir -p "$CLAUDE_DIR"
    if jq -n --argjson sl "$STATUSLINE_JSON" '{statusLine: $sl}' > "$SETTINGS_FILE"; then
      ok "Created settings.json with statusLine."
    else
      fail_step "Failed to create settings.json."
    fi
  fi
}

# --- 2. Seed ccstatusline's own config (optional) --------------------------
seed_ccstatusline_config() {
  mkdir -p "$CCSTATUSLINE_CONFIG_DIR"
  if [ -f "$CCSTATUSLINE_SRC" ]; then
    if cp "$CCSTATUSLINE_SRC" "$CCSTATUSLINE_CONFIG_DIR/settings.json"; then
      ok "Applied ccstatusline config from ${CCSTATUSLINE_SRC##*/}."
    else
      fail_step "Failed to copy ccstatusline config."
    fi
  else
    log "No ${CCSTATUSLINE_SRC##*/} in .devcontainer — using ccstatusline defaults."
  fi
}

# --- Run -------------------------------------------------------------------
enable_statusline
seed_ccstatusline_config

if [ "$FAILURES" -gt 0 ]; then
  warn "ccstatusline setup finished with $FAILURES issue(s) — see above."
  exit 1
fi

ok "ccstatusline setup complete."
