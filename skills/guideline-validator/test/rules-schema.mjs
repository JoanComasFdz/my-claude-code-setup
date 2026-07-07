// Dependency-free shape check for rules.json (DESIGN.md §6).
// Kept deliberately structural: it proves well-formedness, not rule quality.
const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const SHA256 = /^[a-f0-9]{64}$/;

export function validateRulesShape(obj) {
  const errors = [];
  const req = (cond, msg) => { if (!cond) errors.push(msg); };

  if (!obj || typeof obj !== "object" || Array.isArray(obj)) {
    return { ok: false, errors: ["root must be an object"] };
  }

  const s = obj.source;
  req(s && typeof s === "object" && !Array.isArray(s), "source: required object");
  if (s && typeof s === "object") {
    req(typeof s.path === "string" && s.path.length > 0, "source.path: required non-empty string");
    req(typeof s.contentHash === "string" && SHA256.test(s.contentHash),
        "source.contentHash: required 64-char lowercase hex");
  }

  req(Array.isArray(obj.rules), "rules: required array");
  if (Array.isArray(obj.rules)) {
    obj.rules.forEach((r, i) => {
      req(r && typeof r === "object" && !Array.isArray(r), `rules[${i}]: must be object`);
      if (r && typeof r === "object") {
        req(typeof r.id === "string" && SLUG.test(r.id), `rules[${i}].id: required kebab-case slug`);
        req(typeof r.statement === "string" && r.statement.length > 0, `rules[${i}].statement: required non-empty string`);
        req(typeof r.sourceAnchor === "string" && r.sourceAnchor.length > 0, `rules[${i}].sourceAnchor: required non-empty string`);
        if ("rationale" in r) req(typeof r.rationale === "string", `rules[${i}].rationale: must be string when present`);
      }
    });
    const ids = obj.rules.filter(r => r && typeof r.id === "string").map(r => r.id);
    req(new Set(ids).size === ids.length, "rules[].id: ids must be unique within the run");
  }

  req(Array.isArray(obj.outOfScope), "outOfScope: required array (use [] when none)");
  if (Array.isArray(obj.outOfScope)) {
    obj.outOfScope.forEach((o, i) => {
      req(o && typeof o === "object" && !Array.isArray(o), `outOfScope[${i}]: must be object`);
      if (o && typeof o === "object") {
        req(typeof o.statement === "string" && o.statement.length > 0, `outOfScope[${i}].statement: required non-empty string`);
        req(typeof o.reason === "string" && o.reason.length > 0, `outOfScope[${i}].reason: required non-empty string`);
      }
    });
  }

  return { ok: errors.length === 0, errors };
}
