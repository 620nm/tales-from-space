#!/usr/bin/env node
// Where a colour and a look may be spelled under ui/.
//
// A hex colour lives in `ui/theme/tokens.ts` and nowhere else: every
// other file draws with a token, so a repaint is one edit. An inline
// `style` on a node says only where the node goes and how big it is —
// position, offsets, size, grid placement, and the `animation` the host
// composes its own fade over (docs/pack-ui/styles.md) — and never how
// it looks: that belongs to a class in `ui/theme/`. A line that must
// carry a value from data (a substance's colour, a heading's level)
// says so with `theme-lint: allow` on its own line or the one before.
//
//   node tools/theme-lint.mjs     exit 1 on a finding
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const UI = join(ROOT, "ui");
const TOKENS = join(UI, "theme", "tokens.ts");
const PLACEMENT = new Set([
  "position", "left", "top", "right", "bottom",
  "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
  "gridColumn", "gridRow", "gridTemplateColumns", "gridTemplateRows",
  "animation",
]);
const HEX = /#[0-9a-fA-F]{3,8}\b/g;
const ALLOW = /theme-lint:\s*allow/;

/** Every source under ui/, build products and fixtures aside. */
function sources(dir) {
  const out = [];
  for (const name of readdirSync(dir).sort()) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      if (name !== "fixtures") out.push(...sources(path));
    } else if (/\.tsx?$/.test(name)) out.push(path);
  }
  return out;
}

/** The top-level keys of the object literal opening at `start`, or
 *  null when the brace never closes. Spreads are skipped. */
function keys(text, start) {
  let depth = 0, i = start, entry = "", quote = null;
  const out = [];
  const take = () => {
    const key = /^\s*(?:\.\.\.|(["']?)([A-Za-z_$][\w$]*)\1\s*:)/.exec(entry);
    if (key && key[2]) out.push(key[2]);
    entry = "";
  };
  for (; i < text.length; i++) {
    const c = text[i];
    if (quote) {
      if (c === "\\") i++;
      else if (c === quote) quote = null;
      entry += c;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") { quote = c; entry += c; continue; }
    if (c === "{" || c === "(" || c === "[") { depth++; if (depth > 1) entry += c; continue; }
    if (c === "}" || c === ")" || c === "]") {
      depth--;
      if (depth === 0) { take(); return out; }
      entry += c;
      continue;
    }
    if (c === "," && depth === 1) { take(); continue; }
    entry += c;
  }
  return null;
}

const findings = [];
for (const path of sources(UI)) {
  const text = readFileSync(path, "utf8");
  const file = relative(ROOT, path);
  const lines = text.split("\n");
  const lineAt = (offset) => text.slice(0, offset).split("\n").length;
  const allowed = (line) => ALLOW.test(lines[line - 1] ?? "") || ALLOW.test(lines[line - 2] ?? "");
  if (path !== TOKENS)
    for (const hit of text.matchAll(HEX)) findings.push(`${file}:${lineAt(hit.index)}: colour ${hit[0]} outside ui/theme/tokens.ts`);
  // `style: {` on a node, `style = {` on a const, and `style.prop =`.
  for (const hit of text.matchAll(/\bstyle\b\s*(?::\s*[\w|\s<>[\]]+?)?\s*[:=]\s*(?:[^{;\n]*\?\s*)?\{/g)) {
    const line = lineAt(hit.index);
    if (allowed(line)) continue;
    const props = keys(text, hit.index + hit[0].length - 1);
    if (!props) continue;
    for (const prop of props)
      if (!PLACEMENT.has(prop)) findings.push(`${file}:${line}: inline style sets ${prop}; a look belongs to a class in ui/theme/`);
  }
  for (const hit of text.matchAll(/\bstyle\.([A-Za-z]\w*)\s*=[^=]/g)) {
    const line = lineAt(hit.index);
    if (!allowed(line) && !PLACEMENT.has(hit[1])) findings.push(`${file}:${line}: inline style sets ${hit[1]}; a look belongs to a class in ui/theme/`);
  }
}

for (const finding of findings) console.error(finding);
if (findings.length) {
  console.error(`theme-lint: ${findings.length} finding(s)`);
  process.exit(1);
}
console.log("theme-lint: clean");
