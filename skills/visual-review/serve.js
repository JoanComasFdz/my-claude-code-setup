#!/usr/bin/env node
"use strict";
/*
 * serve.js — view a visual-review report with click-to-open-in-VS-Code.
 *
 *   node serve.js [rootDir]     # rootDir defaults to cwd; run it from the REPO ROOT
 *   PORT=8000 node serve.js .
 *
 * Serves static files from rootDir AND handles:
 *   GET /__open?path=<repo-relative>&line=<n>
 *       → runs `code --goto <abs>:<line>:1`, opening the file in the VS Code
 *         window attached to this container/session.
 *
 * The report's source links fetch() that endpoint, so clicking a finding's
 * location opens the real file in your editor instead of downloading it.
 *
 * Requirements: run from a VS Code integrated terminal (so `code` is on PATH and
 * VSCODE_IPC_HOOK_CLI is inherited). No npm dependencies — Node built-ins only.
 */
const http = require("http");
const fs = require("fs");
const path = require("path");
const url = require("url");
const { execFile } = require("child_process");

const ROOT = path.resolve(process.argv[2] || process.cwd());
const PORT = parseInt(process.env.PORT || "8000", 10);

const MIME = {
  ".html": "text/html; charset=utf-8", ".htm": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg", ".gif": "image/gif",
  // everything else (incl. .cs) → text/plain so it displays inline, never a download
};

function inside(root, p) { const r = path.resolve(p); return r === root || r.startsWith(root + path.sep); }

const server = http.createServer((req, res) => {
  const u = url.parse(req.url, true);

  if (u.pathname === "/__open") {
    const rel = String(u.query.path || "").replace(/^\/+/, "");
    const line = (String(u.query.line || "1").match(/\d+/) || ["1"])[0];
    const abs = path.join(ROOT, rel);
    if (!inside(ROOT, abs)) { res.writeHead(400); return res.end("path outside root"); }
    execFile("code", ["--goto", abs + ":" + line + ":1"], { env: process.env }, (err) => {
      if (err) {
        res.writeHead(500, { "Content-Type": "text/plain" });
        res.end("`code --goto` failed: " + err.message +
          "\nRun serve.js from a VS Code integrated terminal so `code` is on PATH.");
      } else { res.writeHead(204); res.end(); }
    });
    return;
  }

  let p = decodeURIComponent(u.pathname);
  if (p.endsWith("/")) p += "index.html";
  const abs = path.join(ROOT, p);
  if (!inside(ROOT, abs)) { res.writeHead(403); return res.end("forbidden"); }
  fs.readFile(abs, (err, buf) => {
    if (err) { res.writeHead(404, { "Content-Type": "text/plain" }); return res.end("not found: " + p); }
    const ext = path.extname(abs).toLowerCase();
    res.writeHead(200, { "Content-Type": MIME[ext] || "text/plain; charset=utf-8" });
    res.end(buf);
  });
});

server.listen(PORT, () => {
  console.log("visual-review server → http://localhost:" + PORT + "  (root: " + ROOT + ")");
  console.log("click-to-open-in-VS-Code: " + (process.env.VSCODE_IPC_HOOK_CLI ? "enabled" : "DISABLED (VSCODE_IPC_HOOK_CLI not set — run from the VS Code terminal)"));
});
