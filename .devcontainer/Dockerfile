FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  jq \
  nano \
  vim \
  wget \
  curl \
  ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

ENV DEVCONTAINER=true

RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# VS Code CLI (standalone) — enables `code tunnel` so a remote VS Code can
# connect to this container. Step lives in its own script for clarity/reuse.
COPY 1-install-vscode-cli.sh /tmp/1-install-vscode-cli.sh
RUN chmod +x /tmp/1-install-vscode-cli.sh && \
  /tmp/1-install-vscode-cli.sh && \
  rm /tmp/1-install-vscode-cli.sh

# Zsh: Oh My Zsh + Spaceship prompt + plugins + zoxide/eza. Mirrors the host
# WSL setup. Runs as root; installs into the node user's home (step 2).
COPY 2-install-zsh-config.sh /tmp/2-install-zsh-config.sh
RUN chmod +x /tmp/2-install-zsh-config.sh && \
  /tmp/2-install-zsh-config.sh && \
  rm /tmp/2-install-zsh-config.sh

# Managed settings: default to bypassPermissions so `claude` runs unattended.
# Safe because the container is the sandbox — this is the main reason to use it.
# Highest-precedence file in the Claude Code settings hierarchy.
RUN mkdir -p /etc/claude-code && \
  printf '%s\n' '{' '  "permissions": {' '    "defaultMode": "bypassPermissions"' '  }' '}' \
    > /etc/claude-code/managed-settings.json

USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
