import test from "node:test";
import assert from "node:assert/strict";
import { validateRulesShape } from "./rules-schema.mjs";

const VALID = {
  source: { path: "guidelines.md", contentHash: "a".repeat(64) },
  rules: [
    { id: "verb-naming", statement: "Every function name contains a verb.", sourceAnchor: "## Naming" }
  ],
  outOfScope: [
    { statement: "The domain must not depend on infrastructure.", reason: "needs a repo-level layer map" }
  ]
};

test("accepts a well-formed rule set", () => {
  const { ok, errors } = validateRulesShape(VALID);
  assert.equal(ok, true, errors.join("; "));
});

test("rejects a missing outOfScope array", () => {
  const bad = structuredClone(VALID); delete bad.outOfScope;
  assert.equal(validateRulesShape(bad).ok, false);
});

test("rejects a non-slug id", () => {
  const bad = structuredClone(VALID); bad.rules[0].id = "Verb Naming";
  assert.equal(validateRulesShape(bad).ok, false);
});

test("rejects a malformed contentHash", () => {
  const bad = structuredClone(VALID); bad.source.contentHash = "xyz";
  assert.equal(validateRulesShape(bad).ok, false);
});

test("rejects duplicate rule ids", () => {
  const bad = structuredClone(VALID);
  bad.rules = [bad.rules[0], { ...bad.rules[0] }];
  assert.equal(validateRulesShape(bad).ok, false);
});
