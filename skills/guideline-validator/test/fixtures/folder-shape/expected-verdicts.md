# Expected verdicts — folder-shape

| File | id (= filename) | Verdict |
|---|---|---|
| verb-naming.md | verb-naming | ✅ actionable |
| no-null-absence.md | no-null-absence | ✅ actionable |
| layering.md | layering | 🚫 out of scope |

**Expected run outcome:** No blocking defect → EMIT rules.json. rules[] ids equal the filenames (NOT statement slugs). 2 rules; outOfScope has 1 entry (layering). Passes validateRulesShape.
