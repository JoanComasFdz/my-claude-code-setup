# Expected verdicts — messy-freeform (loose worklist key)

This is the real variance-lots-check CONVENTIONS.md. The exact rule split is not asserted;
the validator must AT MINIMUM get these landmark calls right, and must HARD STOP overall:

- ✅ actionable: "Name functions/methods with a verb, never a bare noun"; "Prefer static direct calls over interfaces/delegates"; "Domain types are immutable records"; "Construct Dunet cases with `new` (no static factories)".
- ⛔ reject (composite / unbounded): "Vertical Slice Architecture is the top-level driver"; "Make illegal states unrepresentable"; "Railway-oriented (ROP) for the end-to-end flow" (whole-paradigm, not one-file-decidable).
- 🚫 out of scope (needs a repo-level map): "Feature slices depend only on the shared kernel — never sideways"; "Domain never depends on a feature slice or on System.IO"; the `Orchestration → every slice` / `PreFlightValidation → validated slices` boundary rules.
- Overlap suspects to surface: the several restatements of the pure/impure "sandwich" rule (§ Functional design) that say the same thing at different granularity.

**Expected run outcome:** HARD STOP (reject + overlap present). No rules.json emitted. This fixture's PURPOSE is the produced report, which Task 7 ships as the dogfood worklist.
