#!/usr/bin/env node
// Turn `message = "…"` literals under `content/` into catalog keys.
//
// A player-visible sentence spelled in a Luau file is a sentence no
// translator can reach (docs/LOCALIZATION.md). This rewrites each one to
// `sim.msg("lunatic/tfs:<dir>.<file>.<slug>", {})` and writes the English
// it took into `locale/en.json`. Idempotent: a converted file has no
// literal left to take. `--check` writes nothing and fails on the first
// literal it finds, which is the lint a commit runs.
//
//   node tools/keyed-messages.mjs [--check]
//
// A line whose message is CONCATENATED is reported, never rewritten:
// joining fragments is the thing the rule forbids, so each of those is
// hand-authored as one complete template with placeholders.
import { readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const MOD = "lunatic/tfs";
const CHECK = process.argv.includes("--check");

/** Every `.luau` file under `content/`, in a stable order. */
function sources(dir) {
  const out = [];
  for (const name of readdirSync(dir).sort()) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...sources(path));
    else if (name.endsWith(".luau")) out.push(path);
  }
  return out;
}

/** `content/items/crowbar.luau` -> `items.crowbar`. */
function scope(path) {
  const parts = relative(join(ROOT, "content"), path).replace(/\.luau$/, "");
  return parts.split("/").join(".").toLowerCase();
}

/** A key segment out of what the sentence says: five words at most, so a
 *  reader of `locale/en.json` can find the line it renders. */
function slug(text) {
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .split(" ")
    .filter(Boolean)
    .slice(0, 5);
  return words.join("_") || "line";
}

// `message = "…"`, with the rest of the line kept so a concatenation can
// be told from a finished sentence.
const LITERAL = /message = "((?:[^"\\]|\\.)*)"([^\n]*)/g;

// Only what a send CARRIES. The same field name is a prototype's own
// data elsewhere — a vessel gesture's key, a `failure` line the engine
// draws itself — and neither is a sentence this rewrite owns.
const SENT = /sim\.message\.(?:send|broadcast)\(\{[^)]*$/;

// A keyed call is longer than the sentence it replaced, and a wrapped
// send reads better than one running off the screen. Only the shape the
// rewrite makes long is touched: one `sim.message.send`/`broadcast` whose
// whole table fits on its own line.
const CALL = /^(\s*)(sim\.message\.(?:send|broadcast))\(\{ (.*) \}\)(,?)$/;

/** Top-level commas of one inline table, ignoring nested calls. */
function fields(body) {
  const out = [];
  let depth = 0;
  let start = 0;
  let quoted = false;
  for (let i = 0; i < body.length; i += 1) {
    const c = body[i];
    if (quoted) {
      if (c === "\\") i += 1;
      else if (c === '"') quoted = false;
      continue;
    }
    if (c === '"') quoted = true;
    else if (c === "(" || c === "{" || c === "[") depth += 1;
    else if (c === ")" || c === "}" || c === "]") depth -= 1;
    else if (c === "," && depth === 0) {
      out.push(body.slice(start, i).trim());
      start = i + 1;
    }
  }
  out.push(body.slice(start).trim());
  return out;
}

function wrap(src) {
  return src
    .split("\n")
    .flatMap((line) => {
      if (line.length <= 100) return [line];
      const found = CALL.exec(line);
      if (!found) return [line];
      const [, pad, call, body, tail] = found;
      return [
        `${pad}${call}({`,
        ...fields(body).map((field) => `${pad}    ${field},`),
        `${pad}})${tail}`,
      ];
    })
    .join("\n");
}

const catalog = JSON.parse(readFileSync(join(ROOT, "locale/en.json"), "utf8"));
const joined = [];
let rewritten = 0;

for (const path of sources(join(ROOT, "content"))) {
  const src = readFileSync(path, "utf8");
  const taken = new Map();
  let changed = false;
  const out = src.replace(LITERAL, (whole, text, tail, at) => {
    if (!SENT.test(src.slice(0, at))) return whole;
    const line = src.slice(0, at).split("\n").length;
    if (tail.trimStart().startsWith("..")) {
      joined.push(`${relative(ROOT, path)}:${line}`);
      return whole;
    }
    if (CHECK) {
      joined.push(`${relative(ROOT, path)}:${line}`);
      return whole;
    }
    const stem = slug(text);
    const count = (taken.get(stem) ?? 0) + 1;
    taken.set(stem, count);
    const key = `${MOD}:${scope(path)}.${stem}${count > 1 ? `_${count}` : ""}`;
    catalog[key] = text.replace(/\\"/g, '"');
    changed = true;
    rewritten += 1;
    return `message = sim.msg("${key}", {})${tail}`;
  });
  if (changed) writeFileSync(path, wrap(out));
}

if (CHECK) {
  if (joined.length) {
    console.error(
      `a player-visible sentence is spelled in Luau, not in locale/:\n  ${joined.join("\n  ")}`,
    );
    process.exit(1);
  }
  console.log("no message literal under content/");
} else {
  writeFileSync(
    join(ROOT, "locale/en.json"),
    `${JSON.stringify(catalog, null, 2)}\n`,
  );
  console.log(`${rewritten} keyed, ${joined.length} concatenated by hand:`);
  for (const where of joined) console.log(`  ${where}`);
}
