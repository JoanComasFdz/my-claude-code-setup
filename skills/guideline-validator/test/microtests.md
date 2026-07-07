# Verdict-rubric micro-test

**Question:** does the rubric make the reject-vs-out-of-scope boundary — the one the
baseline conflated — convergent and correct?

**Setup:** 6 probes; 5 rubric-arm reps (rubric pasted inline) + 2 no-guidance control
reps; fresh Opus agents, conventions inline, no file access. Every response read by hand.

**Answer key:** P1 actionable · P2 reject · P3 out-of-scope · P4 reject · P5 reject · P6 out-of-scope.

| Probe | Expected | Rubric r1 | r2 | r3 | r4 | r5 | Control c1 | c2 |
|---|---|---|---|---|---|---|---|---|
| P1 "verb name" | actionable | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P2 "apply SOLID / clean / maintainable" | reject | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P3 "domain ⇏ infrastructure" | out-of-scope | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P4 "keep methods small" | reject | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **P5 "railway-oriented end-to-end flow"** | **reject** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ out-of-scope | ✅ |
| P6 "slices ⇏ sideways" | out-of-scope | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Rubric arm: 30/30, zero variance across reps.** The wording is binding.

**Control arm** wavers on exactly the discriminating case: P5 (whole-paradigm "apply
ROP"). c1 called it out-of-scope, c2 reject — the reject/out-of-scope boundary is
unbound without the rubric, matching the messy baseline (Run 4), which kept ROP,
effects-as-data, typestate etc. as enforceable/architectural rather than rejecting them.
The other probes are clear-cut enough that a capable agent classifies them either way;
the rubric's value concentrates on the whole-paradigm reject-vs-out-of-scope call.

**Conclusion:** the explicit "a whole-paradigm mandate ('apply ROP', 'make illegal
states unrepresentable') is reject, not out-of-scope" clause is what binds P5. Zero
variance across rubric reps → no wording change needed. Proceed to full GREEN scenarios.
