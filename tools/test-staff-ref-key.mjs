import assert from "node:assert/strict";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  entryPoints: [fileURLToPath(new URL("../ui/staff/cases/records.ts", import.meta.url))],
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const { refKey, uniqueRefs } = await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`);

// A plain colon join folds these into the same string — the wire
// charset lets `:` occur inside `kind` and `id` (lunatic-core's
// `validate_identifier`), so a colon that lands in one field can shift
// where the next field's boundary appears to be:
//   "7" + ":" + "case:1" + ":" + "9"  ==  "7:case:1:9"
//   "7:case" + ":" + "1" + ":" + "9"  ==  "7:case:1:9"
// yet the two refs below name different rounds and kinds.
const a = { round: "7", kind: "case:1", id: "9" };
const b = { round: "7:case", kind: "1", id: "9" };
assert.notEqual(refKey(a), refKey(b), "refs with different round/kind must not share a key");
assert.equal(uniqueRefs([a, b]).length, 2, "a colliding key would have folded these into one");
console.log("staff ref key: refs that collided under a colon join stay distinct");
