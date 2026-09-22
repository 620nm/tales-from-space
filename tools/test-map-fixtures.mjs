// tools/map-fixture-coverage.mjs against scratch packs under target/,
// then against this pack itself.
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  checkFixtureFiles,
  checkFixtureResults,
  checkGravityRoll,
  gravityRollFixtures,
  gravityRollSpec,
  mapFixtures,
  worldFileNames,
} from "./map-fixture-coverage.mjs";

const pack = fileURLToPath(new URL("..", import.meta.url));
const scratchRoot = join(pack, "target");
mkdirSync(scratchRoot, { recursive: true });

const fixtures = [
  { map: "bench.ron", specs: ["atmos/bench_test.luau", "bench_again_test.luau"] },
  { map: "row.ron", specs: ["row_test.luau"] },
];

// A pack holding exactly `files` (relative path -> text), removed after.
function withPack(files, body) {
  const root = mkdtempSync(join(scratchRoot, "map-coverage-"));
  try {
    for (const [path, text] of Object.entries(files)) {
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), text);
    }
    return body(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

const covered = {
  "tests/maps/bench.ron": "()",
  "tests/maps/row.ron": "()",
  "tests/atmos/bench_test.luau": 't.world_file("bench.ron", 7)\n',
  "tests/bench_again_test.luau": "t.world_file('bench.ron')\n",
  "tests/row_test.luau": 'local x = 1\nt.world_file(\n  "row.ron", 0, "free_build")\n',
};

test("zero shipped maps is legal and both roots are counted apart", () => {
  withPack(covered, (root) => assert.deepEqual(checkFixtureFiles(root, fixtures), { shipped: 0, fixtures: 2 }));
  withPack({ ...covered, "maps/one.ron": "()", "maps/two.ron": "()", "maps/notes.txt": "" }, (root) =>
    assert.deepEqual(checkFixtureFiles(root, fixtures), { shipped: 2, fixtures: 2 }));
});

test("a missing fixture or named spec fails", () => {
  const { "tests/maps/row.ron": _map, ...noMap } = covered;
  withPack(noMap, (root) => assert.throws(() => checkFixtureFiles(root, fixtures), /required fixture missing/));
  const { "tests/row_test.luau": _spec, ...noSpec } = covered;
  withPack(noSpec, (root) => assert.throws(() => checkFixtureFiles(root, fixtures), /required fixture spec missing/));
});

test("a named spec must actually load its map", () => {
  const cases = {
    "loads another map": 't.world_file("bench.ron")\n',
    "a line comment": '-- t.world_file("row.ron")\nt.world([==[()]==])\n',
    "a block comment": '--[[\nt.world_file("row.ron")\n]]\n',
    "prose only": 'local name = "row.ron"\n',
  };
  for (const [label, source] of Object.entries(cases)) {
    withPack({ ...covered, "tests/row_test.luau": source }, (root) =>
      assert.throws(() => checkFixtureFiles(root, fixtures), /never calls t\.world_file\("row\.ron"\)/, label));
  }
});

test("an unnamed fixture and a dangling world_file fail", () => {
  withPack({ ...covered, "tests/maps/orphan.ron": "()" }, (root) =>
    assert.throws(() => checkFixtureFiles(root, fixtures), /orphan\.ron is loaded by no named spec/));
  withPack({ ...covered, "tests/stray_test.luau": 't.world_file("gone.ron")\n' }, (root) =>
    assert.throws(() => checkFixtureFiles(root, fixtures), /stray_test\.luau loads gone\.ron/));
  withPack({ ...covered, "maps/shipped.ron": "()", "tests/stray_test.luau": 't.world_file("shipped.ron")\n' },
    (root) => checkFixtureFiles(root, fixtures));
});

// One passing report row per named spec, booting every fixture it is named for.
function passingRows(list = fixtures) {
  const booted = new Map();
  for (const fixture of list) {
    for (const spec of fixture.specs) booted.set(spec, [...(booted.get(spec) ?? []), fixture.map]);
  }
  return [...booted].map(([name, maps]) => ({ name, status: "ok", maps_loaded: maps, maps_loaded_truncated: false }));
}

test("missing, failed and duplicate runs cannot claim coverage", () => {
  const specs = passingRows();
  checkFixtureResults({ specs }, fixtures);
  assert.throws(() => checkFixtureResults({}, fixtures), /must contain results/);
  assert.throws(() => checkFixtureResults({ specs: [] }, fixtures), /must run exactly once/);
  assert.throws(() => checkFixtureResults({ specs: specs.slice(1) }, fixtures), /must run exactly once/);
  assert.throws(() => checkFixtureResults({ specs: [...specs, specs[0]] }, fixtures), /must run exactly once/);
  assert.throws(() => checkFixtureResults({ specs: [{ ...specs[0], status: "fail" }, ...specs.slice(1)] }, fixtures),
    /fixture spec failed/);
});

test("only a report row that booted the fixture proves coverage", () => {
  const specs = passingRows();
  const withRow = (change) => ({ specs: specs.map((row) => (row.name === "row_test.luau" ? change(row) : row)) });
  checkFixtureResults(withRow((row) => ({ ...row, maps_loaded: ["bench.ron", "row.ron"] })), fixtures);
  // The source names row.ron, so the pre-check passes; the run never booted it.
  withPack(covered, (root) => checkFixtureFiles(root, fixtures));
  assert.throws(() => checkFixtureResults(withRow((row) => ({ ...row, maps_loaded: [] })), fixtures),
    /row_test\.luau passed without booting row\.ron/);
  assert.throws(() => checkFixtureResults(withRow((row) => ({ ...row, maps_loaded_truncated: true })), fixtures),
    /maps_loaded is truncated: row_test\.luau/);
  assert.throws(() => checkFixtureResults(withRow(({ maps_loaded_truncated: _, ...row }) => row), fixtures),
    /maps_loaded is truncated/);
  assert.throws(() => checkFixtureResults(withRow(({ maps_loaded: _, ...row }) => row), fixtures),
    /no maps_loaded list: row_test\.luau/);
  assert.throws(() => checkFixtureResults({ specs: specs.filter((row) => row.name !== "row_test.luau") }, fixtures),
    /must run exactly once: row_test\.luau/);
});

test("world_file names are read from code, not comments", () => {
  assert.deepEqual([...worldFileNames('t.world_file("a.ron") -- t.world_file("b.ron")\n')], ["a.ron"]);
  assert.deepEqual([...worldFileNames('--[==[\nt.world_file("c.ron")\n]==]\nt.world_file("d.ron")')], ["d.ron"]);
});

test("the gravity roll walks exactly the fixtures pinning standard gravity", () => {
  const pinned = "(\n    environment: (gravity_m_s2: Exact(9.80665)),\n)";
  const maps = {
    "tests/maps/a.ron": pinned,
    "tests/maps/b.ron": pinned,
    "tests/maps/zero.ron": "(environment: (gravity_m_s2: Exact(0.0)))",
    "tests/maps/silent.ron": "// gravity_m_s2: Exact(9.80665)\n()",
  };
  const roll = (names) => `for _, map in ipairs({ ${names} }) do\n    t.world_file(map, 7)\nend\n`;
  withPack({ ...maps, "tests/roll_test.luau": roll('"a.ron", "b.ron"') }, (root) =>
    assert.equal(checkGravityRoll(root, "roll_test.luau"), 2));
  withPack(maps, (root) => assert.deepEqual(gravityRollFixtures(root), [
    { map: "a.ron", specs: [gravityRollSpec] },
    { map: "b.ron", specs: [gravityRollSpec] },
  ]));
  const wrong = {
    "a pinned fixture left out": roll('"a.ron"'),
    "an unpinned fixture listed": roll('"a.ron", "b.ron", "zero.ron"'),
    "a listed name only in a comment": `${roll('"a.ron"')}-- "b.ron"\n`,
  };
  for (const [label, source] of Object.entries(wrong)) {
    withPack({ ...maps, "tests/roll_test.luau": source }, (root) =>
      assert.throws(() => checkGravityRoll(root, "roll_test.luau"), /must walk exactly/, label));
  }
  withPack(maps, (root) => assert.throws(() => checkGravityRoll(root, "roll_test.luau"), /gravity roll spec missing/));
});

test("this pack's fixtures are each loaded by their named specs", () => {
  const counts = checkFixtureFiles(pack);
  assert.equal(counts.fixtures, mapFixtures.length);
  checkGravityRoll(pack);
});
