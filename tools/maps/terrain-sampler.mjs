// Writes maps/terrain_sampler.ron: a 64x64 shore, lake, cliff and meadow
// sampler with a rock basement. Edit this file and run
// `node tools/maps/terrain-sampler.mjs`; a run overwrites any editor save of the map.
// Layout is in the header comment.
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SIZE = 64;
const TILE_HEIGHT_M = 3; // content/lib/tile_geometry.luau
const R = 8.314;
const ONE_ATMOSPHERE_PA = 101325.0;
const T = 293.15;
const AIR_N = ONE_ATMOSPHERE_PA / (R * T);
const CELLULOSE_MOLAR_MASS = 162.14;

const SOIL = ".";
const SAND = "a";
const SEA = "w";
const SHALLOWS = "s";
const LAKE = "l";
const CLIFF = "c";
const PIER_SEA = "p";
const PIER_SHALLOWS = "q";
const PIER_SAND = "b";
const ROCK = "#";
const CARVED = "_";

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
  [CLIFF]: `(composition: (substrate: Named("cliff"), material: Named("silica_cliff"), components: []), outdoors: true)`,
  [PIER_SEA]: catwalk("sea_water"),
  [PIER_SHALLOWS]: catwalk("sea_shallows"),
  [PIER_SAND]: catwalk("sand_ground"),
  [ROCK]: `(composition: (components: [(component: "rock")]))`,
  [CARVED]: `(composition: (components: []))`,
};

function num(n) {
  return Number.isInteger(n) ? n.toFixed(1) : String(n);
}

function cover(id, plant, gramsPerM2) {
  const plantMoles = gramsPerM2 / CELLULOSE_MOLAR_MASS / TILE_HEIGHT_M;
  const rows = [
    ["o2", AIR_N * 0.21],
    ["n2", AIR_N * 0.79],
    [`${plant}:solid`, plantMoles],
  ];
  const text = rows.map(([key, moles]) => `("${key}", ${num(moles)})`).join(", ");
  return `"${id}": (rows: [${text}], temperature_k: ${num(T)}, amount: per_m3)`;
}

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
const CLIFF_BANDS = [
  { x0: 24, x1: 41, y0: 38, y1: 40 }, // sea cliff south of the spawn
  { x0: 6, x1: 22, y0: 46, y1: 48 }, // inland ridge
];
const inBox = (b, x, y) => x >= b.x0 && x <= b.x1 && y >= b.y0 && y <= b.y1;

const groundRows = [];
for (let y = 0; y < SIZE; y++) {
  let row = "";
  for (let x = 0; x < SIZE; x++) {
    let glyph = groundGlyph(x, y);
    if (CLIFF_BANDS.some((b) => inBox(b, x, y))) glyph = CLIFF;
    else if (inBox(PIER, x, y)) {
      glyph = { [SEA]: PIER_SEA, [SHALLOWS]: PIER_SHALLOWS, [SAND]: PIER_SAND }[glyph] ?? glyph;
    }
    row += glyph;
  }
  groundRows.push(row);
}

// Plants go on bare soil only.
const painted = [];
const MEADOW = { x0: 4, x1: 24, y0: 22, y1: 36 };
const MOSS = { x0: 26, x1: 30, y0: 24, y1: 30 };
for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    if (groundRows[y][x] !== SOIL) continue;
    if (inBox(MEADOW, x, y)) painted.push([x, y, "meadow"]);
    else if (inBox(MOSS, x, y)) painted.push([x, y, "moss_carpet"]);
  }
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
  const glyph = groundRows[y][x];
  if (![SOIL, SAND].includes(glyph)) throw new Error(`${id} at ${x},${y} stands on '${glyph}'`);
}

// Basement (level -1): solid rock with one carved room under the beach.
const ROOM = { x0: 28, x1: 38, y0: 28, y1: 36 };
const basementRows = [];
for (let y = 0; y < SIZE; y++) {
  let row = "";
  for (let x = 0; x < SIZE; x++) row += inBox(ROOM, x, y) ? CARVED : ROCK;
  basementRows.push(row);
}

const byReading = (a, b) => a[1] - b[1] || a[0] - b[0];
const q = (s) => JSON.stringify(s);
const block = (name, entries) =>
  entries.length
    ? [`            ${name}: [`, ...entries.map((e) => `                ${e},`), "            ],"]
    : [];
const used = new Set([...basementRows, ...groundRows].join(""));
const legendLines = Object.keys(legend)
  .filter((g) => used.has(g))
  .sort()
  .map((g) => `        '${g}': ${legend[g]},`);

const out = [
  "// Terrain sampler: soil inland, a sand shore, a sea with a shallows band, a lake,",
  "// cliffs, a meadow and moss, boulders, a catwalk pier and a rock basement.",
  "// Generated by tools/maps/terrain-sampler.mjs; the map is 64 x 64, (x, y) from the top left.",
  "//   sea x >= 44 (wobbles with y); shallows 4 tiles west of it; sand 6 more; lake at (14, 12)",
  "//   pier y 31-32, x 36-58; spawn (36, 35); sea cliff (24-41, 38-40); ridge (6-22, 46-48)",
  "//   meadow (4-24, 22-36); moss (26-30, 24-30); level -1 rock with a room (28-38, 28-36)",
  "(",
  '    name: "terrain sampler",',
  '    tags: ["terrestrial","warm_outdoors"],',
  "    environment: (",
  "        kind: Exact(terrestrial),",
  "    ),",
  "    legend: {",
  ...legendLines,
  "    },",
  "    blends: {",
  `        ${cover("meadow", "grass", 300.0)},`,
  `        ${cover("moss_carpet", "moss", 200.0)},`,
  "    },",
  "    levels_below_ground: 1,",
  "    levels: [",
  "        (",
  "            rows: [",
  ...basementRows.map((r) => `                ${q(r)},`),
  "            ],",
  "        ),",
  "        (",
  "            rows: [",
  ...groundRows.map((r) => `                ${q(r)},`),
  "            ],",
  ...block(
    "structures",
    [...structures].sort(byReading).map(([x, y, id]) => `(${x}, ${y}, ${q(id)})`),
  ),
  ...block(
    "painted",
    painted.sort(byReading).map(([x, y, id]) => `(${x}, ${y}, ${q(id)})`),
  ),
  "        ),",
  "    ],",
  ")",
  "",
];

const target = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "maps", "terrain_sampler.ron");
writeFileSync(target, out.join("\n"));
console.log(`wrote ${target}`);
