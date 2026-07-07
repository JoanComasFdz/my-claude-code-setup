# Dogfood — `guideline-validator` on the real `variance-lots-check/CONVENTIONS.md`

> **What this is (DESIGN.md §7).** The build order dogfoods the validator "first on a
> real, messy freeform conventions doc … its feedback — aspirational/composite rules
> rejected, architecture-grain rules flagged out-of-scope, contradiction/overlap
> suspects — *is* the worklist for producing a clean general guidelines file." This is
> that worklist: the **verbatim** output of a finished-validator run (following
> `../SKILL.md`, unchanged since the Task-5 GREEN + Task-6 pressure passes) on the real
> `CONVENTIONS.md`. Provenance: `source.contentHash` below pins the exact input.
>
> **Headline:** the doc is a genuinely useful *human* house-style guide, but it is **not**
> a trustworthy rulebook for an automated per-file review as-is — 11 rules are unbounded/
> whole-paradigm (`reject`), one pair overlaps, and 10 are sound-but-architecture-grain
> (`out-of-scope`). Only ~5–7 statements are file-grain-decidable. The validator therefore
> **hard-stops** and hands back the fix list. **The cleanup worklist is the "What to do
> next" section at the end.**

---

# Guideline validation report — `variance-lots-check` CONVENTIONS.md

**Decision: HARD STOP — no `rules.json` written.**

The rulebook contains multiple **reject** verdicts (unbounded / whole-paradigm
mandates) and at least one **overlap** (the impure→pure→impure "sandwich" restated
at two granularities). Reviewing code against an untrustworthy rulebook produces
untrustworthy findings, so no rule set is emitted. Fix the flagged rows in the doc
and re-run.

- **Source:** `input/CONVENTIONS.md`
- **contentHash (SHA-256):** `e4604c45c49dd33743db7b45732f8a1e9799e0c72f2e332f0ece3bf6458eda6d`
- **Shape:** single markdown file → freeform extraction (many candidates)
- **File-grain-decidable (`actionable`) candidates:** 5 — but **none may be emitted** while blocking defects stand.

## Blocking summary

| Verdict | Count | Blocks emit? |
|---|---|---|
| ✅ actionable | 5 | — |
| 🚫 out-of-scope | 10 | no (would be listed in `outOfScope[]`) |
| ⛔ reject | 12 | **yes** |
| ⚠ overlap (suspect pair) | 1 pair | **yes** |
| ⛔ contradiction | 0 | — |

## Candidate verdicts (one row per candidate)

| # | Candidate statement | Source anchor | Verdict | Reason |
|---|---|---|---|---|
| 1 | Vertical Slice Architecture is the top-level driver; a behaviour change touches one slice, not a layer | Architecture, bullet 1 | ⛔ reject | Whole-paradigm architecture mandate; a per-file "violation" cannot be pinned to one concrete condition. |
| 2 | Group by feature, never by kind | Architecture, bullet 1 | 🚫 out-of-scope | Violation is crisp (a folder grouped by technical kind), but deciding it needs the whole project layout, not one file. |
| 3 | Feature slices depend only on the shared kernel; never sideways on each other (only `Orchestration`→all and `PreFlightValidation`→validated slices allowed) | Architecture, bullet 2 | 🚫 out-of-scope | Classic layering/dependency rule; needs the import graph and which file is which slice. |
| 4 | An architecture test enforces these boundaries in CI | Architecture, bullet 2 | 🚫 out-of-scope | Project-level meta-requirement (existence of a test); not a per-file condition. |
| 5 | The kernel's `Extraction` and `Documents` modules may not depend on any feature slice | Architecture, bullet 2 | 🚫 out-of-scope | Dependency/layering across files; needs the import graph + module identity. |
| 6 | The broker is the primary slice; adding one is a folder + a registry line, never an edit to a shared classifier or a dispatch `switch` | Architecture, bullet 3 | 🚫 out-of-scope | To know a `switch` is a broker dispatch that belongs in the registry needs the whole-flow/registry context. |
| 7 | `Domain` holds data + pure value arithmetic only — no feature behaviour, no outward dependency, never depends on a feature slice or `System.IO` | Architecture, bullet 4 | 🚫 out-of-scope | Canonical "domain must not depend on infrastructure"; needs import graph + layer identity. |
| 8 | Strict `impure → pure → impure` sandwich — read at the start, compute in the middle, write at the end | Functional design, bullet 1 | ⛔ reject | Whole-flow paradigm property; no single concrete file-grain violation. **Also overlaps #9 (see pairwise).** |
| 9 | Never mix or nest pure and impure calls on one line; split into separate statements | Functional design, bullet 2 | ✅ actionable | File-local: a single statement nests an impure call around a pure one (or vice versa). **But overlaps #8 → blocking.** |
| 10 | Effects as data — pure functions return an `Effect` DU that the impure shell `Match`es and executes | Functional design, bullet 3 | ⛔ reject | Whole-architecture "effects as data" paradigm; no concrete per-file violation to look for. |
| 11 | Honest, total signatures via our own `Optional`/`Result`/`Unit` | Functional design, bullet 4 | ⛔ reject | Unbounded adjectives ("honest", "total") bundling a paradigm; violation unpinnable. |
| 12 | No third-party FP library | Functional design, bullet 4 | ✅ actionable | File-local: a `using`/import of a third-party FP library (e.g. LanguageExt). |
| 13 | No null-as-absence | Functional design, bullet 4 | ⛔ reject | "null as absence" needs intent; no crisp checkable threshold. |
| 14 | No exceptions-as-control-flow across the pure core | Functional design, bullet 4 | ⛔ reject | "Exceptions as control flow" is fuzzy and "across the pure core" needs knowing what the pure core is. |
| 15 | Railway-oriented (ROP) end-to-end flow — compose `Result`-returning steps, short-circuit on first blocking error, no explicit app-state object | Functional design, bullet 5 | ⛔ reject | Literal whole-paradigm mandate ("railway-oriented flow"); no single concrete violation. |
| 16 | Use typestate when call order matters (e.g. `ValidatedFolder` constructible only via a successful pre-flight, so reconcile-before-validate won't compile) | Functional design, bullet 6 | 🚫 out-of-scope | The invariant is crisp, but verifying the ordering property spans multiple files/whole flow. |
| 17 | Pure state machine is reserved for genuinely stateful situations with more than two states, not the linear app flow | Functional design, bullet 7 | ⛔ reject | A "when to use pattern X" judgment ("genuinely stateful"); no concrete violation. |
| 18 | Data ⟂ behaviour — records hold data; no methods carrying logic on the records themselves | Domain modelling, bullet 1 | ✅ actionable | File-local: a `record` declares a logic-bearing instance method (borderline: "logic" is a soft boundary). |
| 19 | Functions are actions — name every function/method with a verb; never a bare noun (predicates may use `Is`/`Has`/`Can`; conversions `Parse`/`To`/`From`/constructor names) | Domain modelling, bullet 2 | ✅ actionable | Canonical actionable example; per-name check decidable from the file. |
| 20 | Immutability everywhere — all domain types are immutable `record`s | Domain modelling, bullet 3 | ✅ actionable | File-local: a type has mutable fields/setters (borderline: the "domain types" scope qualifier leans out-of-scope). |
| 21 | Model domain variants as discriminated unions (Dunet), not inheritance; behaviour is static/extension functions that pattern-match internally — never `ISomething` + two classes | Domain modelling, bullet 4 | ⛔ reject | "Prefer DU over inheritance" is a paradigm/judgment; deciding an interface "should be" a DU needs context. |
| 22 | Make illegal states unrepresentable — each DU case carries exactly its own figures; prefer a data-carrying case over tag+optionals | Domain modelling, bullet 5 | ⛔ reject | Literal whole-paradigm mandate; no single concrete file-grain violation. |
| 23 | Value objects via Vogen, constructed and validated at the boundary; known-valid inside the pure core | Domain modelling, bullet 6 | 🚫 out-of-scope | "At the boundary" / "pure core" needs flow knowledge to evaluate. |
| 24 | Add a named failure/`Severity` case only when the app branches on it, never merely to carry a message; message-only IO uses `Result<_, string>` | Domain modelling, bullet 7 | 🚫 out-of-scope | "Only when the app branches on it" requires whole-app flow knowledge. |
| 25 | Prefer static direct calls over interfaces/delegates | API gotchas, bullet 1 | ⛔ reject | Soft "prefer" with no threshold; any interface/delegate could be justified — no crisp violation. |
| 26 | Construct Dunet union cases with `new` (`new Result<T,F>.Ok(x)`/`.Error(e)`); use `Optional.Some<T>(x)`/`Optional.None<T>()`; never `Result.Ok(...)` / `Optional<T>.None()` | API gotchas, bullet 2 | ✅ actionable | File-local: the construction expression is visible in the file. |
| 27 | `Match` needs an explicit type argument when branches return different types (`value.Match<string>(...)`) | API gotchas, bullet 3 | ✅ actionable | File-local: a `Match` with differing non-void branch returns lacking an explicit type argument. |
| 28 | Catch foreseeable boundary exceptions (missing/denied permission, locked/corrupt/unreadable file) and wrap in `Result<_, Failure>`; let unrecoverable exceptions (`OutOfMemoryException`) bubble | API gotchas, bullet 4 | 🚫 out-of-scope | "At the boundary" needs knowing which file is the boundary; "foreseeable vs unrecoverable" is judgment. |

_(Reported `actionable` conservatively as 5–7: #9, #12, #19, #26, #27 are clean file-grain checks; #18 and #20 are borderline and lean soft. Irrelevant to the decision, since none may be emitted while blocking defects stand.)_

## Pairwise scan — contradictions & overlaps

Every pair was compared. One blocking pair found; no contradictions.

- ⚠ **Overlap suspect — #8 ⟷ #9 (the "sandwich" restated at two granularities).**
  #8 states the pure/impure separation as a whole-program structural property
  ("`impure → pure → impure`; read/compute/write"); #9 states the *same*
  separation at statement granularity ("never mix pure and impure on one line").
  A line that violates #9 is the atomic instance of the structure #8 mandates —
  the two rules flag the same underlying defect and would double-count findings.
  The author should keep the checkable statement-level rule (#9) and drop, or
  demote to rationale, the whole-flow restatement (#8).

- **Contradictions:** none found.

## What to do next  ← the cleanup worklist

This report is validation only — the guidelines are **never rewritten** here.
Recommended edits to the author, then re-run this validator:

1. **Split or delete the `reject` rows** (unbounded/whole-paradigm): #1, #8, #10,
   #11, #13, #14, #15, #17, #21, #22, #25. Each needs to become a concrete,
   single-condition rule or be removed. A whole-paradigm mandate ("apply ROP",
   "make illegal states unrepresentable") has no single concrete violation to look
   for and cannot drive a per-file review.
2. **Resolve the overlap** #8 ⟷ #9 by keeping only one phrasing (the file-local #9).
3. The **`out-of-scope`** rows (#2–#7, #16, #23, #24, #28) are sound architectural
   rules but not file-grain-decidable — they are not defects to fix in the doc;
   on a clean re-run they would be recorded in `rules.json`'s `outOfScope[]`,
   never in `rules[]`, and would never block. They are enforced by the
   architecture test, not by the per-file reviewer.

Once the reject rows are split/removed and the overlap resolved, re-run the
validator to emit `rules.json`.
