# Guideline-validator scenarios

Dispatch each as a FRESH general-purpose subagent on Opus. Two arms per fixture.

## RED arm (baseline — no skill)

**Isolation is mandatory (learned the hard way).** The fixtures live inside this
tool's own repo, next to `DESIGN.md`, `rules-schema.json`, and each fixture's
`expected-verdicts.md` answer key. A capable agent given filesystem access will
find and execute the methodology + the answer key, producing a false GREEN
baseline. So a RED run must **paste the conventions inline** and forbid file
access — no methodology and no answer key to discover. In production this leakage
can't happen (the user's CONVENTIONS.md sits in their repo; there is no answer
key), so inline-paste is the faithful baseline, not an artificial one.

Prompt, verbatim, with no reference to guideline-validator and no methodology hints
(no "decidability", "reject/out-of-scope", "contradiction", "hard stop"):

> This is a real task. Our team keeps the coding-conventions document pasted below.
> We're about to run an automated per-file code review that checks every source
> file against these conventions. Prepare the conventions for that review: produce,
> as JSON, the list of rules the review should enforce.
>
> Work ONLY from the conventions text below. Do not read any files, do not explore
> the repository. Reply with (1) the JSON rule list and (2) a short note on what you
> did and whether anything about these conventions blocks or concerns you.
>
> --- CONVENTIONS ---
> <paste the fixture's guidelines.md / concatenated folder files here>
> --- END CONVENTIONS ---

## GREEN arm (with skill)
Prompt:

> Read and follow `guideline-validator/SKILL.md` exactly. Validate the guidelines at
> `<FIXTURE>` (a single file, or the folder for the folder case). Write outputs to
> `<OUT_DIR>`. Report what you wrote and your stop/emit decision.

## Assertions
| Fixture | Expected (see the fixture's expected-*.md) |
|---|---|
| synthetic-freeform | HARD STOP; report lists R1–R6 with the keyed verdicts; NO rules.json |
| clean | EMIT rules.json (validateRulesShape ok); 3 rules; outOfScope=[layering]; no stop |
| folder-shape | EMIT rules.json; ids == filenames; 2 rules; outOfScope=[layering] |
| messy-freeform | HARD STOP; landmark verdicts correct; NO rules.json |

Fixture absolute paths (this worktree):
- synthetic: `/workspace/.claude/worktrees/guideline-validator/__code-review-skill/guideline-validator/test/fixtures/synthetic-freeform/guidelines.md`
- clean:     `.../test/fixtures/clean/guidelines.md`
- folder:    `.../test/fixtures/folder-shape/`  (the directory)
- messy:     `.../test/fixtures/messy-freeform/CONVENTIONS.md`
