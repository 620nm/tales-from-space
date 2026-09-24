import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
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
globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))) };
const { cursorReopenQuery } = await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`);

const anchor = { round: "4", kind: "entity", id: "9" };
const session = (response) => ({ roundId: "4", records: { response } });
const refused = (requestId, query) => session({ request_id: requestId, query, error: "staff.cursor_not_issued" });

// A cursor the server no longer issued (a reconnect, a round cutover)
// reopens the same query from its first page, once per response.
const dead = refused("r-1", { op: "context", anchor, after: "77", limit: 64 });
assert.deepEqual(cursorReopenQuery(dead), { kind: "query", query: JSON.stringify({ op: "context", anchor, limit: 64 }) });
assert.equal(cursorReopenQuery(dead), null, "the same response never reopens twice");
const deadCases = refused("r-2", { op: "cases", after: "12", limit: 64 });
assert.deepEqual(JSON.parse(cursorReopenQuery(deadCases).query), { op: "cases", limit: 64 });

// An opening page, another refusal, or a page that answered never reopens.
assert.equal(cursorReopenQuery(refused("r-3", { op: "cases", limit: 64 })), null);
assert.equal(cursorReopenQuery(session({ request_id: "r-4", query: { op: "cases", after: "1" }, error: "staff.history_not_recorded" })), null);
assert.equal(cursorReopenQuery(session({ request_id: "r-5", query: { op: "cases", after: "1" }, result: { kind: "cases", items: [] } })), null);
assert.equal(cursorReopenQuery(session(null)), null);

console.log("staff cursor reopen: a refused cursor reopens its query from the first page, once");
