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
