// Named map-fixture coverage. The `maps` lane only round-trips a map, so
// a fixture no spec boots would pass on parsing alone: every
// `tests/maps/*.ron` is named here with the specs that boot it. The
// authority is the `specs` lane's `--json` report: each named spec ran
// once, passed, and lists the fixture in `maps_loaded` (the engine's
// `docs/scripting/determinism-and-testing.md`). Without a report, the
// source check is a fast pre-check only. Zero shipped `maps/` is legal.
//
//   node tools/map-fixture-coverage.mjs [spec-report.json]
import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const mapFixtures = [
  {
    map: "cold_outpost.ron",
    specs: ["atmos/environment/terrestrial_environment_test.luau", "atmos/environment/tile_air_test.luau"],
  },
  { map: "diagonal_wall_mount.ron", specs: ["construction/diagonal_wall_mount_test.luau"] },
  { map: "flooded_alcove.ron", specs: ["atmos/environment/flooded_alcove_test.luau"] },
  { map: "plant_loop.ron", specs: ["atmos/pipenet/plant_loop_test.luau"] },
  {
    map: "programmable_airlock.ron",
    specs: ["devices/programmable_airlock_test.luau", "devices/programmable_airlock_ready_test.luau"],
  },
  { map: "tank_row.ron", specs: ["atmos/pipenet/tank_row_test.luau"] },
];

// The spec that walks every fixture pinning standard gravity from a
// table of names, so no literal `t.world_file` names them.
export const gravityRollSpec = "atmos/environment/space_environment_test.luau";
const STANDARD_GRAVITY = /\bgravity_m_s2\s*:\s*Exact\(\s*9\.80665\s*\)/;

function ronFiles(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((name) => name.endsWith(".ron")).sort();
}

// Every `tests/**/*_test.luau`, named as the spec runner names it:
// relative to `tests/`, `/`-separated.
function specFiles(tests, dir = tests) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return specFiles(tests, path);
    return entry.name.endsWith("_test.luau") ? [relative(tests, path).split("\\").join("/")] : [];
  });
}

// A Luau source with its comments dropped.
function luauCode(source) {
  return source.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, "").replace(/--[^\n]*/g, "");
}

// The maps a spec source boots by literal name. Comments are dropped
// first, so a commented-out call or a mention in prose loads nothing.
export function worldFileNames(source) {
  return new Set([...luauCode(source).matchAll(/\bworld_file\(\s*(["'])([^"'\n]+)\1/g)].map((m) => m[2]));
}

// The `tests/maps/` files whose own lines pin standard gravity.
export function gravityPinnedFixtures(pack) {
  const maps = join(pack, "tests", "maps");
  return ronFiles(maps).filter((map) =>
    readFileSync(join(maps, map), "utf8").split("\n").some((line) =>
      STANDARD_GRAVITY.test(line.replace(/\/\/.*/, ""))));
}

// The gravity roll's `.ron` string literals are exactly the pinned
// fixtures; `gravityRollFixtures` makes its report row prove the boots.
export function checkGravityRoll(pack, spec = gravityRollSpec) {
  const pinned = gravityPinnedFixtures(pack);
  const path = join(pack, "tests", spec);
  assert.ok(existsSync(path), `gravity roll spec missing: tests/${spec}`);
  const source = luauCode(readFileSync(path, "utf8"));
  const listed = [...new Set([...source.matchAll(/(["'])([^"'\n]+\.ron)\1/g)].map((m) => m[2]))].sort();
  assert.deepEqual(listed, pinned,
    `tests/${spec} must walk exactly the tests/maps/ fixtures pinning standard gravity`);
  return pinned.length;
}

export function checkFixtureFiles(pack, fixtures = mapFixtures) {
  const tests = join(pack, "tests");
  const shipped = ronFiles(join(pack, "maps"));
  const onDisk = ronFiles(join(tests, "maps"));
  const named = new Set(fixtures.map((fixture) => fixture.map));
  for (const map of onDisk) {
    assert.ok(named.has(map), `tests/maps/${map} is loaded by no named spec: add it to mapFixtures`);
  }
  for (const fixture of fixtures) {
    assert.ok(onDisk.includes(fixture.map), `required fixture missing: tests/maps/${fixture.map}`);
    assert.ok(fixture.specs.length > 0, `tests/maps/${fixture.map} names no spec`);
    for (const spec of fixture.specs) {
      const path = join(tests, spec);
      assert.ok(existsSync(path), `required fixture spec missing: tests/${spec}`);
      assert.ok(
        worldFileNames(readFileSync(path, "utf8")).has(fixture.map),
        `tests/${spec} never calls t.world_file("${fixture.map}")`,
      );
    }
  }
  // A spec booting a name neither root holds fails at run time anyway;
  // naming it here says which file, before a world is built.
  for (const spec of specFiles(tests)) {
    for (const map of worldFileNames(readFileSync(join(tests, spec), "utf8"))) {
      assert.ok(
        onDisk.includes(map) || shipped.includes(map),
        `tests/${spec} loads ${map}, which neither tests/maps/ nor maps/ holds`,
      );
    }
  }
  return { shipped: shipped.length, fixtures: onDisk.length };
}

// The gravity roll as fixture rows: each pinned fixture, booted by it.
export function gravityRollFixtures(pack) {
  return gravityPinnedFixtures(pack).map((map) => ({ map, specs: [gravityRollSpec] }));
}

// The spec runner's `--json` document (`{ specs: [{ name, status,
// maps_loaded, maps_loaded_truncated }] }`). A truncated or absent list
// proves nothing, so it fails.
export function checkFixtureResults(report, fixtures = mapFixtures) {
  assert.ok(Array.isArray(report?.specs), "spec runner report must contain results");
  for (const fixture of fixtures) {
    for (const spec of fixture.specs) {
      const rows = report.specs.filter((row) => row.name === spec);
      assert.equal(rows.length, 1, `required fixture spec must run exactly once: ${spec}`);
      const [row] = rows;
      assert.equal(row.status, "ok", `required fixture spec failed: ${spec}`);
      assert.ok(Array.isArray(row.maps_loaded), `spec report row has no maps_loaded list: ${spec}`);
      assert.equal(row.maps_loaded_truncated, false, `spec report row's maps_loaded is truncated: ${spec}`);
      assert.ok(row.maps_loaded.includes(fixture.map), `${spec} passed without booting ${fixture.map}`);
    }
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const pack = fileURLToPath(new URL("..", import.meta.url));
  const counts = checkFixtureFiles(pack);
  const gravity = checkGravityRoll(pack);
  const reportPath = process.argv[2];
  if (reportPath) {
    checkFixtureResults(JSON.parse(readFileSync(reportPath, "utf8")), [...mapFixtures, ...gravityRollFixtures(pack)]);
  }
  const verdict = reportPath ? "each booted by its passing named specs" : "each named in its specs' source";
  console.log(`maps/: ${counts.shipped} shipped; tests/maps/: ${counts.fixtures} fixtures, ${verdict}; ` +
    `${gravity} pinning standard gravity, each walked by ${gravityRollSpec}`);
}
