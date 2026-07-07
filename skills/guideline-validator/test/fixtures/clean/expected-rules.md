# Expected outcome — clean fixture

- No blocking defect → validator EMITS rules.json (does not stop).
- rules.json passes validateRulesShape (Task 1).
- Exactly 3 rules; ids are slugs of the statements (order not asserted).
- outOfScope has exactly 1 entry: the domain→infrastructure rule (excluded, reported, NON-blocking).
- Slug ids are illustrative; assert the SET of statements + that every id is a kebab-slug, not exact slug spelling.

Note (2026-07-06): the immutability rule was originally "Domain types are immutable records" —
role-scoped to "domain types", which the validator (correctly, consistently with the layering
rule) sends to out-of-scope. Sharpened to "Every record type is immutable" so this slot tests a
plainly file-local actionable rule. The role-scoping behaviour is documented in SKILL.md instead.
