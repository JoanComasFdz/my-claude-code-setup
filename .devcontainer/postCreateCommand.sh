#!/usr/bin/env bash
# Dev container postCreate entrypoint.
#
# Runs once, inside the container, right after it is created and all mounts
# (including the persisted ~/.claude volume) are in place. Add one-time runtime
# setup steps here. Unlike the numbered scripts baked into the image at build
# time (1-*, 2-*), work that must land on the ~/.claude volume has to run here,
# because that volume is only mounted at runtime.
#
# Invoked from devcontainer.json:
#   "postCreateCommand": "bash .devcontainer/postCreateCommand.sh"
set -euo pipefail

# Resolve this script's own directory so sibling steps are found regardless of
# the working directory postCreate happens to run from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "▶ postCreate: running dev container setup…"

# --- Claude Code: plugins + MCP servers ------------------------------------
# Best-effort: a failure here (e.g. no network to clone a marketplace) must NOT
# abort container creation, so we swallow a non-zero exit. The step logs its own
# detailed, per-item errors.
if bash "$SCRIPT_DIR/3-setup-claude-code.sh"; then
  echo "▶ postCreate: Claude Code setup done."
else
  echo "▶ postCreate: Claude Code setup reported issues (continuing anyway)." >&2
fi

# --- Claude Code: status line (ccstatusline) -------------------------------
if bash "$SCRIPT_DIR/4-setup-ccstatusline.sh"; then
  echo "▶ postCreate: ccstatusline setup done."
else
  echo "▶ postCreate: ccstatusline setup reported issues (continuing anyway)." >&2
fi

echo "▶ postCreate: complete."
