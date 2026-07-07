# Dev Container

A ready-to-use, isolated Linux box for working on this repo with **Claude Code**.
Open the folder in VS Code and choose **"Reopen in Container"** — everything below
is set up for you, the same way every time.

## Why use it

- **Safe sandbox** — Claude Code runs inside the container, not on your machine,
  so it can work freely without touching your host system.
- **No setup** — the tools, shell, and editor config are baked into the image.
- **Same for everyone** — anyone who opens the repo gets an identical environment.

## What's inside

- **Claude Code** — installed globally and ready to run (`claude`).
- **Node.js 20** — the base runtime.
- **Common Linux tools** — `git`, `gh`, `jq`, `fzf`, `vim`, `nano`, `curl`, `wget`,
  `delta` (nicer git diffs), and more.
- **VS Code CLI** — lets you connect from anywhere over a tunnel
  (`code-tunnel`, or `vscode-cli` for the full CLI).
- **Zsh, like your host** — Oh My Zsh + Spaceship prompt with the same plugins:
  `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zoxide` (`z` to jump
  around), `eza` (the `l` alias), and more. Zsh is the default shell.

## Nice touches

- **Claude runs unattended** — inside the sandbox, permission prompts are turned
  off (`bypassPermissions`), so Claude doesn't stop to ask for approval.
- **History is kept** — your shell history survives rebuilds.
- **Config is kept** — your Claude Code login/config survives rebuilds.
- **No AI Chat pop-up** — VS Code's built-in Chat / AI-sessions panel stays
  hidden on startup, so it's out of the way.
- **Editor** — commands that open an editor (like `git commit`) use VS Code
  (`code --wait`) when you're attached to the IDE, and fall back to `nano`
  otherwise (for example over a raw tunnel).

## One-time host setup: terminal font

The Spaceship prompt and `eza` file icons use **Nerd Font** glyphs. VS Code
renders the integrated terminal on your **host machine**, not in the container,
so the font must be installed on the host (installing it in the container has no
effect). This is the one step that can't be baked into the image.

Install any Nerd Font on your host, then make sure its name is first in the
`terminal.integrated.fontFamily` list in `devcontainer.json`. On Windows (WSL2),
install it into **Windows**, not inside WSL or the container:

- **Scoop:** `scoop bucket add nerd-fonts && scoop install FiraCode-NF`
- **oh-my-posh:** `oh-my-posh font install FiraCode`
- **Manual:** download from <https://www.nerdfonts.com/font-downloads>, unzip,
  select the `.ttf` files, right-click → *Install*.

Restart VS Code after installing. Any Nerd Font works — just match the name.

## Files

- `devcontainer.json` — VS Code settings, extensions, and mounts.
- `Dockerfile` — how the image is built.
- `1-install-vscode-cli.sh` — installs the VS Code CLI (for tunnels).
- `2-install-zsh-config.sh` — installs Zsh, Oh My Zsh, Spaceship, and plugins.
