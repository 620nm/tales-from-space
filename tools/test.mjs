#!/usr/bin/env node
// The pack's node tests, in one run: the lints over ui/ and content/,
// then every tools/test-*.mjs against the engine checkout's SDK. The
// engine is the first argument or LUNATIC_ENGINE, else the checkout
// beside this one; the engine's gate runs this as its `pack-node` lane.
//
//   node tools/test.mjs [/abs/path/to/lunatic]
import { spawnSync } from "node:child_process";
import { readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const TOOLS = join(ROOT, "tools");
const engine = resolve(process.argv[2] ?? process.env.LUNATIC_ENGINE ?? join(ROOT, "..", "lunatic"));

const steps = [
  ["theme-lint", [join(TOOLS, "theme-lint.mjs")]],
  ["keyed-messages", [join(TOOLS, "keyed-messages.mjs"), "--check"]],
  ...readdirSync(TOOLS).filter((name) => /^test-.*\.mjs$/.test(name)).sort()
    .map((name) => [name.replace(/\.mjs$/, ""), [join(TOOLS, name), engine]]),
];

let failed = 0;
for (const [name, args] of steps) {
  const run = spawnSync(process.execPath, args, {
    cwd: ROOT, encoding: "utf8", env: { ...process.env, LUNATIC_ENGINE: engine },
  });
  const ok = run.status === 0;
  console.log(`${ok ? "ok  " : "FAIL"}  ${name}`);
  if (!ok) {
    failed++;
    process.stdout.write(run.stdout ?? "");
    process.stderr.write(run.stderr ?? "");
  }
}
if (failed) {
  console.error(`${failed} of ${steps.length} pack node steps failed`);
  process.exit(1);
}
