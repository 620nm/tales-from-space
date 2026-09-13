import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: {
    contents: "export { refKey as recordsRefKey, uniqueRefs } from './staff/cases/records';\nexport { refKey as modelRefKey } from './staff/model';",
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const { recordsRefKey, modelRefKey, uniqueRefs } = await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`);

// There is only one implementation: `cases/records.ts` re-exports
// `../model`'s `refKey` rather than defining its own, so both names
// bundle to the exact same function.
assert.equal(recordsRefKey, modelRefKey, "cases/records and model must share one refKey, not two");

// A plain colon join folds these into the same string — the wire
// charset lets `:` occur inside `kind` and `id` (lunatic-core's
// `validate_identifier`), so a colon that lands in one field can shift
// where the next field's boundary appears to be:
//   "7" + ":" + "case:1" + ":" + "9"  ==  "7:case:1:9"
//   "7:case" + ":" + "1" + ":" + "9"  ==  "7:case:1:9"
// yet the two refs below name different rounds and kinds.
const a = { round: "7", kind: "case:1", id: "9" };
const b = { round: "7:case", kind: "1", id: "9" };
for (const refKey of [recordsRefKey, modelRefKey]) {
  assert.notEqual(refKey(a), refKey(b), "refs with different round/kind must not share a key");
}
assert.equal(uniqueRefs([a, b]).length, 2, "a colliding key would have folded these into one");

// `model.ts`'s refKey also tolerates a missing ref, which several
// staff-side callers rely on (e.g. an unset review target).
assert.equal(modelRefKey(null), "");
assert.equal(modelRefKey(undefined), "");

console.log("staff ref key: one implementation, and refs that collided under a colon join stay distinct");
