import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: {
    contents: [
      "export { inspectionValue } from './staff/model';",
      "export { staffNotice } from './staff/notice';",
      "export { HISTORY_NOT_RECORDED, STORAGE_FAILED, NO_HISTORY } from './staff/strings';",
    ].join("\n"),
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const { inspectionValue, staffNotice, HISTORY_NOT_RECORDED, STORAGE_FAILED, NO_HISTORY } =
  await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`);

// "Not recorded" is its own state, never read as an empty history.
assert.notEqual(HISTORY_NOT_RECORDED, NO_HISTORY);
const target = { round: "4", kind: "entity", id: "9" };
const unrecorded = inspectionValue({ target, found: true, tombstone: false, audit: [], history: "not_recorded" }, "4");
assert.equal(unrecorded.historyRecorded, false);
const recorded = inspectionValue({ target, found: true, tombstone: false, audit: [], history: "recorded" }, "4");
assert.equal(recorded.historyRecorded, true, "an empty recorded audit means nothing happened");

// The engine's own refusal keys read as their own notices.
assert.equal(staffNotice({ error: "staff.history_not_recorded" }).message, HISTORY_NOT_RECORDED);
assert.equal(staffNotice({ error: "staff.storage_failed" }).message, STORAGE_FAILED);

console.log("staff history state: not recorded is distinct from no history, and its refusals read as notices");
