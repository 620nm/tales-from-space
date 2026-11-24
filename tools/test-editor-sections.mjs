import assert from "node:assert/strict";
import { test } from "node:test";
import { servedRoster } from "./served-roster.mjs";

// The declaration is content/editor.luau; the engine serves it decoded.
const served = servedRoster();
if (served.missing) console.log(`SKIP editor sections: ${served.missing}`);
const skip = served.missing ?? false;
const manifest = served.roster?.editor;
assert(skip || manifest, "the served roster carries content/editor.luau's editor declaration");

// Station staples file under task headings, not their simulation
// domains: a mapper building a room thinks doors, power, air and
// furniture, whatever graph the engine files them under.
const SECTIONS = {
  Doors: [
    "airlock",
    "airlock.engineering",
    "airlock.engineering_glass",
    "airlock.interior_glass",
    "airlock_wide",
    "airlock_button",
  ],
  Power: [
    "apc",
    "generator",
    "light",
    "smes",
    "solar",
    "steam_generator",
    "utility_outlet_port",
    "core_rotor",
  ],
  Atmos: [
    "air_alarm",
    "air_injector",
    "air_scrubber",
    "air_sensor",
    "canister",
    "passive_vent",
    "bidirectional_vent",
    "vent",
    "pump",
    "volume_pump",
    "manual_valve",
    "digital_valve",
    "stationary_tank",
    "floor_drain",
    "connector_port",
  ],
  Furniture: [
    "table",
    "wood_table",
    "reinforced_table",
    "locker",
    "crate",
    "freezer",
    "rack",
    "cadaver_chamber",
    "optable",
    "iv_drip",
  ],
};

test("station staples declare their palette sections", { skip }, () => {
  const byId = new Map(manifest.prototypes.map((p) => [p.id, p]));
  for (const [section, ids] of Object.entries(SECTIONS)) {
    for (const id of ids) {
      const entry = byId.get(id);
      assert(entry, `${id} is declared in the editor manifest`);
      assert.equal(entry.section, section, `${id} files under ${section}`);
      assert.equal(entry.kind, "structure", `${id} stays a structure`);
    }
  }
});

test("the spawn markers keep their Map Markers section", { skip }, () => {
  const byId = new Map(manifest.prototypes.map((p) => [p.id, p]));
  assert.equal(byId.get("player_spawn")?.section, "Map Markers");
  assert.equal(byId.get("threat_spawn")?.section, "Map Markers");
});
