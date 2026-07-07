# Expected verdicts — synthetic-freeform

| # | Candidate rule (paraphrase) | Verdict | Why |
|---|---|---|---|
| R1 | Name every function with a verb | ✅ actionable | atomic, decidable reading one file |
| R2 | Constructors do no work beyond field assignment | ✅ actionable | decidable at file grain |
| R3 | Apply SOLID / keep the architecture clean | ⛔ reject | composite / unbounded — whole-paradigm |
| R4 | Domain must not depend on infrastructure | 🚫 out of scope | needs a repo-level layer map to interpret |
| R5a | A function has exactly one return (single exit) | ⛔ contradiction with R5b | single-exit forbids the extra returns guard clauses require |
| R5b | Use early-return guard clauses | ⛔ contradiction with R5a | — |
| R6a | Every public method has an XML `<summary>` | ⚠ overlap with R6b | same requirement, two phrasings → double-counted |
| R6b | All public members documented with `///` summaries | ⚠ overlap with R6a | — |

**Expected run outcome:** HARD STOP. The report must list every row above. Because a reject (R3), a contradiction (R5a/R5b) and an overlap (R6a/R6b) are present, the validator MUST NOT emit rules.json. R4 is reported as out-of-scope but is not itself the reason for the stop.
