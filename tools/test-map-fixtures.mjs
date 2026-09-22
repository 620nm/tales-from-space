// tools/map-fixture-coverage.mjs against scratch packs under target/,
// then against this pack itself.
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { checkFixtureFiles, checkFixtureResults, mapFixtures, worldFileNames } from "./map-fixture-coverage.mjs";

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

test("missing, failed and duplicate runs cannot claim coverage", () => {
  const specs = fixtures.flatMap((fixture) => fixture.specs.map((name) => ({ name, status: "ok" })));
  checkFixtureResults({ specs }, fixtures);
  assert.throws(() => checkFixtureResults({}, fixtures), /must contain results/);
  assert.throws(() => checkFixtureResults({ specs: [] }, fixtures), /must run exactly once/);
  assert.throws(() => checkFixtureResults({ specs: specs.slice(1) }, fixtures), /must run exactly once/);
  assert.throws(() => checkFixtureResults({ specs: [...specs, specs[0]] }, fixtures), /must run exactly once/);
  assert.throws(() => checkFixtureResults({ specs: [{ ...specs[0], status: "fail" }, ...specs.slice(1)] }, fixtures),
    /fixture spec failed/);
});

test("world_file names are read from code, not comments", () => {
  assert.deepEqual([...worldFileNames('t.world_file("a.ron") -- t.world_file("b.ron")\n')], ["a.ron"]);
  assert.deepEqual([...worldFileNames('--[==[\nt.world_file("c.ron")\n]==]\nt.world_file("d.ron")')], ["d.ron"]);
});

test("this pack's fixtures are each loaded by their named specs", () => {
  const counts = checkFixtureFiles(pack);
  assert.equal(counts.fixtures, mapFixtures.length);
});
