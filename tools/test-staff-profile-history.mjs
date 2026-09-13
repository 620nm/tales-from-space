import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: {
    contents: [
      "export { default as ui } from './staff/main';",
      "export { readStaff } from './staff/model';",
      "export { eventFrom, readRef } from './staff/cases/records';",
      "export { conversationFor, profileView } from './staff/profile/data';",
      "export { identityCard } from './staff/shared/identity-card';",
      "export { historicalEventTime } from './staff/shared/presentation';",
    ].join("\n"),
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const formatterBundle = await build({
  stdin: {
    contents: [
      "import { historicalEventTime } from './staff/shared/presentation';",
      "export default { render(view) { return { id: 'timestamp', type: 'text', text: historicalEventTime(undefined, view.timestamp) }; } };",
    ].join("\n"),
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const runtimeBundle = await build({
  entryPoints: [resolve(engine, "web/src/pack-ui/runtime.ts")],
  bundle: true, format: "esm", packages: "bundle", platform: "node", write: false,
});
const { ui, readStaff, conversationFor, eventFrom, profileView, readRef, identityCard, historicalEventTime } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);
const scratchRoot = process.env.LUNATIC_TEST_TMP ?? tmpdir();
await mkdir(scratchRoot, { recursive: true });
const runtimeDir = await mkdtemp(join(scratchRoot, "staff-history-"));
const runtimePath = join(runtimeDir, "runtime-test.mjs");
await writeFile(runtimePath, runtimeBundle.outputFiles[0].text);
const { GuestRuntime } = await import(pathToFileURL(runtimePath).href);
await rm(runtimeDir, { recursive: true, force: true });
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))),
};

const fixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-profile.json", import.meta.url)));
const liveFixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-live.json", import.meta.url)));
const view = fixture.view;
const payload = view.state.staff.payload;
const accountId = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
payload.current_round = "85";
view.state.staff.round_id = "85";
payload.records.response.result.profile.conversations = [{
  reference: { round: "84", kind: "conversation", id: "7001" },
  account: { round: "", kind: "account", id: accountId },
}];

test("historical case, context and conversation references survive a new round", () => {
  const session = readStaff(view);
  assert(session);
  assert.equal(session.roundId, "85");
  assert.equal(session.cases[0].reference.round, "84");
  assert(session.inspector);
  assert.deepEqual(session.inspector.target, { round: "84", kind: "item", id: "4294967300" });
  assert.equal(session.inspector.found, true);
  assert.equal(session.inspector.tombstone, false);

  const source = eventFrom(payload.selected.audit[0], session.roundId);
  assert(source);
  assert.equal(source.reference.round, "84");
  assert.equal(source.mindRef?.round, "84");

  const profile = profileView(session, accountId);
  assert(profile);
  const conversation = conversationFor(session, profile);
  assert(conversation);
  assert.deepEqual(conversation.reference, { round: "84", kind: "conversation", id: "7001" });
});

test("historical item spawns keep their root target, timestamp and cursors", () => {
  const timestamp = 1789251650531;
  const refs = [
    4294965721, 4294965722, 4294965723, 4294965724,
    4294965725, 4294965726, 4294965728,
  ].map((id) => ({ round: "2", kind: "entity", id: String(id) }));
  const row = {
    reference: { round: "2", kind: "event", id: "126" },
    event_type: "item_spawned",
    server_id: "history-server",
    created_at_ms: timestamp,
    payload: { event: "item_spawned", item_id: 4294965728, seq: 125 },
    refs,
    tick: 125,
    deleted: false,
  };
  const source = eventFrom(row, "3");
  assert(source);
  assert.equal(source.reference.id, "126");
  assert.equal(source.sourceSeq, "125");
  assert.equal(source.createdAtMs, timestamp);
  assert.equal(source.time, "2026-09-12 22:20:50.531 UTC");
  assert.deepEqual(source.targetRef, refs.at(-1));
  assert.equal(source.target, "4294965728");
  assert.deepEqual(source.refs, refs);

  const copy = JSON.parse(JSON.stringify(view));
  copy.state.staff.round_id = "3";
  copy.state.staff.payload.current_round = "3";
  copy.state.staff.payload.audit = [row];
  const session = readStaff(copy);
  assert(session);
  const parsed = session.audit[0];
  assert(parsed);
  assert.equal(parsed.reference.id, "126");
  assert.equal(parsed.sourceSeq, "125");
  assert.equal(parsed.createdAtMs, timestamp);
  assert.equal(parsed.time, "2026-09-12 22:20:50.531 UTC");
  assert.deepEqual(parsed.targetRef, refs.at(-1));
  assert.equal(parsed.target, "4294965728");
  assert.deepEqual(parsed.refs, refs);
});

test("historical timestamps format deterministically without Date", async () => {
  const quickJs = await GuestRuntime.create({
    version: 6,
    id: "staff-history-test",
    slot: "staff",
    audience: "staff",
    entry: "main.js",
      modules: { "main.js": formatterBundle.outputFiles[0].text },
  }, resolve(engine, "web/node_modules/@jitl/quickjs-wasmfile-release-sync/dist/emscripten-module.wasm"), {
    tag: "en", catalog: globalThis.__lunaticLocale.catalog,
  });
  const originalDate = globalThis.Date;
  try {
    globalThis.Date = undefined;
    assert.equal(historicalEventTime(undefined, 0), "1970-01-01 00:00:00.000 UTC");
    assert.equal(historicalEventTime(undefined, -1), "1969-12-31 23:59:59.999 UTC");
    assert.equal(historicalEventTime(undefined, 951782400000), "2000-02-29 00:00:00.000 UTC");
    assert.equal(historicalEventTime(undefined, 1789251650531), "2026-09-12 22:20:50.531 UTC");
    const liveSession = readStaff(liveFixture.view);
    assert(liveSession);
    assert.equal(liveSession.audit.find((event) => event.id === "905")?.time, "2026-09-12 22:20:50.531 UTC");
    const liveRow = liveFixture.view.state.staff.payload.audit.find((event) => event.reference?.id === "905");
    assert(liveRow);
    assert.equal(quickJs.render({ timestamp: liveRow.created_at_ms }).text, "2026-09-12 22:20:50.531 UTC");
    assert.equal(historicalEventTime(undefined, -8640000000000001), "—");
    assert.equal(historicalEventTime(undefined, 8640000000000001), "—");
    assert.equal(historicalEventTime(undefined, Number.MAX_SAFE_INTEGER), "—");
    assert.equal(historicalEventTime(undefined, Number.NaN), "—");
  } finally {
    globalThis.Date = originalDate;
    quickJs.dispose();
  }
});

test("known ids stay typed while future references use the core grammar", () => {
  assert.deepEqual(readRef({ round: "84", kind: "event", id: "901" }, "85"), { round: "84", kind: "event", id: "901" });
  assert.deepEqual(readRef({ round: "84", kind: "virus", id: "spore-alpha" }, "85"), { round: "84", kind: "virus", id: "spore-alpha" });
  assert.equal(readRef({ round: "84", kind: "event", id: "cursor-901" }, "85"), null);
});

test("profile queries retain the server role over ambient identity summaries", () => {
  const copy = JSON.parse(JSON.stringify(view));
  copy.state.staff.payload.records.response.result.profile.identity = {
    id: accountId, username: "Rowan", avatar: "unknown", role: "owner",
  };
  const session = readStaff(copy);
  const ambient = session.profiles.find((profile) => profile.id === accountId);
  assert(ambient);
  ambient.role = "";
  const profile = profileView(session, accountId);
  assert(profile);
  assert.equal(profile.profile.role, "owner");
  const card = identityCard("test/profile", { ...profile.profile, role: "" });
  assert.equal(findNode(card, "test/profile/role").text, "Player");
  const owner = identityCard("test/owner", { ...profile.profile, role: "owner" });
  assert.equal(findNode(owner, "test/owner/role").text, "Owner");
});

test("profile cards open the cases profile drill with a canonical profile query", () => {
  const rendered = ui.render(view);
  const profileButton = findNode(rendered, "staff/cases/event/901/profile/open");
  assert(profileButton);
  assert.equal(profileButton.type, "button");
  const action = ui.onEvent({ id: profileButton.id, type: "activate" }, view).action;
  assert(action);
  const query = JSON.parse(action.request.action.Query.query);
  assert.equal(query.op, "profile");
  assert.deepEqual(query.target, { round: "", kind: "account", id: accountId });
});

function findNode(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = findNode(child, id);
    if (found) return found;
  }
  return null;
}
