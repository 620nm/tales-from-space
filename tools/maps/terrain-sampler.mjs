// Writes maps/terrain_sampler.ron: a 64x64 shore, lake, cliff, ridge and
// meadow sampler over generated ground. Edit this file and run
// `node tools/maps/terrain-sampler.mjs`; a run overwrites any editor save of the map.
// Layout is in the header comment.
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SIZE = 64;

// Level 0 tiles.
const SOIL = ".";
const SAND = "a";
const SEA = "w";
const SHALLOWS = "s";
const LAKE = "l";
const CLIFF = "c";
const RIDGE = "r";
const PIER_SEA = "p";
const PIER_SHALLOWS = "q";
const PIER_SAND = "b";
// A blank tile: what lies there is the generated ground.
const BLANK = "_";
const BLANK_OUTDOORS = ",";

const ground = (material) =>
  `(composition: (substrate: Named("ground"), material: Named("${material}"), components: []), outdoors: true)`;
const catwalk = (material) =>
  `(composition: (substrate: Named("ground"), material: Named("${material}"), components: [(component: "catwalk")]), outdoors: true)`;
const legend = {
  [SOIL]: ground("soil_ground"),
  [SAND]: ground("sand_ground"),
  [SEA]: ground("sea_water"),
  [SHALLOWS]: ground("sea_shallows"),
  [LAKE]: ground("lake_water"),
  [PIER_SEA]: catwalk("sea_water"),
  [PIER_SHALLOWS]: catwalk("sea_shallows"),
  [PIER_SAND]: catwalk("sand_ground"),
  [BLANK]: `(composition: ())`,
  [BLANK_OUTDOORS]: `(composition: (), outdoors: true)`,
};

// Ground hints, one per column (docs/mapping/format.md §Ground in the engine).
const PLAIN = ".";
const GRASS = "g";
const MOSS = "m";
const RAISED = "^";
const PIT = "v";
const groundLegend = {
  [GRASS]: `(cover: Some("grass"))`,
  [MOSS]: `(cover: Some("moss"))`,
  [RAISED]: `(height: 1, material: Some(Role("rock")))`,
  [PIT]: `(height: -1)`,
};
// A cliff tile is a half-height step of quartz (content/terrain.luau `steps`).
const CLIFF_STEP = `StepOf("half", Blend("silica_ground"))`;

// Ground level, sketched east to west: sea, shallows, sand shore, soil.
const shoreX = (y) => 44 + Math.round(2 * Math.sin(y / 5));
const inEllipse = (x, y, cx, cy, rx, ry) =>
  ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1;

function groundGlyph(x, y) {
  const edge = shoreX(y);
  if (x >= edge) return SEA;
  if (x >= edge - 4) return SHALLOWS;
  if (inEllipse(x, y, 14, 12, 8, 5)) return LAKE;
  if (x >= edge - 10 || inEllipse(x, y, 14, 12, 10, 7)) return SAND;
  return SOIL;
}

const PIER = { x0: 36, x1: 58, y0: 31, y1: 32 };
const CLIFF_BAND = { x0: 24, x1: 41, y0: 38, y1: 40 }; // sea cliff south of the spawn
const RIDGE_BAND = { x0: 6, x1: 22, y0: 46, y1: 48 }; // inland ridge, one level high
const inBox = (b, x, y) => x >= b.x0 && x <= b.x1 && y >= b.y0 && y <= b.y1;

const levelRows = [];
for (let y = 0; y < SIZE; y++) {
  let row = "";
  for (let x = 0; x < SIZE; x++) {
    let glyph = groundGlyph(x, y);
    if (inBox(CLIFF_BAND, x, y)) glyph = CLIFF;
    else if (inBox(RIDGE_BAND, x, y)) glyph = RIDGE;
    else if (inBox(PIER, x, y)) {
      glyph = { [SEA]: PIER_SEA, [SHALLOWS]: PIER_SHALLOWS, [SAND]: PIER_SAND }[glyph] ?? glyph;
    }
    row += glyph;
  }
  levelRows.push(row);
}

const structures = [
  [36, 35, "player_spawn"],
  [31, 33, "outcrop"],
  [40, 35, "outcrop"],
  [24, 42, "outcrop"],
  [38, 28, "outcrop.cluster"],
  [30, 31, "outcrop.cluster"],
  [10, 43, "outcrop.cluster"],
];
for (const [x, y, id] of structures) {
  const glyph = levelRows[y][x];
  if (![SOIL, SAND].includes(glyph)) throw new Error(`${id} at ${x},${y} stands on '${glyph}'`);
}

// Basement (level -1): generated rock, with one room carved under the beach
// by a pit hint that opens the column down to the generated level.
const ROOM = { x0: 28, x1: 38, y0: 28, y1: 36 };
// Plants go on bare soil only.
const MEADOW = { x0: 4, x1: 24, y0: 22, y1: 36 };
const MOSS_BED = { x0: 26, x1: 30, y0: 24, y1: 30 };
const hintRows = [];
const solid = [];
for (let y = 0; y < SIZE; y++) {
  let row = "";
  for (let x = 0; x < SIZE; x++) {
    const glyph = levelRows[y][x];
    let hint = PLAIN;
    if (glyph === RIDGE) hint = RAISED;
    else if (inBox(ROOM, x, y)) hint = PIT;
    else if (glyph === SOIL && inBox(MEADOW, x, y)) hint = GRASS;
    else if (glyph === SOIL && inBox(MOSS_BED, x, y)) hint = MOSS;
    if (glyph === CLIFF) solid.push([x, y, CLIFF_STEP]);
    row += hint;
  }
  hintRows.push(row);
}
const tileRows = levelRows.map((r) =>
  r.replaceAll(CLIFF, BLANK_OUTDOORS).replaceAll(RIDGE, BLANK_OUTDOORS),
);
const basementRows = Array.from({ length: SIZE }, () => BLANK.repeat(SIZE));

const byReading = (a, b) => a[1] - b[1] || a[0] - b[0];
const q = (s) => JSON.stringify(s);
const block = (name, entries) =>
  entries.length
    ? [`            ${name}: [`, ...entries.map((e) => `                ${e},`), "            ],"]
    : [];
const used = new Set([...basementRows, ...tileRows].join(""));
const legendLines = Object.keys(legend)
  .filter((g) => used.has(g))
  .sort()
  .map((g) => `        '${g}': ${legend[g]},`);
const usedHints = new Set(hintRows.join(""));
const groundLegendLines = Object.keys(groundLegend)
  .filter((g) => usedHints.has(g))
  .sort()
  .map((g) => `            '${g}': ${groundLegend[g]},`);

const out = [
  "// Terrain sampler: soil inland, a sand shore, a sea with a shallows band, a lake,",
  "// a cliff of half-height steps, a raised ridge, grass and moss covers, boulders,",
  "// a catwalk pier, and generated rock below with one carved room.",
  "// Generated by tools/maps/terrain-sampler.mjs; the map is 64 x 64, (x, y) from the top left.",
  "//   sea x >= 44 (wobbles with y); shallows 4 tiles west of it; sand 6 more; lake at (14, 12)",
  "//   pier y 31-32, x 36-58; spawn (36, 35); sea cliff (24-41, 38-40); ridge (6-22, 46-48)",
  "//   grass (4-24, 22-36); moss (26-30, 24-30); level -1 room (28-38, 28-36)",
  "(",
  '    name: "terrain sampler",',
  '    needs: ["gravity"],',
  "    environment: (",
  "        kind: Exact(terrestrial),",
  "        surface_temperature_k: Exact(293.15),",
  "    ),",
  "    legend: {",
  ...legendLines,
  "    },",
  "    ground: (",
  "        legend: {",
  ...groundLegendLines,
  "        },",
  "        rows: [",
  ...hintRows.map((r) => `            ${q(r)},`),
  "        ],",
  "    ),",
  "    levels_below_ground: 1,",
  "    levels: [",
  "        (",
  "            rows: [",
  ...basementRows.map((r) => `                ${q(r)},`),
  "            ],",
  "        ),",
  "        (",
  "            rows: [",
  ...tileRows.map((r) => `                ${q(r)},`),
  "            ],",
  ...block(
    "structures",
    [...structures].sort(byReading).map(([x, y, id]) => `(${x}, ${y}, ${q(id)})`),
  ),
  ...block(
    "solid",
    solid.sort(byReading).map(([x, y, fill]) => `(${x}, ${y}, ${fill})`),
  ),
  "        ),",
  "    ],",
  ")",
  "",
];

const target = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "maps", "terrain_sampler.ron");
writeFileSync(target, out.join("\n"));
console.log(`wrote ${target}`);
