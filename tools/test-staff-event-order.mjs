import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: {
    contents: "export { compareDecimalIds, compareEventOrder, eventsForCase } from './staff/shared/records';\nexport { caseFromRaw } from './staff/cases/records';",
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const { compareDecimalIds, compareEventOrder, eventsForCase, caseFromRaw } =
  await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`);

// A ledger row is `{round, event, seq}`: ids are decimal text, ordered as
// numbers, never as strings ("10" after "9").
assert.deepEqual(["10", "9", "100", "2"].sort(compareDecimalIds), ["2", "9", "10", "100"]);
const row = (round, id) => ({ reference: { round, kind: "event", id }, id, time: "", action: "a" });
const ordered = [row("10", "1"), row("9", "20"), row("9", "3")].sort(compareEventOrder);
assert.deepEqual(ordered.map((event) => `${event.reference.round}/${event.id}`), ["9/3", "9/20", "10/1"],
  "round first, then seq, both numeric");

// A case's addressed event names its round: the same seq in another round is
// another row, so it never joins the case's evidence.
const item = caseFromRaw({
  reference: { round: "4", kind: "case", id: "1" },
  label: "case",
  case_addressed_events: [{ round: "4", kind: "event", id: "7" }],
}, "4");
assert.deepEqual(item.eventRefs, [{ round: "4", kind: "event", id: "7" }]);
const session = { events: [row("4", "7"), row("5", "7")] };
assert.deepEqual(eventsForCase(session, item).map((event) => event.reference.round), ["4"]);

console.log("staff event order: rows sort by numeric round and seq, and a seq only matches in its round");
