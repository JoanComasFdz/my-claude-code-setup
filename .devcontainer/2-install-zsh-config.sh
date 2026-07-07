#!/usr/bin/env bash
# Reproduce the host WSL zsh setup inside the container:
#   - Oh My Zsh framework + Spaceship prompt theme
#   - Plugins: git, zsh-autosuggestions, zsh-syntax-highlighting, sudo,
#     zoxide, extract, history, docker, npm
#   - zoxide (smarter `cd`) + eza (modern `ls`) binaries
#   - A .zshrc adapted from the host config (WSL-only bits like snap/nvm dropped)
#
# Runs as root during the image build: system tools go on PATH, the shell
# framework is installed into the `node` user's home, and ownership is fixed up
# at the end so the unprivileged user owns its own config.
set -euo pipefail

USER_NAME=node
USER_HOME=/home/node
ZSH_DIR="$USER_HOME/.oh-my-zsh"

# --- System tools: zoxide (apt) + eza (pinned GitHub binary) ---------------
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends zoxide
apt-get clean && rm -rf /var/lib/apt/lists/*

EZA_VERSION=0.23.4
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) EZA_TARGET=x86_64-unknown-linux-gnu ;;
  arm64) EZA_TARGET=aarch64-unknown-linux-gnu ;;
  *) echo "Unsupported architecture for eza: $ARCH" >&2; exit 1 ;;
esac
curl -fsSL "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_${EZA_TARGET}.tar.gz" \
  -o /tmp/eza.tar.gz
tar -xzf /tmp/eza.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/eza
rm /tmp/eza.tar.gz

# --- Oh My Zsh + Spaceship + custom plugins (into node's home) -------------
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR"
git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git \
  "$ZSH_DIR/custom/themes/spaceship-prompt"
ln -sf "$ZSH_DIR/custom/themes/spaceship-prompt/spaceship.zsh-theme" \
  "$ZSH_DIR/custom/themes/spaceship.zsh-theme"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_DIR/custom/plugins/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_DIR/custom/plugins/zsh-syntax-highlighting"

# Make zsh the default login shell for the node user.
chsh -s "$(command -v zsh)" "$USER_NAME"

# --- .zshrc (adapted from the host WSL config) -----------------------------
cat > "$USER_HOME/.zshrc" <<'ZSHRC'
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.local/bin:$PATH"

# Theme
ZSH_THEME="spaceship"

# Disable auto-setting terminal title
DISABLE_AUTO_TITLE="true"

# Persist shell history on the devcontainer volume mounted at /commandhistory
export HISTFILE=/commandhistory/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000
setopt SHARE_HISTORY

# Plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  sudo
  zoxide
  extract
  history
  docker
  npm
)

# Spaceship configuration (BEFORE sourcing oh-my-zsh)
SPACESHIP_USER_SHOW=always
SPACESHIP_CHAR_SYMBOL="❯"
SPACESHIP_CHAR_SUFFIX=" "
SPACESHIP_EXEC_TIME_SHOW=true
SPACESHIP_EXEC_TIME_ELAPSED=1
SPACESHIP_EXEC_TIME_PRECISION=2
SPACESHIP_EXEC_TIME_PREFIX="⏱ "
SPACESHIP_EXEC_TIME_SUFFIX=" "
SPACESHIP_EXEC_TIME_COLOR="yellow"

SPACESHIP_PROMPT_ORDER=(
  user
  dir
  host
  git
  exec_time
  line_sep
  jobs
  exit_code
  char
)

# Source Oh My Zsh (THIS MUST BE AFTER SPACESHIP CONFIG)
source $ZSH/oh-my-zsh.sh

# zoxide (smarter cd)
eval "$(zoxide init zsh)"

# eza alias (modern ls)
alias l='eza --long --all --header --icons --group-directories-first --no-permissions --no-user'

# Editor
export EDITOR="code --wait"

# Tips on startup
echo "Tip: use 'z' instead of 'cd' to change directories!"
echo "Tip: use 'l' instead of 'ls' to explore directories!"
ZSHRC

# --- Ownership -------------------------------------------------------------
chown -R "$USER_NAME:$USER_NAME" "$ZSH_DIR" "$USER_HOME/.zshrc"
