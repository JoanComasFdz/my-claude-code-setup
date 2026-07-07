# Baseline (no-skill) findings — RED

Four runs: two contaminated (a harness lesson), two clean (the real RED). All on Opus.

## Runs 1–2: CONTAMINATED (fixtures live in the tool's own repo)

Given filesystem access and the naive task, both no-skill agents explored the repo and
read `DESIGN.md` (§3.1 decidability triage, §6 output shape), `references/rules-schema.json`,
**and the fixture's own `expected-verdicts.md` answer key** — then reproduced the methodology
almost perfectly (correct hard stop, correct reject/out-of-scope/contradiction/overlap split,
real `contentHash`). That is a **false GREEN**: the control passed only by discovering the
design + the answer key.

**Lesson (fixed):** a RED run must isolate — paste the conventions inline, forbid file access.
In production this leakage cannot occur (the user's CONVENTIONS.md sits in their repo; there is
no answer key), so inline-paste is the *faithful* baseline. `scenarios.md` RED arm updated.

## Run 3: CLEAN synthetic (inline paste, no file access)

**Got right, un-guided:** enumerated all 7 statements (no sampling miss); split the two
compound sections; **caught the contradiction** (single-exit vs guard clauses) and **caught the
doc overlap** (merged the two documentation sentences); recognized "Apply SOLID" and the layering
rule as not per-file-mechanical.

**Failed (what the skill must teach):**
- [x] **No hard stop.** It did *not* refuse to emit. It "quarantined" the bad rules with
  `status: "blocked"` / `status: "active"` and emitted a usable-looking artifact anyway —
  keeping the contradictory rules so "the review pipeline sees them but doesn't act on them."
  This is the prepare-around-it loophole the design forbids.
- [x] **Wrong output contract.** Invented `schemaVersion`, `checkability`, `flagWhen`, `status`,
  `supersedes`, `conflictsWith` — not the §6 `rules.json` shape.
- [x] **Reintroduced per-finding `severity`** (`warning`/`info`/`error`) — §5 drops it.
- [x] **Conflated reject vs out-of-scope.** "SOLID" (composite → reject) and "domain must not
  depend on infrastructure" (crisp but repo-grain → out-of-scope) both became "architectural /
  blocked." No reject-vs-out-of-scope distinction.

## Run 4: CLEAN messy — real CONVENTIONS.md (inline paste, no file access)

**Got right, un-guided:** thorough — decomposed the prose into 28 atomic rules, splitting
compound sentences (the "honest/total signatures" bullet → 4 rules). **No sampling failure at
this scale.** Also made a smart (but off-target) observation that the doc is app-scoped.

**Failed (what the skill must teach):**
- [x] **No hard stop.** Emitted all 28 as an enforceable, annotated list.
- [x] **No `reject` verdict.** Composite whole-paradigm rules — Vertical Slice Architecture,
  Railway-oriented flow, Effects-as-data, Typestate, Make-illegal-states — were kept as
  enforceable `error`/`warning` rules merely tagged `needs-cross-file-context`, not rejected.
- [x] **No `outOfScope` separation.** Architectural/dependency rules (slice boundaries, domain
  purity) stayed inside the `rules` array with a scope tag, rather than excluded-and-reported.
- [x] **Missed the overlap.** The pure/impure "sandwich" is restated (FUNC-01 sandwich vs
  FUNC-02 "no mixing on one line"); the baseline kept both as distinct rules, no overlap flag.
- [x] **Wrong contract + reintroduced severity**, as in Run 3.

## Verdict

The un-guided baseline **fails the design's core requirements**: it does not hard-stop, does not
use the reject / out-of-scope / contradiction / overlap taxonomy, does not emit the `rules.json`
contract, and reintroduces severity. So the skill's job for the *validator* is **discipline
(hard stop) + taxonomy + output contract** — NOT coverage. (Honest note: §1's sampling/premature-
completion failure did not manifest at single-doc scale; a single Opus agent enumerates a
~1200-word doc thoroughly. §1's sampling story bites the whole-codebase *file-review* loop
[build #2], not this guideline-extraction step.) → proceed to GREEN.

**Where to aim the SKILL.md and the micro-tests:** the hard-stop discipline and its
prepare-around-it loopholes (`status: blocked`, "the pipeline sees them but won't act"), the
reject-vs-out-of-scope boundary, and the "emit the rules.json contract, no severity" shape.
