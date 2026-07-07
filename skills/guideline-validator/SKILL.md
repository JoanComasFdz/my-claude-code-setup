---
name: guideline-validator
description: Use when turning a coding-guidelines or conventions document into rules for an automated code review, or before trusting such a review's results. Symptoms: a prose CONVENTIONS.md with vague, composite, or contradictory rules; unsure which rules a per-file reviewer can actually decide; architectural rules mixed with file-level ones. Also the gate the code-review master runs before fanning out.
---

# Guideline Validator

## Overview

A code review is only as trustworthy as its rulebook. This gate turns a prose
guidelines document into a validated, **file-grain-decidable** rule set
(`rules.json`) — and **refuses to proceed** when the rulebook itself is
untrustworthy (composite rules, contradictions, overlaps). It **validates only**;
it never rewrites the guidelines. The author edits the doc and re-runs — that loop
is the point.

**Validating the letter is validating the spirit.** "Preparing the conventions"
does not mean handing the review a best-effort rule list with the bad rules
annotated. If the rulebook has a blocking defect, the honest output is a STOP, not
a padded list — see Hard gate.

## When to use
- Preparing a `CONVENTIONS.md`/guidelines doc to drive `/code-review`.
- Before trusting a review whose churn suggests the rules were never pinned down.
- As the code-review master's gate (dispatched as an agent on this file).

## Inputs
- A **single markdown file** → extract MANY discrete rules from it.
- A **folder of markdown files** → **each file is exactly one rule.**
- Optional **output dir**. Default (standalone): next to the input. The master
  passes its run dir.

## Procedure
1. **Detect the shape** (file vs folder) — it decides extraction.
2. **Extract candidate rules.** Freeform: split into atomic normative statements;
   strip examples and rationale from the `statement`. A sentence that bundles
   several requirements becomes several candidates. Folder: one rule per file;
   `id` = filename (without extension).
3. **Classify each candidate** with the decidability test (below) → exactly one of
   `actionable` / `reject` / `out-of-scope`.
4. **Scan the set pairwise** for **contradictions** (two rules cannot both be
   honoured on one site) and **overlaps** (two rules target the same defect). Do
   this explicitly — compare every pair; do not assume none exist because none is
   obvious.
5. **Decide (see Hard gate):**
   - Any `reject`, `contradiction`, or `overlap` (or a borderline overlap
     *suspect*) → **HARD STOP.** Report everything; write NO `rules.json`.
   - Otherwise → **emit** `rules.json`. `out-of-scope` rules are excluded from
     `rules[]` and listed in `outOfScope[]` — they never block.

## The verdict rubric

**Decidability test (apply to every candidate), in order:**
1. **Can you state the violation as one concrete, checkable condition?** If NO —
   the rule bundles several concerns, or leans on an unbounded adjective with no
   threshold ("clean", "maintainable", "small", "SOLID") → **reject.**
2. **To decide that condition *here*, would you need facts about other files or the
   project layout** (which file is which layer/slice, the whole import graph, the
   end-to-end flow)? If YES → **out-of-scope.**
3. Otherwise — decidable from this file plus its immediate callers/callees →
   **actionable.**

| Verdict | The tell | Example |
|---|---|---|
| ✅ **actionable** | one concrete condition, decidable at file grain | "Name functions with a verb" |
| ⛔ **reject** | composite / unbounded — you cannot even pin down what "violated" means | "Apply SOLID", "keep it clean and maintainable", "make illegal states unrepresentable", "railway-oriented flow" |
| 🚫 **out of scope** | you know EXACTLY what a violation looks like, but can't see it from one file | "The domain must not depend on infrastructure"; "feature slices never depend sideways" |
| ⛔ **contradiction** | two rules cannot both be honoured on one site | "single exit" vs "use early-return guard clauses" |
| ⚠ **overlap** | two rules flag the same defect → double-counted findings | two phrasings of the same requirement (e.g. a "sandwich" restated at two granularities) |

**reject vs out-of-scope is the boundary that drifts** (the baseline conflated
them): **reject** = the condition itself is unpinnable; **out-of-scope** = the
condition is crisp, only the *context to evaluate it* exceeds one file. A
whole-paradigm mandate ("apply ROP", "make illegal states unrepresentable") is
`reject`, not `out-of-scope` — there is no single concrete violation to look for.

## Hard gate behaviour

- **Any `reject`, `contradiction`, or `overlap` → report everything and STOP.**
  Reviewing against such a rulebook produces untrustworthy findings, so no
  `rules.json` may be written.
- **`out-of-scope` is the ONLY non-blocking verdict** — exclude it from `rules[]`,
  list it in `outOfScope[]`, and proceed. It never triggers a stop by itself.
- **Never rewrite the guidelines.** Report the defect; the human fixes the doc and
  re-runs. Validator feedback + human editing IS the authoring loop.
- **Report the count of checkable rules**, so a caller sees an empty rule set.

## Outputs

**On a clean pass — write `rules.json`** conforming to `references/rules-schema.json`.
Each rule object has EXACTLY these keys and no others:
`id`, `statement`, `sourceAnchor`, and optional `rationale`. There is **no
`severity`, no `status`, no `checkability`, no `scope`, no `flagWhen`** — a rule is
either in `rules[]` (checkable) or in `outOfScope[]` (excluded), nothing in
between. Top level: `source { path, contentHash }`, `rules[]`, `outOfScope[]`.
- `contentHash` = SHA-256 of the source bytes: `sha256sum <file>` (Linux) /
  `shasum -a 256 <file>` (macOS); for a folder, hash the files' concatenation in
  sorted path order. Record the 64-char lowercase hex.
- `id`: folder shape → filename (no extension); freeform shape → a kebab-slug of
  the `statement` (lowercase; non-alphanumeric → `-`; collapse and trim `-`),
  unique within the run.
- Write to the output dir if one was given; else next to the input.

**On a hard stop — write NO `rules.json`.** Standalone: write `validation-report.md`
next to the input — human-readable markdown, one row per candidate (verdict +
reason), contradiction/overlap suspects listed as pairs. Master run: no report
file — state the STOP and every candidate's verdict in your final message; the
`outOfScope` list would otherwise ride inside `rules.json`.

## Common mistakes
- **Emitting a "best-effort" list past a blocking defect.** A contradiction/overlap/
  reject means STOP — not a `rules.json` with the bad rules flagged.
- **Keeping a bad rule with a `status`/`blocked`/`needs-context` tag.** There is no
  such field. Checkable → `rules[]`; excluded → `outOfScope[]`; otherwise → STOP.
- **Adding `severity`.** Dropped by design. Priority, if ever wanted, belongs on the
  rule in the guidelines, decided by the author — never invented per rule here.
- **Calling a whole-paradigm rule `out-of-scope`.** "Apply ROP" / "make illegal
  states unrepresentable" is `reject` — no concrete violation to look for.
- **Skipping the pairwise scan** and missing an overlap because it wasn't obvious.

## Rationalizations — STOP
| Excuse | Reality |
|--------|---------|
| "The doc is mostly fine; I'll emit the good rules and flag the rest." | An untrustworthy rulebook makes every downstream finding suspect. A blocking defect means STOP — no partial `rules.json`. |
| "I'll keep the bad rules but mark them `blocked` so the pipeline sees but ignores them." | That is emitting a padded matrix. The pipeline must never receive a rule it shouldn't act on. Checkable or excluded or STOP — no fourth state. |
| "This composite rule is important; I'll keep it and interpret it at review time." | Unbounded rules produce N interpretations and endless churn. Reject it; the human splits it. |
| "The contradiction is minor; a reviewer can pick one." | Then two files get opposite verdicts for identical code. STOP; the human resolves it. |
| "I'll just reword the rule to make it crisp." | You validate, never rewrite. Report the defect and stop. |

## Red flags — you are about to fail
- Writing `rules.json` while a reject/contradiction/overlap is unresolved.
- Any per-rule `status`, `blocked`, `severity`, `checkability`, or `scope` field.
- Putting a layering/dependency/whole-flow rule into `rules[]`.
- Emitting rules without having compared every pair for overlap/contradiction.
- Rewording a rule instead of reporting it.
