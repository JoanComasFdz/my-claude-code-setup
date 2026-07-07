#!/usr/bin/env bash
# Install the standalone VS Code CLI so `code tunnel` works inside the container
# and a remote VS Code can connect to it.
#
# The downloaded binary is itself named `code`, so it is kept OFF PATH under
# /opt and exposed through thin wrappers. This avoids shadowing the `code` shim
# that the VS Code Server injects when you attach the IDE to the container.
#   - `vscode-cli`  -> the full standalone CLI (e.g. `vscode-cli serve-web`)
#   - `code-tunnel` -> shorthand for `vscode-cli tunnel` (extra args pass through)
set -euo pipefail

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) VSCODE_CLI_TARGET=cli-linux-x64 ;;
  arm64) VSCODE_CLI_TARGET=cli-linux-arm64 ;;
  *) echo "Unsupported architecture for VS Code CLI: $ARCH" >&2; exit 1 ;;
esac

mkdir -p /opt/vscode-cli
curl -fsSL "https://update.code.visualstudio.com/latest/${VSCODE_CLI_TARGET}/stable" \
  -o /tmp/vscode-cli.tar.gz
tar -xzf /tmp/vscode-cli.tar.gz -C /opt/vscode-cli
rm /tmp/vscode-cli.tar.gz

printf '%s\n' '#!/bin/sh' 'exec /opt/vscode-cli/code "$@"' > /usr/local/bin/vscode-cli
printf '%s\n' '#!/bin/sh' 'exec /opt/vscode-cli/code tunnel "$@"' > /usr/local/bin/code-tunnel
chmod +x /usr/local/bin/vscode-cli /usr/local/bin/code-tunnel
