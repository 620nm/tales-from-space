import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: {
    contents: [
      "export { readStaff } from './staff/model';",
      "export { entitiesForRef } from './staff/cases/records';",
      "export { profileDrill } from './staff/profile';",
    ].join("\n"),
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true,
  format: "esm",
  platform: "node",
  write: false,
});
const { readStaff, entitiesForRef, profileDrill } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))),
};

const fixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-live.json", import.meta.url))).view;
const round = "84";
const accountA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const accountB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const mind = "4294967307";

function cloneView() {
  const view = structuredClone(fixture);
  view.state.staff.round_id = round;
  view.state.staff.payload.current_round = round;
  return view;
}

function account(id) {
  return { round: "", kind: "account", id };
}

function mindRef(id, refRound = round) {
  return { round: refRound, kind: "mind", id };
}

function nodes(node) {
  return [node, ...(node?.children ?? []).flatMap(nodes)];
}

test("current account links to its live body through direct identity fields", () => {
  const view = cloneView();
  const body = view.state.staff.payload.world.entities[0];
  body.account_id = accountA;
  body.mind_id = mind;
  const session = readStaff(view);
  assert(session);
  assert.deepEqual(entitiesForRef(session, account(accountA)).map((entity) => entity.id), [body.id]);
  assert.equal(entitiesForRef(session, account(accountA))[0].mindId, mind);
});

test("Mind links require the selected round", () => {
  const view = cloneView();
  const body = view.state.staff.payload.world.entities[0];
  body.account_id = accountA;
  body.mind_id = mind;
  const session = readStaff(view);
  assert(session);
  assert.equal(entitiesForRef(session, mindRef(mind)).length, 1);
  assert.equal(entitiesForRef(session, mindRef(mind, "83")).length, 0);
});

test("event actor attribution cannot link another account to the occupant body", () => {
  const view = cloneView();
  const body = view.state.staff.payload.world.entities[0];
  body.account_id = accountA;
  body.mind_id = mind;
  const event = view.state.staff.payload.selected.audit[0];
  event.occupant_account = accountB;
  event.occupant_mind = Number(mind);
  event.account = account(accountB);
  event.mind = mindRef(mind);
  const session = readStaff(view);
  assert(session);
  assert.equal(entitiesForRef(session, account(accountA)).length, 1);
  assert.equal(entitiesForRef(session, account(accountB)).length, 0);
});

test("staff drive attribution does not change the occupant account", () => {
  const view = cloneView();
  const body = view.state.staff.payload.world.entities[0];
  body.account_id = accountB;
  body.mind_id = mind;
  const event = view.state.staff.payload.selected.audit[0];
  event.account = account(accountA);
  event.occupant_account = accountA;
  event.occupant_mind = Number(mind);
  event.mind = mindRef(mind);
  const session = readStaff(view);
  assert(session);
  assert.equal(entitiesForRef(session, account(accountB)).length, 1);
  assert.equal(entitiesForRef(session, account(accountA)).length, 0);
});

test("a selected live body can fill a truncated world roster once", () => {
  const view = cloneView();
  const world = view.state.staff.payload.world;
  world.entities = world.entities.filter((entity) => entity.id !== "4294967297");
  view.state.staff.payload.selected.payload.account_id = accountA;
  view.state.staff.payload.selected.payload.mind_id = mind;
  const session = readStaff(view);
  assert(session);
  const linked = entitiesForRef(session, account(accountA));
  assert.equal(linked.length, 1);
  assert.equal(linked[0].id, "4294967297");
  assert.equal(entitiesForRef(session, account(accountA)).length, 1);
});

test("a selected fallback does not replace a canonical world row", () => {
  const view = cloneView();
  const world = view.state.staff.payload.world;
  const body = world.entities[0];
  body.account_id = accountA;
  view.state.staff.payload.selected.target.kind = "entity";
  view.state.staff.payload.selected.payload.account_id = accountA;
  delete view.state.staff.payload.selected.payload.name;
  const session = readStaff(view);
  assert(session);
  const linked = entitiesForRef(session, account(accountA));
  assert.equal(linked.length, 1);
  assert.equal(linked[0].kind, "player");
  assert.equal(linked[0].name, "Mara Venn");
});

test("profile body rows lead with the known character name", () => {
  const view = cloneView();
  const body = view.state.staff.payload.world.entities[0];
  body.account_id = accountA;
  const session = readStaff(view);
  assert(session);
  const tree = profileDrill(session, accountA);
  const inspect = nodes(tree).find((node) => node.id === "staff/profile/body/0/inspect");
  assert.match(inspect?.text ?? "", /^Mara Venn · player · 4294967297/);
});

test("profile body rows render the live position when location text is absent", () => {
  const view = cloneView();
  const body = view.state.staff.payload.world.entities[0];
  body.account_id = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
  body.mind_id = mind;
  const session = readStaff(view);
  assert(session);
  const tree = profileDrill(session, body.account_id);
  const location = nodes(tree).find((node) => node.id === "staff/profile/body/0/location");
  assert.equal(location?.text, "(18, 42)");
});
