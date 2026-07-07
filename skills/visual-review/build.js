#!/usr/bin/env node
"use strict";
/*
 * build.js — render a visual-review report.
 *
 *   node build.js <findings.json> [out.html]
 *
 * Injects the findings JSON into template.html (co-located with this script)
 * and writes a self-contained HTML file. No dependencies — Node built-ins only.
 * The agent authors ONLY the findings JSON; presentation lives in template.html,
 * so every report is consistent (never hand-written HTML).
 */
const fs = require("fs");
const path = require("path");

const [, , findingsPath, outArg] = process.argv;
if (!findingsPath) {
  console.error("usage: node build.js <findings.json> [out.html]");
  process.exit(2);
}

const here = __dirname;
const templatePath = path.join(here, "template.html");
const MARKER = "__REVIEW_JSON__";

let raw, template;
try { raw = fs.readFileSync(findingsPath, "utf8"); }
catch (e) { console.error("cannot read findings: " + e.message); process.exit(1); }
try { template = fs.readFileSync(templatePath, "utf8"); }
catch (e) { console.error("cannot read template.html next to build.js: " + e.message); process.exit(1); }

// Validate it is JSON and re-serialize compactly (fail loudly on malformed data).
let data;
try { data = JSON.parse(raw); }
catch (e) { console.error("findings file is not valid JSON: " + e.message); process.exit(1); }

if (template.indexOf(MARKER) === -1) {
  console.error("template.html is missing the " + MARKER + " marker.");
  process.exit(1);
}

// Escape any "</" so an embedded snippet can never close the <script> tag early.
const json = JSON.stringify(data).replace(/<\//g, "<\\/");
const html = template.replace(MARKER, json);

const out = outArg || deriveOut(data);
fs.writeFileSync(out, html);

const n = (data.findings || []).length;
console.log("wrote " + out + "  (" + n + " finding" + (n === 1 ? "" : "s") + ", " +
  Buffer.byteLength(html) + " bytes)");

function deriveOut(d) {
  const m = (d && d.meta) || {};
  const base = (m.subproject ? m.subproject + "/" : "") +
    (m.reportSlug || "code-review") + (m.date ? "-" + m.date : "") + ".html";
  return base;
}
