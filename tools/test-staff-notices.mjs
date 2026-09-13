import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  entryPoints: [fileURLToPath(new URL("../ui/staff/notice.ts", import.meta.url))],
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))) };
const { staffNotice } = await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`);
const notice = (result, error = null) => staffNotice({ records: { response: { result, error } } });
assert.equal(notice({ action: "restore", applied: true, revived: true }).message, "Restore applied.");
const partial = notice({ action: "restore", applied: true, revived: false, reason: "Missing viable anatomy" });
assert.match(partial.message, /Restore applied; revival did not complete: Missing viable anatomy/);
assert.equal(partial.tone, "staff-warning");
assert.match(notice(null, "Target retired").message, /Request failed: Target retired/);
assert.equal(notice({ kind: "profile" }), null);
console.log("staff notices: applied restoration, partial revival and refusals remain distinct");
