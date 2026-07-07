# visual-review

Renders **already-gathered** code-review findings (a conventions audit, a PR review, …) into one **self-contained, interactive HTML report** — a scannable dashboard instead of a compact bullet list. You author a `findings.json`; a pinned renderer draws it. You never hand-write HTML, so every report looks the same.

It does **not** run the review — gather findings first (`/code-review`, or reading code against a ruleset). See `SKILL.md` for the `findings.json` contract; copy `example-findings.json` as the starting shape.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | When-to-use + the `findings.json` content contract |
| `template.html` | The pinned renderer — all CSS + vanilla JS, inline (edit findings, not this) |
| `build.js` | `node build.js findings.json out.html` — injects the data into the template |
| `serve.js` | Optional viewer that adds click-to-open-in-editor (see below) |
| `example-findings.json` | A filled-in sample; doubles as a smoke test |

## What the report shows

- **Stats strip** — auto totals (findings · files affected · areas clean).
- **Filters** — severity chips + a summarized **directory tree** (single-child folders collapsed); click a folder/file to filter the findings.
- **Finding cards** (collapsible, grouped by severity) — quoted convention/basis, the **current code in context** with notes anchored to the offending lines, a **before/after diff** (stacked), and for signature changes a **blast-radius** list of real callers. Deep-linkable via `#finding-<id>`.
- Compact **Judgment calls**, **Non-findings**, and **Checked & clean** sections.

## Usage

```bash
# 1. author findings.json per SKILL.md (copy example-findings.json)
# 2. build into the repo tree
node .claude/skills/visual-review/build.js findings.json \
     variance-lots-check/conventions-compliance-review-$(date +%F).html
# 3. view it (see Dependencies)
node .claude/skills/visual-review/serve.js .   # from the repo root
```

## Dependencies

Tiered — each level is optional, the report degrades gracefully without it.

1. **Build the report — Node.js only.** `build.js` and `serve.js` use Node built-ins; **no `npm install`, no packages, no network, no MCP/CLI**.
2. **View it — a JavaScript-capable viewer.** The report runs client-side JS, so open it in a browser, VS Code **"Simple Browser: Show"**, or the Live Preview extension — not a plain terminal. Serve from the **repo root** (e.g. `serve.js`, or `python3 -m http.server`) so a finding's file link resolves to real source.
3. **Click-to-open-in-editor — VS Code `code` CLI (optional).** Run `serve.js` from a **VS Code integrated terminal**: clicking a finding's location runs `code --goto <file>:<line>`, opening the real file in your editor at the line. This needs the `code` CLI on `PATH` **and** `VSCODE_IPC_HOOK_CLI` set — **both present in a VS Code devcontainer terminal, but not guaranteed elsewhere** (e.g. plain SSH, CI, a bare shell). `serve.js` prints whether it's `enabled` on startup.

   **Without it:** links still work — they display the source file as text in the browser (`serve.js` serves everything as `text/plain`, so no "Save As" download). For a **shared/hosted** report, set `meta.repoUrl` to a GitHub blob base instead, and links become `…#Lnn` on the host with a working line jump.

Output `.html` files are generated artifacts — commit them or add `*.html` to `.gitignore`.
