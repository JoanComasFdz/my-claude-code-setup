# Code-review skill family — design spec

> Status: **draft for review** · 2026-07-02 · rev 2026-07-06 — **scope narrowed to code-only**: the architecture lens was removed entirely; this family reviews *how code is written vs. how it should be written*, nothing above file grain.
> **Self-contained by intent:** terms that emerged during design (premature completion, completion criterion, model/user-invoked, …) are defined briefly where first used, so this reads without any prior conversation.
> Location: developed in `__code-review-skill/` because the family is **app-agnostic** — nothing is specific to this repo. Final home TBD (a user-level skills dir, or its own repo). Not part of the `variance-lots-check` subproject.

## 1. Problem

Recurring task: *"review a codebase against written guidelines and surface every violation."* Doing it by ad-hoc prompting ("use subagents to scan the code and check it against CONVENTIONS.md") is **not thorough** — it churns: prompt → findings → fix → prompt → *new* findings → fix, apparently forever.

**Root cause — the prompt asks the model to *search*, and an open-ended search *samples* instead of *enumerating*.** It applies the rules that come to mind to the files it happens to read closely, surfaces a plausible subset, and stops. Each run draws a different sample, so next round's "new" findings are mostly **missed-first-time**, not newly created. That is **premature completion**: the agent treats a unit of work as done when the output *feels* complete rather than when coverage *is* complete. Five concrete gaps feed it:

1. No enumerated rule set — salient rules get applied, the rest dropped.
2. No enumerated file set / coverage record — "thorough" is unmeasured, so it stops when output feels done.
3. Context dilution — one agent holding 40+ files and 20 rules degrades; later files get shallow checks.
4. No stop condition, no dedup across runs — each run is an independent lossy sample.
5. No decidability check on the rules — rules that *can't* be decided at file grain (architectural, whole-graph) get smeared into the same pass and end up half-checked, instead of being explicitly declared out of scope.

## 2. Core idea

Thoroughness is a **coverage problem**, fixed by structure, not by a better prompt:

```
 <scope> ──enumerate──▶ F files          guidelines ──validate──▶ R rules
             │                                        │
             └──────────────────┬─────────────────────┘
                                ▼
              the (files × rules) matrix — F × R cells,
         one agent per file fills its ROW: an outcome per cell
                                │
                │ rule-1     rule-2      rule-3
        file-A  │ clean      violation   n/a ("no DUs in this file")
        file-B  │ clean      clean       violation
        file-C  │ (missing) ◀── gap → re-dispatch file-C's agent (bounded retries, §3.3)
                                │
                                ▼
          adversarial verify: a skeptic attacks every violation —
          it stands, or its cell flips  violation → refuted  (§4)
                                │
                                ▼
        receipt (ships in the report):  "F files × R rules = C cells,
        A applicable, V confirmed, X refuted, 0 gaps"
```

- **The review is a (files × rules) matrix.** Enumerate the files, enumerate the rules, and for each file check *every* applicable rule, recording the result. The matrix is **complete by construction in one pass** — that is what ends the churn. What makes each unit actually finish is a sharp **completion criterion** — *the condition the agent judges "done" against.* Make it **checkable** (can the agent tell done from not-done?) and **exhaustive** ("every rule evaluated against this file", not "a list of issues"). A vague criterion is exactly what lets premature completion in; an exhaustive one binds the whole matrix. (No "loop until nothing new appears" needed — that was a crutch for the sampling model.)
- **Exhaustiveness must be *provable*, not asserted.** "We checked everything" is worthless unless it can be shown, so the matrix is emitted **as data**: every file-agent records the **outcome of every (file × rule) cell** — clean, violation, or n/a; the fourth state, **refuted**, is applied by the script after the skeptic pass (§4). The orchestration script **reconciles** the recorded cells against the independently-enumerated inventory of files and rules. A missing cell is a **gap** the run must fill before it can claim done. The filled, gap-free matrix — *"F files × R rules = C cells, 0 gaps"* — **is** the proof, and it ships in the report.
- **What the proof proves — and doesn't.** The gap-free matrix proves **coverage**: every cell was adjudicated. It does **not** prove each adjudication is *correct*. Correctness is guarded per error direction: false violations → the run-time adversarial skeptic (§4); false clean/n/a → the planted-violation answer-key fixtures at skill-build time (§8) **and** the `--deep` run-time spot check over sampled clean/n/a cells (§4); and every n/a additionally carries a mandatory recorded reason (§6), so inapplicability is always auditable. The report's receipt claims coverage, nothing more.
- **Actionable rules make the fan-out reproducible.** Parallel per-file agents drift because a vague rule invites N interpretations; a *crisp, atomic, file-grain-decidable* rule collapses that variance. So validating rules for actionability isn't hygiene — it is what makes the matrix *trustworthy*.
- **Two parameterized interfaces**, nothing app-specific baked in: a **guidelines file** (in) and a **findings JSON** (out — rendered by `visual-review`).

**The artifact map** — every file a run generates, in one place (schemas: §6; how they're produced: §3.5):

```
.review/                         ← at the repo root; self-ignoring (the script drops a
                                   .review/.gitignore containing "*" on first run)
.review/<YYYY-MM-DD-HHMMSS>/     ← per-run working dir, isolated by the <run-id>
                                   (a full timestamp)
  rules.json                     JSON — the validated rule set; written once by the
                                        validator gate, read by every file-agent dispatch
  inventory.json                 JSON — the expected grid: scope, exclude globs, enumerated
                                        files, rule ids; written by the script
  rows/<relative-path>.json      JSON — one matrix row per reviewed file, mirroring the
                                        source tree; authored by that file's agent,
                                        persisted by the script (§3.5); transient audit trail
  code-findings.json             JSON — findings + coverage grid + totals + gaps; single
                                        writer: the script; the one input to build.js
<your-output-path>/
  …-review-<date>.html           HTML — the final self-contained interactive report
                                        (rendered by visual-review's build.js)

standalone guideline-validator run (no run dir): rules.json + a validation report,
written next to the guidelines input.
```

## 3. The family

```
        guidelines file  (single source of truth: general + actionable)
                 │
  /code-review (master)  ⟨ <scope>, --exclude <glob…>, --guidelines <file|folder>, --deep ⟩
     1. gate: run guideline-validator → rules.json into the run dir
        ── quality issue? → report + STOP  (out-of-scope rules: excluded + reported)
     2. file-code-review — per-file fan-out over the validated rules
     3. reconcile coverage (0 gaps, bounded retries) → adversarial verify
     4. → code-findings.json (findings + coverage) → render (visual-review build.js)
```

### 3.0 Invocation: what is a skill, what is a file

A **skill** is a markdown instruction sheet a human runs by typing `/name`. A skill's **description** field is what *additionally* lets the **agent** reach it on its own — the model firing it autonomously, or one skill invoking another. Keeping the description ("**model-invoked**") therefore costs **context load**: the description sits in the model's context *every turn*, used or not. Dropping the description ("**user-invoked**") means only a human typing `/name` can reach it — zero context load, but nothing else can invoke it.

This family deliberately carries **no model-invoked skills**: nothing auto-fires, nothing pays standing context load, everything is triggered by you with `/`. The master orchestrates by **reading files and running scripts — never skill-to-skill invocation** (a user-invoked skill can't be fired by another skill, and doesn't need to be, because reading its file works).

| Component | You type `/` | Master needs it | What it is |
|---|---|---|---|
| **`code-review`** (master) | ✓ | — | user-invoked skill |
| **`guideline-validator`** | ✓ (lint guidelines standalone) | ✓ (gate) | user-invoked skill; the gate **dispatches an agent on its `SKILL.md`** as the procedure (§3.5) |
| **`visual-review`** | ✓ (render any findings) | ✓ (final render) | user-invoked skill + `build.js`; master **runs `build.js`** directly |
| **`file-code-review`** | — | ✓ | **not a skill** — a procedure file the master reads |

Each procedure lives in exactly one file (**single source of truth**): the human runs `guideline-validator`, the master reads that same file; the review procedure lives once inside the master's folder. Promoting a procedure file to a `/`-callable skill later is trivial *if* a standalone use appears — so we don't pay for reach we don't use.

### 3.1 `guideline-validator`
Reads the guidelines input and turns it into a validated rule set — extraction follows the input shape (§6: single file → many extracted rules; folder → one rule per file). Then it lints each rule:
- **Actionable** — atomic and **decidable at file grain**: *could a reviewer decide "violated / not violated" for one file, with bounded judgment, reading at most that file plus its immediate callers/callees?* Two distinct failure verdicts fall out of this one test:
  - ⛔ **reject** — composite/unbounded rules ("apply SOLID", "use clean architecture", "keep it simple") that demand whole-paradigm interpretation and let both sides argue forever;
  - 🚫 **out of scope** — *sound rule, wrong tool*: rules that are crisp but need more than file-grain context to decide (dependency direction, module boundaries, layering — the offending `import` is visible in a file, but *interpreting* it takes a repo-level map of what counts as which layer). **Not a hard stop:** the rule is **excluded from `rules.json` and reported loudly** — by the validator, and again in the final report (*"S rules out of scope, unchecked"*). Real guideline docs legitimately mix such rules in (they serve human readers too); exclude-and-declare lets the tool run on them as-is, without ever silently padding the matrix as n/a-everywhere.
- **No contradictions** — e.g. "return early" vs "nesting up to 3 ifs is fine".
- **No overlaps** — e.g. "one if-level" vs "return early" (redundant → double-counted findings).

**Behaviour — a hard gate, the same shape as plan-review before plan-execution** (superpowers:executing-plans: *read → review critically → any concern? report + STOP → proceed only when clean → re-review after the human revises*). The validator only *validates* — it never rewrites the rulebook. **Any quality problem** — a composite/unbounded rule, a contradiction, *or* a borderline overlap suspect — is a **hard stop**: it reports everything and refuses to proceed, because reviewing against a rulebook like that makes the results untrustworthy. **Out-of-scope rules are the deliberate exception** — they don't damage the checkable rule set, so they exclude-and-report instead of blocking (above). The human edits the guidelines and re-runs; validator-feedback + human-editing *is* the authoring loop.

**Output — `rules.json`, validated fresh every run.** On a clean pass the validator emits **`rules.json`** (§6); a standalone run also writes the human-readable validation report (locations: the artifact map, §2). A master run writes no separate report file — a hard stop surfaces the problems directly in the gate's output, and the out-of-scope list travels inside `rules.json` to the final report (§6). Guidelines can change at any moment, so the gate re-validates at the start of every run; within a run, validation happens exactly **once** — the gate writes `rules.json` into the run dir (§3.5) and every file-agent dispatch reads that same copy, so N agents never mean N extractions and all agents see byte-identical rules.

Example verdicts (these double as the validator's test fixture, §8):

| Candidate rule | Verdict | Reason |
|---|---|---|
| "Name functions with a verb" | ✅ actionable | atomic, decidable at file grain |
| "Apply SOLID / use clean architecture" | ⛔ reject | composite/unbounded — whole-paradigm |
| "The domain must not depend on infrastructure" | 🚫 out of scope | needs a repo-level layer map to interpret — excluded + reported, run proceeds |
| "Return early" + "nesting up to 3 ifs is fine" | ⛔ contradiction | can't honour both |
| "One if-level" + "return early" | ⚠ overlap | same defect counted twice |

### 3.2 `file-code-review` (procedure file the master reads)
Per-file fan-out over the validated rules:
1. Enumerate the in-scope files — exactly what `<scope>` minus the declared `--exclude` globs (§3.3) resolves to. Fully deterministic: a glob either matches or it doesn't. There is **no built-in tests/build/generated exclusion engine**: scope and declared excludes are the only filter, so nothing is silently dropped by a heuristic the caller can't see.
2. Spawn **one subagent per file.** The separate context per file isn't only for focus: hiding the rest of the run behind a real context boundary is what actually prevents premature completion — an inline loop keeps the remaining work in view and invites rushing. Hand each agent the full crisp rule set.
3. Each agent reads its file fully and, rule by rule, records the **outcome of every rule** — *clean*, *violation* (line + evidence), or *n/a* (no applicable site in this file, with a one-line reason) — producing the file's **complete matrix row**, not just the hits.
4. Each agent returns its row as a **shard** (§3.5); the script assembles all rows into the single `code-findings.json` (findings **and** the coverage grid).

**Context pulls are read-only.** A rule that can't be decided from the file alone lets the agent pull in the specific context it needs — callers and callees resolved via an **LSP where the environment provides one** (find-references, go-to-definition), falling back to import-following and search where not — and read it **fully** before ruling. But pulled context is for *understanding and reporting only*: the agent **never records findings against any file but its own**. Two consequences: (a) **single reporter by construction** — every violation has exactly one possible reporter, the owning file's agent, so within-run double counting is impossible; a caller-side misuse is still caught, because the caller's file gets its own agent; (b) **blast-radius enrichment** (listing which other code a signature change would ripple to) is the same category of read — reporting sugar for the fix, never a source of findings.

**Completion criterion (each file-agent) — checkable + exhaustive:** *done* = every rule in the set has been evaluated against this file and its **outcome recorded** (clean, violation-with-evidence, or n/a-with-reason) — the full row, **not** "some issues found." Recording the clean cells too is exactly what makes coverage *provable* (§2), and it is the direct antidote to the churn (§1).

### 3.3 `code-review` (master orchestrator)
A **recipe the agent follows**, not an engine — the sheet that sequences the others and uses subagents as the muscle for the per-file fan-out (run via a pinned Workflow script — §3.5). **User-invoked** (you always type `/code-review`); it orchestrates by reading procedure files and running scripts (§3.0), not by invoking other skills. (Known and accepted: some harnesses ship a built-in `/code-review`; deployed there, this skill shadows it. Revisit the name only if that bites in practice.)
- **Parameters:** `<scope>` (path/glob to review), `--exclude <glob>` (repeatable — declared exclusions, **relative to the scope root**, e.g. `**/tests/**`, `**/*.Tests/**`), `--guidelines <path>` (a markdown **file** → many rules extracted, *or* a **folder** → one rule per file; §6), `--deep` (optional — higher-confidence audit, see §4), `--out <path>` (optional — where the final HTML lands; default: the current directory, named `…-review-<date>.html`), and `--concurrency K` (optional — throttle below the auto-cap, §3.5).
- **Focus in natural language compiles to globs.** The typical need: *"review this solution, but skip the test projects."* You can say it in words — the master **translates** the intent into concrete `--exclude` globs (`**/*.Tests/**` for a .NET solution, `src/test/**` for a Java module, …), **shows them for confirmation** (whether or not an explicit `<scope>` was given), and records the final globs plus the resolved file list in `inventory.json`. The artifacts always carry globs, never free text alone — so enumeration stays deterministic and the receipt's denominator (*F files*) is auditable. Explicit `<scope>` + explicit `--exclude` → run without asking; free-text focus → always confirm the derived globs first.
- **`--guidelines` missing → hard error** (no rules, no sensible default; ask for it).
- **`<scope>` missing → cost guardrail, don't scan silently.** Because scope = file count = subagent count = tokens, resolve the default folder, enumerate what it *would* review, and confirm with the blast radius shown:
  > "No scope given. I'd review everything under `X/` — **N files across M folders**. That's **N file-subagents**. Narrow it (a path, or excludes like 'skip the test folders') / proceed / cancel?"
  Explicit scope → run without asking.
- **Empty matrix → hard stop.** If enumeration yields **zero files** (scope + excludes match nothing) or validation yields **zero checkable rules** (everything out-of-scope), the run stops before the fan-out. A 0×R or F×0 matrix would be gap-free *by vacuity* — a "0 gaps" receipt over nothing — and this design never ships a receipt that proves less than it appears to.
- **Flow:** gate (run the validator — hard-stop on any quality issue; `rules.json` lands in the run dir) → run file-code-review → **reconcile coverage** → **adversarial verify** (under `--deep`, an overturned cell re-enters reconcile, §4) → render.
- **Reconcile coverage (the exhaustiveness proof) — bounded, fail-closed.** The run enumerated the files (`inventory.json`) and holds the validated rule set (`rules.json`), so the script knows the exact inventory. The script verifies that every (file × rule) cell has a recorded outcome; any **gap** — a file-agent that died, a rule skipped — is **re-dispatched, at most twice** (three attempts total). Gaps are typed: **retryable** (agent died mid-run) get the retries; **structural** (file unreadable, binary matched by the glob, file too large for one agent's context) skip retries and go straight to the gap list with their reason. If gaps remain after that, the run **fails closed**: it never claims done — the report still renders, but leads with an explicit **"INCOMPLETE — N gaps"** banner listing each gap and why. It never fails open (no receipt that pretends completeness). Only a gap-free matrix may claim *done*, and that matrix ships in the report as the receipt.

### 3.4 `visual-review` v2 (evolve the existing renderer)
A **user-invoked, fully independent** skill (anyone renders any findings file); the master reaches it only by running its `build.js` — a script, so no skill invocation is needed. Extend the already-built renderer rather than clone it (~90% chrome reuse):
- **Group by rule, not severity** (severity itself is dropped — §5) — sections and filter chips become per-rule ("all 6 verb-naming violations", "all 3 null-as-absence"); the directory tree stays as the location axis.
- **Breaking schema, declared:** the findings file carries `schemaVersion: 2` and `build.js` **errors clearly on v1 input** instead of guessing. No compatibility path — existing v1 reports never need re-rendering, because their HTML is self-contained and already built.
- **Add a coverage panel — the exhaustiveness receipt:** *"F files × R rules = C cells, A applicable, V confirmed, X refuted, 0 gaps"*, plus *"S rules out of scope, unchecked"* when `meta` carries the forwarded `outOfScope` list (§6), plus the *derived* fully-clean files and rules-honoured-everywhere (and, on demand, the grid itself, with `n/a` cells greyed and `refuted` cells marked). When the input carries gaps, the panel is replaced by the **"INCOMPLETE — N gaps"** banner with the gap list (§3.3). This **replaces the hand-curated "clean" section** — nothing about coverage is hand-authored anymore.
- **One input, coverage optional:** `build.js` takes the single `code-findings.json` (findings + coverage, §6). `coverage` is **optional in the schema** — present, it renders the panel (or the INCOMPLETE banner); absent (e.g. a hand-authored write-up of a PR review, with no matrix behind it), the report simply has no coverage section. That optionality is what keeps `visual-review` a clean standalone "render findings" tool while also being the master's renderer; master runs always emit coverage.

### 3.5 Orchestration & run artifacts

**Orchestrator = a pinned Workflow script, built incrementally.** The master ships `code-review.workflow.js` (exactly as `visual-review` ships `build.js`). The deterministic JS owns the control flow — enumerate → fan out → collect → **reconcile → bounded retries → fail closed** → verify → render; the LLM agents only make per-file/per-rule judgments and the refutes. This is deliberate: the **0-gaps proof (§3.3) must be machine-checked** — an LLM deciding "are we done?" would reintroduce the premature completion (§1) we are eliminating. The script grows in two stages matching the build order (§7): **stage A** (ships with `file-code-review`) is a minimal driver — enumerate files → fan out per-file agents → collect shards → assemble the coverage grid, with `rules.json` handed in manually; **stage B** (the master) adds the validator gate (the script dispatches a validator **agent** whose instructions are `guideline-validator`'s SKILL.md, and persists the returned `rules.json` into the run dir), reconcile + bounded retry, the skeptic pass, the scope guardrail, and the render call. Stage A is also the harness the §8 scenarios run on. (An Agent-tool loop, where the master LLM dispatches agents itself, is a weaker fallback for tiny/one-off runs.)

**No shared file, and the matrix never enters an LLM context.** Each per-file agent is handed only *(its file + the rule set)* and returns its **row** into the JS layer (persisted as its own shard). So the two dangers dissolve:
- **Concurrent writes** — impossible: each file-agent owns exactly one shard; `code-findings.json` is written **once**, by the script.
- **Context up/down** — the down-payload is tiny and identical per agent (one file + the rules); the N rows live in JS variables / on disk, **not** in any model's window. The master loop sees only one-line acks and the gap list.

**Run layout — the artifact map in §2 is the single source of truth** for names, locations, formats, and writers. Intermediates live in the gitignored run dir; the final report is written to your chosen output path (as `visual-review` does). One implementation note: workflow scripts can't read the clock, so the master passes the run timestamp (the `<run-id>`) into the script as an argument.

**Reconcile** = the script diffs `inventory.json` against `rows/*.json`: a missing shard, or a shard missing a rule, is a **gap**, handled by §3.3's bounded-retry policy. Fully deterministic, and it terminates. A single-cell re-dispatch (a `--deep` overturn, §4) returns a one-cell row and **the script merges it into that file's shard** (author/persist split per the artifact map, §2).

**Documented for three audiences:** the **shards** are the transient audit trail; **`code-findings.json`** is the machine record; the **coverage panel** in the report is the human receipt (§3.4).

**Concurrency & cost — auto-managed, steered by scope, not a parallelism dial:**
- Concurrency is **auto-capped** at `min(16, cores−2)` per workflow; pass all N files, ~14 run at once, the rest queue. Backstops (rarely hit): ≤4096 items per fan-out, ≤1000 agents per run.
- **Total work** is steered by `<scope>` (the guardrail — fewer files = fewer agents).
- **Model: one tier for v1 — Opus for every agent** (per-file checks and refutes alike). No model-tiering yet: it's an obvious later cost lever, but adding it now would introduce a variable while we're still proving correctness. An optional `--concurrency K` throttles below the default only if rate/cost limits demand it.

## 4. Adversarial verification

"Adversarial" here means: after the review completes, each finding is handed to a fresh **skeptic** agent whose only job is to *refute* it — *"here is the code and the rule; make the strongest case this is NOT a violation (an exemption applies, the scope was misread, it's a false positive)."* If the skeptic can't refute it, it stands; if it refutes convincingly, the finding is dropped **and its coverage cell flips `violation → refuted`** — a distinct fourth state (not silently back to `clean`), so the shipped matrix reflects the *post-verification* truth **and** still records that a violation was proposed here and knocked down. (A cell with several findings for the same rule flips only when **all** of them are refuted — one confirmed violation keeps the cell `violation`.) The skeptic has the same **read-only context privileges** as the finder (§3.2) — it can pull the callers/callees the finding relied on; without that it would refute cross-file-context findings whose basis it can't see. Why refute at all: a finder told to *find* violations is biased toward over-reporting, and a false positive here costs a wasted (or wrong) fix — a dedicated refuter cancels that bias. Centralized in the master for consistency.

**Tunable depth (`--deep`):** one skeptic by default; `--deep` runs a **3-vote skeptic panel** (drop a finding if ≥2 refute) — a higher-confidence audit at higher cost. `--deep` also guards the *other* error direction: it audits a **random sample of up to 20 `clean`/`n/a` cells** (10% of them, when that's smaller) asking *"was this really clean / really inapplicable?"*; an overturned cell is treated as a **gap** — that file's agent is re-dispatched for that rule, and any new violation it produces goes back through the skeptic; the loop is bounded by the same retry cap (§3.3). The sample is a fixed-cost spot check, not a full re-review: it reliably catches a *systematically* lazy or rule-misreading finder; a finder that is wrong only occasionally can slip past it — that is the accepted trade. (No model-tier bump: v1 is Opus everywhere, §3.5.)

## 5. Severity — dropped for v1

A per-finding severity is an **ungrounded cross-rule ranking** the reviewer cannot justify (is a null-return "worse" than a missing verb? unanswerable). Removed. **Grouping-by-rule** replaces it as the organizing axis. If prioritization is wanted later, it belongs on the **rule** in the guidelines file ("this rule is blocking") — decided once by the guideline author, which *is* the grounded version — not invented per-finding. Deferred.

## 6. Data contracts

**Guidelines input (in).** Human-authored markdown, and the *shape decides the extraction*:
- a **single freeform file** → the validator **extracts multiple discrete rules** from it (this repo's `CONVENTIONS.md` shape);
- a **folder of markdown files** → **each file is exactly one rule** (the well-documented shape — one rule with a lot of explanation and examples per file), validated as a unit.

General — no app-specific references.

**Validated rule set (`rules.json`) — the validator's output, the master's input.** The busiest interface in the family, so it gets a schema:
```json
{
  "source": { "path": "…", "contentHash": "…" },
  "rules": [
    { "id": "…", "statement": "…", "sourceAnchor": "…", "rationale": "…?" }
  ],
  "outOfScope": [ { "statement": "…", "reason": "…" } ]
}
```
- `id` — for the folder shape, the rule file's name; for the freeform shape, a slug derived from the rule's *normative statement* (not its position in the file). Ids only need to be stable **within a run** — findings and the coverage grid are per-run artifacts, and every agent reads the same run-local `rules.json` (§3.1).
- `contentHash` — provenance: it records exactly which version of the guidelines this run validated against.
- `statement` — the crisp, file-grain-decidable rule itself; example/rationale is illustration, kept out of the statement.
- `sourceAnchor` — where in the guidelines the rule came from, for traceability.
- `outOfScope` — the rules excluded as not file-grain-decidable (§3.1), with the validator's reason. The script forwards this list into `code-findings.json`'s `meta` so the final report can state *"S rules out of scope, unchecked"* — exclusion is always visible, never silent.

**Run inventory (`inventory.json`) — the expected grid, written by the script before the fan-out.**
```json
{
  "runId": "2026-07-06-141530",
  "scope": "variance-lots-check/src",
  "excludes": ["**/*.Tests/**"],
  "focusText": "production code only",
  "files": ["VarianceLotsCheck.Core/Gen10SheetLoading/Gen10Sheet.cs", "…"],
  "ruleIds": ["verb-naming", "no-null-as-absence", "…"]
}
```
- `focusText` — present only when the excludes were derived from natural language (§3.3): the original words, kept for audit. The globs are what executed.
- `files` — relative to the scope root; `files × ruleIds` **is** the denominator the receipt reports, and what reconcile diffs the shards against.

**Row shard (`rows/<relative-path>.json`) — one file-agent's return value, persisted by the script** (verbatim on first write; single-cell re-dispatches are merged in, §3.5).
```json
{
  "file": "VarianceLotsCheck.Core/Gen10SheetLoading/Gen10Sheet.cs",
  "cells": [
    { "rule": "verb-naming", "outcome": "violation" },
    { "rule": "no-null-as-absence", "outcome": "clean" },
    { "rule": "du-total-match", "outcome": "n/a", "reason": "no discriminated unions in this file" }
  ],
  "findings": [ /* full finding objects — shape below */ ]
}
```
- Exactly one `cells` entry per rule id in `rules.json` — a missing entry is a **gap** (§3.3). Every `n/a` carries its one-line reason (auditable, sampled under `--deep`, §4) so it can't silently dodge work.
- Agents emit only `clean | violation | n/a`. **`refuted` never comes from an agent** — the script flips `violation → refuted` after the skeptic pass (§4).

**Findings file (`code-findings.json`) — the run's single output: findings + coverage.** Evolves the current `visual-review` v1 schema (whose real shape is `meta` + `findings[]` with `severity` / `convention` / `kind` / annotated `current` / `callers` / before-after `suggestion`, plus hand-curated `judgmentCalls` / `nonFindings` / `clean` sections):
- `schemaVersion: 2` — the v1→v2 change is breaking (no `severity`, grouping needs `rule`); `build.js` rejects v1 input with a clear error (§3.4).
- `meta` — kept (title, ruleset, scope, date, summary), plus the forwarded `outOfScope` list; script-filled from `inventory.json` and `rules.json`. The human-oriented `summary` comes from a **summarizer agent the script dispatches last** (handing it the assembled findings and totals) — agents judge, the script writes, so the script stays the file's single writer (§2).
- Finding — keeps v1's proven fields: `id`, `title`, `kind (line|signature)`, `symbol?`, `location {path, line, endLine?}`, `what`, `current {lang, startLine, code, annotations[]}`, `callers[]?` (from the read-only pulls, §3.2 — enrichment, never a finding location), `suggestion {summary, before, after, callerBefore?, callerAfter?}`, `notes?`. `id` is **prefixed with the file's slug** (v1's real ids — `gen10sheet-openxml-null-forgiving` — already follow this), making ids unique across the run with no cross-agent coordination. Path bases, declared once: `location.path` (and `callers[].path`) are **repo-root-relative** — v1's convention, and what click-to-open needs — while `inventory.files` and `coverage.files` are **scope-root-relative**; the renderer joins `meta.scope` + file to cross-link grid cells to the findings tree.
- Two v1 fields change: `severity` — **dropped** (§5); `convention` (free prose) → **`rule: { id, statement }`** (findings cite and group by rule).
- `judgmentCalls[]` and `nonFindings[]` — **kept, optional, hand-authored only**: no pipeline step produces them, so master runs never emit them. In a master run their role is played by `refuted[]` — a settled-by-design "violation" is exactly a finding the skeptic knocks down citing the prior decision. They survive for standalone hand-written findings files.
- `refuted[]` — **new, optional**: each skeptic-dropped finding in full, plus the refutation rationale — so the skeptic itself is auditable, not just its verdict.
- `clean[]` — **removed**: fully-clean files (a row with no confirmed violation) and rules-honoured-everywhere (a column with no confirmed violation) are *derived* from the grid; nothing about coverage is hand-authored.
- `coverage` — optional in the schema, always emitted by master runs (§3.4):
```json
"coverage": {
  "files": ["…"],
  "ruleIds": ["…"],
  "cells": [ { "file": "…", "rule": "…", "outcome": "clean | violation | n/a | refuted", "reason": "…(n/a only)" } ],
  "totals": { "cells": 0, "applicable": 0, "violations": 0, "refuted": 0, "gaps": 0 },
  "gaps": [ { "file": "…", "rule": "…?", "type": "retryable | structural", "reason": "…" } ]
}
```
  Semantics: **`totals` counts cells, not findings** (a file violating one rule twice is one `violation` cell carrying two findings); `cells = files × ruleIds`; `applicable = clean + violation + refuted` (the cells where the rule had a real site and was adjudicated); `violations` is confirmed, post-refutation — a cell flips to `refuted` only when *all* its findings were refuted (§4). The script asserts **`gaps == 0`** to claim done; otherwise the gap list ships and the report renders the INCOMPLETE banner (§3.3). The receipt the report leads with — *"F files × R rules = C cells, A applicable, V confirmed, X refuted, 0 gaps"* — is honest, not padded, and per §2 it is a claim about **coverage, not correctness**.

**Validation report (standalone validator runs).** Human-readable markdown mirroring §3.1's verdict table — one row per candidate rule (verdict + reason), contradiction/overlap suspects listed as pairs. No machine contract needed: `rules.json` is the machine artifact.

The final HTML is a rendering of `code-findings.json`, not a contract of its own.

## 7. Build order

1. **`guideline-validator`** — smallest, foundational, independently useful; ships the `rules.json` contract. Dogfood it first on a **real, messy freeform conventions doc** (app-coupled, prose-heavy, vague and overlapping rules): its feedback — aspirational/composite rules rejected, architecture-grain rules flagged out-of-scope, contradiction/overlap suspects — *is* the worklist for producing a clean general guidelines file, and it de-risks the whole premise.
2. **`file-code-review` + the stage-A driver** — the per-file matrix, emitting **full rows** (outcome per rule) so coverage is captured, plus the minimal workflow driver (enumerate → fan out → collect shards → assemble grid; §3.5) that makes it executable and testable standalone. Most of the day-to-day value.
3. **`visual-review` v2** — rule-grouping + drop severity + **coverage panel / INCOMPLETE banner** (needed to render #2 well).
4. **`code-review` master** — **grow the stage-A driver** into the full orchestration: validator gate, scope guardrail with natural-language-focus → glob translation, **coverage reconciliation with bounded retries and the fail-closed INCOMPLETE path**, adversarial verify, render.

Each is built test-first (see §8).

## 8. Building these skills (test-first)

The family is built the way Superpowers builds skills: **test-first, no component without a failing test first.** Per **superpowers:writing-skills**, *"writing skills IS TDD applied to process documentation"* — the same **RED → GREEN → REFACTOR** cycle and the same Iron Law (*no skill without a failing test first*). Each component here splits cleanly into one of two natures, and the two test differently.

**Deterministic components → conventional unit tests (RED-GREEN).** The orchestrator's control flow (enumerate → fan out → **reconcile → bounded retries → fail closed**), the coverage math (`cells / applicable / violations / refuted / gaps`), the scope/exclude enumeration, and `visual-review`'s `build.js` render are ordinary code. Test them with fixed inputs and asserted outputs, test-first:
- Feed a fixture tree + a scope + exclude globs; assert the enumerated file list (and so `inventory.json`) matches exactly — test folders out, production files in.
- Feed a hand-built `inventory.json` + `rows/*.json` with a deliberately **missing shard and a missing cell**; assert `reconcile` reports exactly those two gaps and re-dispatches *only* them. (RED: with no reconciler, the assertion fails — that's the point.)
- Feed a gap that **fails all three attempts**; assert the run ends `gaps > 0` with the gap typed and reasoned — never a clean receipt. Feed a **structural** gap; assert no retries are spent on it.
- Feed a known coverage grid; assert the totals and the `gaps == 0` / `gaps > 0` verdict.
- Feed a known findings file; assert the rendered HTML has the expected cards, per-rule grouping, and coverage panel — including the *"S rules out of scope"* line when `meta` carries the list — and, for a gapped input, the INCOMPLETE banner. Feed a `schemaVersion: 1` file; assert a clear rejection, not a mangled render.

**LLM-judgment components → answer-key fixtures + subagent scenarios (RED-GREEN-REFACTOR).** The validator's lint, the per-file cell outcomes, the adversarial refuter, the natural-language-focus → glob translation (§3.3), and the `--deep` clean/n/a audit (§4) are model judgments. Test them the writing-skills way: run the scenario **without** the procedure to watch the baseline fail (RED — *"if you didn't watch an agent fail without the skill, you don't know the skill teaches the right thing"*), then **with** it (GREEN), then close loopholes (REFACTOR). The natural fixture is the one this repo already uses for `by-broker`: **a small source tree with planted violations + an answer key** (like the existing `errors.md`). The fixture carries **two assertions that activate with the build order (§7)**: at **#2**, running on the stage-A driver (§3.5, no master needed), the review **recovers every planted violation** with full rows — a miss *is* the premature-completion regression the whole design targets (§1). At **#4**, once the skeptic exists, the verified review **adds none beyond the key** — a spurious add *is* a refuter miss (§4). Together they exercise the core claim end-to-end: coverage complete *and* honest.
- **Validator:** the example verdicts in §3.1 are the answer key (rule → expected verdict, including the 🚫 out-of-scope row); assert the lint matches, that any *quality* problem trips the hard stop (the gate must never proceed on an untrustworthy rulebook), **and** that an out-of-scope rule is excluded-and-reported without blocking (§3.1).
- **Micro-test the judgment wording before the full scenarios** (superpowers:writing-skills): one fresh-context sample per call, **always include a no-guidance control** (if the control doesn't fail, there's nothing to fix — stop), 5+ reps, read every flagged match by hand, treat variance across reps as a failure signal. Cheap iteration on the prompt before the expensive scenario runs.

**Build order is test order.** §7's sequence is also the dependency order of the tests: each component ships green before the next one builds on it.
