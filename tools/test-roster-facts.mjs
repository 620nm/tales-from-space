// What this pack claims about itself, read back off the roster document
// the engine serves (`lunatic-server roster <pack>`). These were engine
// Rust assertions against the live pack until the engine suite stopped
// reading it; they are facts about THIS pack, so they live here.
//
// The JSON arrives one of two ways: the gate bakes it once and names it
// in LUNATIC_ROSTER (the same file its `placeable` lane hands the client
// test), else this runs the engine itself. Neither available is a SKIP
// by name -- never a silent pass. Only stdout is the document; `roster`
// writes its "no atlas baked" NOTE to stderr.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const pack = resolve(fileURLToPath(new URL("..", import.meta.url)));
const engine = resolve(process.argv[2] ?? process.env.LUNATIC_ENGINE ?? join(pack, "..", "lunatic"));

// The gate's own copy, written before any lane ran. Unreadable or
// unparseable is a failure, not a skip: the gate promised this file.
function rosterFromGate() {
  const path = process.env.LUNATIC_ROSTER;
  if (!path) return null;
  return { source: `LUNATIC_ROSTER=${path}`, text: readFileSync(path, "utf8") };
}

// The fallback, for a bare `node tools/test.mjs <engine>`: one roster
// run against this pack. `--web` only where the gate named the root its
// bake wrote to, so this never adopts the engine checkout's own atlas.
function rosterFromEngine() {
  const manifest = join(engine, "Cargo.toml");
  if (!existsSync(manifest)) return { missing: `no LUNATIC_ROSTER, and no engine checkout at ${engine}` };
  const web = process.env.LUNATIC_PACK_WEB;
  const args = ["run", "-q", "--manifest-path", manifest, "-p", "lunatic-server", "--", "roster", pack];
  if (web) args.push("--web", web);
  const run = spawnSync("cargo", args, { cwd: engine, encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  if (run.error?.code === "ENOENT") return { missing: "no LUNATIC_ROSTER, and cargo is not on PATH" };
  if (run.error) throw run.error;
  if (run.status !== 0) {
    throw new Error(`cargo run -p lunatic-server -- roster ${pack} exited ${run.status}\n${run.stderr ?? ""}`);
  }
  return { source: `cargo run -p lunatic-server -- roster ${pack}`, text: run.stdout };
}

let roster = null;
let unavailable = false;
let failure = null;
try {
  const got = rosterFromGate() ?? rosterFromEngine();
  if (got.missing) unavailable = got.missing;
  else {
    roster = JSON.parse(got.text);
    console.log(`roster facts: ${got.source}`);
  }
} catch (error) {
  failure = error;
}
if (unavailable) console.log(`SKIP roster facts: ${unavailable}`);
if (failure) test("the roster document is readable", () => { throw failure; });

const skip = unavailable || (failure ? "the roster document could not be read" : false);
const fact = (name, assertion) => test(name, { skip }, assertion);

const HUMAN_CAPACITY_BINDINGS = new Map([
  ["consciousness", "consciousness"],
  ["moving", "movement"],
  ["manipulation", "manipulation"],
  ["sight", "vision"],
  ["hearing", "hearing"],
  ["speech", "speech"],
  ["breathing", "breathing"],
  ["blood", "circulation"],
  ["metabolism", "metabolism"],
]);

function assertPackManifest(packRoster) {
  assert.deepEqual(packRoster.manifest, {
    id: "lunatic/tfs",
    name: "Tales from Space",
    version: "0.1.0",
    api_version: 1,
  }, "the roster serves the loaded pack identity, not the editor's claim");
}

function assertHumanBody(packRoster) {
  const bodyIds = (packRoster.bodies ?? []).map((body) => body.id);
  assert.deepEqual(bodyIds, [...bodyIds].sort(), "body rows are sorted by id");
  const human = (packRoster.bodies ?? []).find((body) => body.id === "human");
  assert(human, "the roster serves the human body plan");
  const capacities = human.capacities ?? [];
  for (const [role, port] of HUMAN_CAPACITY_BINDINGS) {
    const matches = capacities.filter((capacity) => capacity.role === role);
    assert.equal(matches.length, 1, `human binds native capacity role ${role} exactly once`);
    assert.equal(matches[0].port, port, `human binds ${role} to native port ${port}`);
  }
  const lethal = capacities.filter((capacity) => capacity.lethal === true).map((capacity) => capacity.id).sort();
  assert.deepEqual(lethal, ["brain"], "brain is the human body's sole lethal capacity");
}

// Product rows do not carry their private trigger. These bare products end
// the target in this pack's build ladders; a `leaves` row also raises debris,
// so it is not a terminal rung in this same-structure walk.
const teardownProducts = new Set(["gone", "remove_component"]);
const productKinds = new Set([
  "state", "add_component", "replace_component", "remove_component",
  "preset", "gone", "finish", "eject",
]);

function stateLabel(state) {
  return state === null ? "<stateless>" : state;
}

function assertConstructionGraph(packRoster) {
  const structures = packRoster.structures ?? [];
  assert(structures.length > 0, "the roster serves structures");
  assert(
    structures.every((entry) => typeof entry.buildable === "boolean"),
    "the roster marks every structure's buildability",
  );
  const buildable = structures.filter((entry) => entry.buildable === true);
  assert(buildable.length > 0, "the roster serves at least one buildable structure");

  for (const entry of buildable) {
    const states = entry.states ?? [];
    const stateSet = new Set(states);
    assert.equal(stateSet.size, states.length, `${entry.id}: construction states are unique`);
    const constructionStates = new Set();
    for (const row of entry.transitions ?? []) {
      if (row.at != null) constructionStates.add(row.at);
      const product = row.product ?? {};
      if (product.kind === "state" && typeof product.id === "string") {
        constructionStates.add(product.id);
      } else if (product.kind === "eject" && typeof product.to === "string") {
        constructionStates.add(product.to);
      }
    }
    // `states` also names native control/appearance positions. The historical
    // teardown walk starts at the first state and follows construction rows;
    // positions with no construction row are not build-ladder nodes. A
    // wildcard-only ladder still gets its first state as a validation root.
    const nodes = states.length === 0
      ? [null]
      : [...(constructionStates.size > 0 ? constructionStates : [states[0]])];
    const edges = new Map(nodes.map((state) => [state, []]));
    const terminal = new Set();

    for (const [index, row] of (entry.transitions ?? []).entries()) {
      const product = row.product ?? {};
      assert(productKinds.has(product.kind), `${entry.id}: transition ${index} has unknown product ${product.kind}`);
      const origins = row.at == null ? nodes : [row.at];
      for (const origin of origins) {
        assert(edges.has(origin), `${entry.id}: transition ${index} starts at unknown state ${origin}`);
      }

      if (product.kind === "state" || product.kind === "eject") {
        const destination = product.kind === "state" ? product.id : product.to;
        assert.equal(typeof destination, "string", `${entry.id}: transition ${index} names a destination`);
        assert(stateSet.has(destination), `${entry.id}: transition ${index} points to unknown state ${destination}`);
        for (const origin of origins) edges.get(origin).push(destination);
      } else if (teardownProducts.has(product.kind) && row.leaves == null) {
        for (const origin of origins) terminal.add(origin);
      }
      // Finish is intentionally neither an edge nor a teardown exit.
    }

    const canTeardown = new Set(terminal);
    let changed = true;
    while (changed) {
      changed = false;
      for (const [origin, destinations] of edges) {
        if (!canTeardown.has(origin) && destinations.some((state) => canTeardown.has(state))) {
          canTeardown.add(origin);
          changed = true;
        }
      }
    }
    // Every construction state must independently be able to follow
    // State/Eject (including wildcard) rows to a bare teardown product.
    for (const state of nodes) {
      assert(canTeardown.has(state), `${entry.id}: construction state ${stateLabel(state)} has no teardown route`);
    }
  }
}

function representativeRoster() {
  const capacities = [...HUMAN_CAPACITY_BINDINGS].map(([role, port]) => ({
    id: role,
    role,
    port,
    lethal: false,
  }));
  capacities.push({ id: "brain", lethal: true });
  return {
    manifest: { id: "lunatic/tfs", name: "Tales from Space", version: "0.1.0", api_version: 1 },
    bodies: [{ id: "human", capacities }],
    structures: [
      {
        id: "wildcard_frame",
        buildable: true,
        states: ["standing"],
        transitions: [{ at: null, product: { kind: "gone" } }],
      },
      {
        id: "assembly_frame",
        buildable: true,
        states: ["empty", "boarded"],
        transitions: [
          { at: "empty", product: { kind: "state", id: "boarded" } },
          { at: "boarded", product: { kind: "eject", to: "empty" } },
          { at: "boarded", product: { kind: "finish" } },
          { at: "empty", product: { kind: "gone" } },
        ],
      },
      // A canister's failure state is deliberately not a build ladder.
      {
        id: "canister",
        buildable: false,
        states: ["anchored", "displaced", "broken"],
        transitions: [
          { at: "anchored", product: { kind: "state", id: "displaced" } },
          { at: "displaced", product: { kind: "state", id: "anchored" } },
        ],
      },
    ],
  };
}

const copyRoster = () => structuredClone(representativeRoster());

test("roster policy accepts wildcard teardown and ejection ladders", () => {
  const fixture = representativeRoster();
  assertPackManifest(fixture);
  assertHumanBody(fixture);
  assertConstructionGraph(fixture);
});

test("roster policy catches a wrong manifest identity", () => {
  const fixture = copyRoster();
  fixture.manifest.id = "other/pack";
  assert.throws(() => assertPackManifest(fixture), /identity|lunatic\/tfs/);
});

test("roster policy catches a wrong native role binding", () => {
  const fixture = copyRoster();
  fixture.bodies[0].capacities.find((capacity) => capacity.role === "moving").port = "vision";
  assert.throws(() => assertHumanBody(fixture), /moving|movement/);
});

test("roster policy catches a changed lethal capacity", () => {
  const fixture = copyRoster();
  fixture.bodies[0].capacities.find((capacity) => capacity.id === "brain").lethal = false;
  fixture.bodies[0].capacities.find((capacity) => capacity.role === "moving").lethal = true;
  assert.throws(() => assertHumanBody(fixture), /lethal|brain/);
});

test("roster policy catches a reachable ladder with no teardown", () => {
  const fixture = copyRoster();
  const frame = fixture.structures.find((entry) => entry.id === "assembly_frame");
  frame.transitions = frame.transitions.filter((row) => row.product.kind !== "gone");
  assert.throws(() => assertConstructionGraph(fixture), /no teardown route/);
});

test("a debris-producing gone row is not a terminal teardown", () => {
  const fixture = copyRoster();
  const frame = fixture.structures.find((entry) => entry.id === "assembly_frame");
  frame.transitions = frame.transitions.map((row) => row.product.kind === "gone"
    ? { ...row, leaves: "girder" }
    : row);
  assert.throws(() => assertConstructionGraph(fixture), /no teardown route/);
});

test("roster policy catches a disconnected state with no teardown route", () => {
  const fixture = copyRoster();
  const frame = fixture.structures.find((entry) => entry.id === "assembly_frame");
  frame.states.push("stranded");
  frame.transitions.push({ at: "stranded", product: { kind: "state", id: "stranded" } });
  assert.throws(() => assertConstructionGraph(fixture), /stranded.*no teardown route/);
});

test("finish does not count as a teardown route", () => {
  const fixture = copyRoster();
  const frame = fixture.structures.find((entry) => entry.id === "assembly_frame");
  frame.transitions = frame.transitions.map((row) => row.product.kind === "gone"
    ? { ...row, product: { kind: "finish" } }
    : row);
  assert.throws(() => assertConstructionGraph(fixture), /no teardown route/);
});

test("failure-only canister states stay outside the buildable policy", () => {
  assert.doesNotThrow(() => assertConstructionGraph(representativeRoster()));
  const fixture = copyRoster();
  fixture.structures.find((entry) => entry.id === "canister").buildable = true;
  assert.throws(() => assertConstructionGraph(fixture), /canister.*no teardown route/);
});

fact("the roster manifest identifies this pack independently of editor modes", () => {
  assertPackManifest(roster);
});

fact("the human body binds every native role and has a lethal capacity", () => {
  assertHumanBody(roster);
});

fact("buildable structure ladders have reachable teardown routes", () => {
  assertConstructionGraph(roster);
});

// A truncated or foreign document would make every check below vacuous.
fact("the roster is this pack's, with content to place", () => {
  for (const kind of ["items", "structures", "machines"]) {
    assert(roster[kind]?.length > 0, `Tales from Space rosters ${kind}`);
  }
});

// `editor: null` is a clean exit: the engine returns Ok when
// editor/manifest.json is merely absent, so presence is the fact.
fact("the pack ships the editor manifest that declares its palettes", () => {
  assert(roster.editor, "editor/manifest.json declares this pack's modes, palettes, property schemas and previews");
  assert.equal(roster.editor.pack, "lunatic/tfs", "editor/manifest.json names its pack lunatic/tfs");
  assert.equal(roster.editor.default_mode, "space_station", "the editor opens a map in Space Station");
});

fact("the editor offers Space Station and Free Build by those names", () => {
  assert.equal(roster.editor.modes?.space_station?.label, "Space Station", "the full station round is shown as Space Station");
  assert.equal(roster.editor.modes?.free_build?.label, "Free Build", "the construction playground is shown as Free Build");
});

// Every flag reads declared content (the engine's
// `net/roster_mechanisms.rs`): this pack declares all seven, and an
// editor handed a false one hides the lens or tool that goes with it.
fact("the pack declares every mechanism the editor gates on", () => {
  const declared = roster.mechanisms ?? {};
  assert.equal(declared.transport_networks, true, "compositions declare the power and pipe networks");
  assert.equal(declared.matter_blends, true, "the pack declares substances and blends");
  assert.equal(declared.device_networks, true, "structures and machines declare device links");
  assert.equal(declared.stores, true, "the pack rosters filetypes, drives and program slots");
  assert.equal(declared.environments, true, "the pack declares environment profiles");
  assert.equal(declared.residue, true, "residue appearances dress the settled kinds");
  assert.equal(declared.decals, true, "compositions declare the floor decals");
});

// `default = true` is what makes "what a room opens with" one answer.
fact("one blend is the air an unpainted tile opens with", () => {
  const defaults = (roster.blends ?? []).filter((blend) => blend.default === true);
  assert.deepEqual(defaults.map((blend) => blend.id), ["breathable_air"], "breathable air alone is the pack's default blend");
  assert.equal(defaults[0].name, "Breathable air", "the default blend is shown as Breathable air");
});
