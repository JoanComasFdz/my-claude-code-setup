---
name: visual-review
description: Use when writing up the findings of a completed code review as a report document — a conventions-compliance audit of a source tree, a PR review, or similar — and a compact bullet list hides too much local context. Not for running the review or entering review mode. Renders findings into a self-contained interactive HTML report (zero deps, offline).
---

# Visual Review

## Overview

Renders **already-gathered** code-review findings into one self-contained, interactive HTML report — a scannable dashboard of collapsible finding cards with before/after diffs, code-in-context, and per-signature blast-radius. It does **not** find the issues; gather those first (`/code-review`, or reading the code against a ruleset). Inspired by visual-plan/visual-recap's data→renderer model, but with **no MCP, no CLI, no network** — just Node's built-in `fs`.

**The one rule that makes it work: you author *data*, never HTML.** You write a `findings.json`; a pinned `template.html` renders it. That is what keeps every report identical instead of hand-rolled "HTML slop, different every time." Do not open `template.html` to tweak a report — change the JSON.

## Workflow

1. **Gather findings** (out of scope for this skill) against the ruleset — e.g. `variance-lots-check/CONVENTIONS.md`.
2. **Author `findings.json`** following the content contract below. Copy `example-findings.json` in this skill directory as the canonical shape and replace its contents.
3. **Build it** into the repo tree (so the root-relative file links resolve to real source):
   ```bash
   node .claude/skills/visual-review/build.js findings.json \
        variance-lots-check/conventions-compliance-review-$(date +%F).html
   ```
4. **Show it.** The report renders client-side, so it needs a browser or JS-executing preview — not a plain terminal. Serve the **repo root** with the bundled server, run from a **VS Code integrated terminal** (so `code` is on PATH):
   ```bash
   node .claude/skills/visual-review/serve.js .   # from the repo root; PORT=8000 by default
   # → http://localhost:8000/variance-lots-check/conventions-compliance-review-<date>.html
   ```
   Open that URL in a browser or VS Code **"Simple Browser: Show"**. `serve.js` also exposes `/__open`, so clicking a finding's location **opens the real source file in your VS Code editor at the line** (`code --goto`; needs `VSCODE_IPC_HOOK_CLI`, present in a devcontainer terminal). Plain `python3 -m http.server 8000` or the Live Server extension also work, but then a link just displays the file as text in the browser (no editor jump, and Live Server may download `.cs`). For a shared/hosted report, set `meta.repoUrl` to a GitHub blob base → links become `…#Lnn` on the host.

Output default is `<subproject>/<reportSlug>-<date>.html`. It's a generated artifact; add `*.html` to `.gitignore` if you don't want it committed.

## The finding content contract (what every actionable finding MUST carry)

Each finding is a JSON object. Fill these fields — they are the whole point of the format (each one is a thing the old compact reports dropped):

- `id` — kebab-case slug, **required**; it becomes the card's `#finding-<id>` anchor, so a single finding can be deep-linked.
- `severity` `"major" | "minor" | "info"`, `title` (one-line defect), `location` `{ path, line, endLine? }` — `line` is the **defect line** the primary annotation anchors to (not a method-declaration line far above the fault); `current` must contain it. Links are built from `path`+`line`, so there is **no `href` field**. Set `meta.repoUrl` (a repo-host base, e.g. a GitHub blob URL) for absolute links with a working `#Lnn`; without it, links are root-relative and resolve when the report is served from the repo root.
- `convention` — the **quoted** rule text it violates for a genuine breach; for a code-quality nit that isn't a rule, write a short descriptive basis instead of a fabricated quote. `what` — 1–2 sentences on the concrete failure.
- `kind` `"line" | "signature" | "function"` — this drives what context is required (table below).
- `current` — the **real** code in context (never paraphrased): `{ lang?, startLine, code, annotations:[{lines,label?,note}] }`. `lang?` is an optional caption; `startLine` is the true first line so the gutter numbers match the file. Each annotation anchors a margin note to a line — `lines` is a single line (`"59"`) or a range (`"59-60"`); the highlight anchors to the first line of the range.
- `suggestion` — `{ summary, before, after, callerBefore?, callerAfter? }` (no `lang`). `before` is real source; `after` is your **proposed** fix (authored — it need not be lifted from the file). The caller pair shows how a caller updates.
- `notes?` — blast radius / "same gap in N other files".

**Code blocks must be the actual source lines** (`current.code`, `callers[].snippet`, `suggestion.before`) — read the file, don't reconstruct from memory (visual-recap's "true by construction" rule). **Then strip the common leading indentation** so the block starts at column 0; `startLine` keeps the gutter correct. And **don't stretch `current.code` across unrelated lines**: when the cause and its effect are far apart (e.g. a discarded result on line 59 that only bites on line 82), keep `current` on the cause site and name the distant effect site by `path:line` in the annotation `note` or in `notes` — annotations can only anchor to lines actually shown in the block.

### Context required by finding kind

| `kind` | `current` shows | also required |
|---|---|---|
| `line` | the enclosing function's relevant lines that change with it | — |
| `signature` | the signature (+ method body if short) | `symbol` + `callers:[{name?,path,line,snippet}]` — each a real call site (`snippet` is real source); drives the blast-radius diagram |
| `function` | the whole function | — |

Top-level: `meta` (`title, subproject, reportSlug, ruleset:{label,href}, scope, date, summary, repoUrl?`) and `findings[]` are required; the compact sections `judgmentCalls[]` (decisions punted to the user), `nonFindings[]` (looked, compliant), and `clean[]` (`{area,note}`) are **optional** — omit them or pass `[]`. **`meta.summary` is 1–2 qualitative sentences** (the takeaway / highest-value fix) — do **not** restate per-finding detail or counts; the totals (findings, affected files) are computed and shown automatically. See `example-findings.json` for a filled-in instance.

## Common mistakes

- **Editing `template.html` per report.** Don't — author JSON only; the template is fixed so reports stay consistent.
- **Paraphrasing `current`/`snippet` code.** Read the real lines; a diff built from imagined code is worse than no diff.
- **Omitting `callers` on a `signature` finding.** The blast-radius is the "how does this affect its surroundings" the report exists to show — a signature change with no callers listed is incomplete.
- **Using this to *run* the review.** It only renders findings you already have.
