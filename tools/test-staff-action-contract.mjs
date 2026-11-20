import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Pass the engine checkout path.");

const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: {
    contents: "export { staffRequest } from './staff/shared/actions';",
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true,
  format: "esm",
  platform: "node",
  write: false,
});
const { staffRequest } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);

const fixturePath = resolve(engine, "crates/lunatic-client/tests/fixtures/staff-edits.json");
const cases = JSON.parse(await readFile(fixturePath, "utf8"));
const session = { roundId: "84", revision: "9007199254740993" };

assert.equal(cases.length, 9, "the contract covers every staff edit verb");
for (const [index, { semantic, wire }] of cases.entries()) {
  const action = staffRequest(session, semantic);
  assert.deepEqual(action.request.action, wire, `staff edit wire case ${index + 1}`);
}

console.log("staff action contract: all nine pack edit verbs match the native wire shape");
