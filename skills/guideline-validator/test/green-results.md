# GREEN verify — with-skill runs

Each fixture run as a fresh Opus agent in an **isolated run dir** (skill + input only;
no answer key, no DESIGN.md), following `SKILL.md`. Emitted `rules.json` machine-checked
with `validateRulesShape` (Task 1).

| Fixture | Expected | Actual | Verdict |
|---|---|---|---|
| synthetic-freeform | HARD STOP; verdicts R1–R6; no rules.json | HARD STOP; all verdicts correct; `validation-report.md` written | **PASS** |
| clean (v2) | EMIT; 3 actionable + 1 out-of-scope; schema-valid | EMIT; 3 rules + 1 outOfScope; `validateRulesShape` OK; 64-hex hash | **PASS** |
| folder-shape | EMIT; ids == filenames; 2 rules + 1 out-of-scope | EMIT; ids `verb-naming`,`no-null-absence`; 2+1; schema-valid; folder hash over sorted concat | **PASS** |
| messy-freeform | HARD STOP; landmark verdicts + the sandwich overlap | HARD STOP; VSA/ROP/make-illegal-states rejected; layering/slice rules out-of-scope; **caught the sandwich overlap**; no rules.json | **PASS** (loose key) |

## All four baseline failures are fixed
- **Hard-stop discipline** — synthetic AND messy both stopped and wrote NO `rules.json`.
  No `status: blocked`, no quarantine-and-emit. (Baseline Run 3/4's core failure.)
- **Output contract** — every emitted `rules.json` is schema-valid; a grep for
  `severity`/`status`/`checkability`/`scope`/`flagWhen` across all emitted files found
  **none**. (Baseline invented all of these.)
- **Overlap detection** — caught in synthetic (the two documentation rules) AND in messy
  (the pure/impure "sandwich" restated at two granularities). The baseline MISSED the
  sandwich overlap.
- **reject vs out-of-scope** — correct on every clear case; micro-tested 5/5 convergent.

## Findings (feed Task 6)

1. **Clean-fixture ambiguity (fixed, not a skill bug).** v1's immutability rule
   *"Domain types are immutable records"* was classified **out-of-scope** — consistently
   with how the skill treats *"domain must not depend on infrastructure"* (both scoped to
   "domain", which needs the repo layer map). Sound, uniform behaviour; the fixture was at
   fault for using a role-scoped rule in the "plain actionable" slot. Sharpened to *"Every
   record type is immutable"* (v2) → 3 actionable rules, as expected. **Task 6:** make this
   role-scoping behaviour *explicit* in the rubric so it is documented intent, not incidental.

2. **Borderline soft-rule rejection (accepted).** On the messy doc the agent rejected some
   soft/terse rules — "prefer static direct calls" ("soft 'prefer', no threshold") and the
   terse bundled "no null-as-absence". Note the *well-specified* folder-shape "no-null-absence"
   was correctly **actionable**. The difference is input quality: a terse/bundled statement is
   genuinely harder to pin down, and flagging it is the validator working as intended (the
   messy key is loose by design; the asserted landmarks all pass).

3. **No NEW rationalization/loophole surfaced.** The skill held under all four scenarios —
   the hard gate never leaked, no rule was rewritten, no forbidden field appeared. Task 6 is
   therefore a light pass: document the role-scoping (finding 1) and re-verify.
