#!/usr/bin/env bash
# Set up Claude Code extras inside the dev container:
#   - Plugin:     superpowers   (from the obra/superpowers-marketplace catalog)
#   - MCP server: context7      (Upstash — up-to-date, version-specific library docs)
#
# WHY THIS RUNS AT postCreate (and not in the Dockerfile):
# ~/.claude is a persisted named volume (see the `mounts` in devcontainer.json).
# Plugins install into ~/.claude/plugins and the MCP config is written under the
# Claude config dir — both live on that volume. Anything written to that path
# during the image build is shadowed when the (initially empty) volume mounts
# over it at runtime, so this setup has to happen after the container exists.
#
# Design:
#   - Idempotent — safe to re-run on every container (re)create. Each item is
#     skipped when already present, so a persisted volume isn't reinstalled.
#   - Fault-tolerant — a failure in one item (e.g. a network blip while cloning
#     a marketplace) is logged and does NOT abort the others. The script exits
#     non-zero if anything failed so the caller can surface it, but these extras
#     are best-effort and never block container creation.
#   - No auth needed — adding a marketplace / installing a plugin is a git clone
#     plus a local config write, and `claude mcp add` only writes config. None of
#     these require being logged in to Claude Code, so they work at create time.
#
# Note `set -e` is deliberately NOT enabled: we want every step to be attempted
# even if an earlier one fails. Undefined-variable and pipe-failure checks stay on.
set -uo pipefail

# --- Config ----------------------------------------------------------------
SUPERPOWERS_MARKETPLACE="obra/superpowers-marketplace"   # owner/repo added as a marketplace
SUPERPOWERS_MARKETPLACE_NAME="superpowers-marketplace"   # its registered name
SUPERPOWERS_PLUGIN="superpowers@superpowers-marketplace" # plugin@marketplace to install
CONTEXT7_MCP_NAME="context7"

# Optional: export CONTEXT7_API_KEY to raise Context7's rate limits (a free key
# is available at https://context7.com/dashboard). It works fine without one.
CONTEXT7_API_KEY="${CONTEXT7_API_KEY:-}"

FAILURES=0

# --- Logging ---------------------------------------------------------------
log()  { printf '\033[0;36m[claude-setup]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[claude-setup] ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[claude-setup] ! %s\033[0m\n' "$*" >&2; }
err()  { printf '\033[0;31m[claude-setup] ✗ %s\033[0m\n' "$*" >&2; }

fail_step() { err "$1"; FAILURES=$((FAILURES + 1)); }

# --- Preflight -------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  err "\`claude\` not found on PATH — is Claude Code installed in the image?"
  exit 1
fi
log "Using $(claude --version 2>/dev/null || echo 'claude (version unknown)')"

# --- superpowers plugin ----------------------------------------------------
setup_superpowers() {
  log "Setting up the 'superpowers' plugin…"

  # 1. Register the marketplace (skip if already known to this config).
  if claude plugin marketplace list 2>/dev/null | grep -q "$SUPERPOWERS_MARKETPLACE_NAME"; then
    log "Marketplace '$SUPERPOWERS_MARKETPLACE_NAME' already registered."
  elif claude plugin marketplace add "$SUPERPOWERS_MARKETPLACE"; then
    ok "Added marketplace '$SUPERPOWERS_MARKETPLACE'."
  else
    fail_step "Could not add marketplace '$SUPERPOWERS_MARKETPLACE' (skipping plugin install)."
    return
  fi

  # 2. Install the plugin (skip if already installed).
  if claude plugin list 2>/dev/null | grep -q "superpowers"; then
    log "Plugin 'superpowers' already installed."
  elif claude plugin install "$SUPERPOWERS_PLUGIN"; then
    ok "Installed plugin '$SUPERPOWERS_PLUGIN'."
  else
    fail_step "Could not install plugin '$SUPERPOWERS_PLUGIN'."
  fi
}

# --- context7 MCP server ---------------------------------------------------
# Context7 is an MCP server, NOT a Claude Code plugin, so it is registered with
# `claude mcp add` rather than `claude plugin install`. The `--` separates
# Claude's own flags from the server launch command; any server args (like
# --api-key) belong AFTER it.
setup_context7() {
  log "Setting up the 'context7' MCP server…"

  if claude mcp list 2>/dev/null | grep -q "$CONTEXT7_MCP_NAME"; then
    log "MCP server '$CONTEXT7_MCP_NAME' already configured."
    return
  fi

  local -a cmd=(claude mcp add --scope user "$CONTEXT7_MCP_NAME" -- npx -y @upstash/context7-mcp)
  if [ -n "$CONTEXT7_API_KEY" ]; then
    cmd+=(--api-key "$CONTEXT7_API_KEY")   # passed to the context7 server (after --)
    log "Using CONTEXT7_API_KEY from the environment."
  fi

  if "${cmd[@]}"; then
    ok "Configured MCP server '$CONTEXT7_MCP_NAME'."
  else
    fail_step "Could not configure MCP server '$CONTEXT7_MCP_NAME'."
  fi
}

# --- Run -------------------------------------------------------------------
setup_superpowers
setup_context7

if [ "$FAILURES" -gt 0 ]; then
  warn "Claude Code setup finished with $FAILURES issue(s) — see above."
  exit 1
fi

ok "Claude Code setup complete."
