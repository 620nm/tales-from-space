#!/usr/bin/env node
// The seven art assertions this pack's bake owns. They were facts about
// THIS pack's art living in the engine's client suite, and left it in
// lunatic's 5c8b41971; each test below names the Rust test it restates.
// The subject is the bake at $LUNATIC_PACK_WEB -- a served document root
// holding assets/atlas.ron, assets/delivery.ron and assets/obj/. Unset,
// or set at an unbaked root, is a named SKIP: absence is nothing to
// check, disagreement is a bug. The engine checkout's own web/assets is
// never a fallback; two bakes in one check is the bug this replaced.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { test } from "node:test";
import { inflateSync } from "node:zlib";

const web = process.env.LUNATIC_PACK_WEB;
const assets = web ? resolve(web, "assets") : null;
const skip = !web
  ? "LUNATIC_PACK_WEB names no bake to check"
  : !existsSync(join(assets, "atlas.ron"))
    ? `no bake at ${assets}; bake-atlas --content assets --web ${web}`
    : false;
if (skip) console.log(`SKIP bake-art: ${skip}`);

/** A bracket-balanced top-level RON list, by field name. */
function section(text, name) {
  const head = new RegExp(`^ {4}${name}: \\[`, "m").exec(text);
  if (!head) return "";
  let depth = 0;
  let quoted = false;
  for (let i = head.index + head[0].length - 1; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === "\\") i++;
      else if (ch === '"') quoted = false;
    } else if (ch === '"') quoted = true;
    else if (ch === "[") depth++;
    else if (ch === "]" && --depth === 0) return text.slice(head.index, i);
  }
  throw new Error(`atlas.ron: unterminated ${name} list`);
}

/** A top-level unsigned RON field, or `fallback` when absent. */
function field(text, name, fallback) {
  const found = new RegExp(`^ {4}${name}: (\\d+),$`, "m").exec(text);
  if (!found) {
    if (fallback === undefined) throw new Error(`atlas.ron: no ${name}`);
    return fallback;
  }
  return Number(found[1]);
}

/** Displacements in SOURCE pixels, by sprite (`offsets`, `worn_offsets`). */
const shifts = (text, name) =>
  new Map(
    [...section(text, name).matchAll(/sprite: "([^"]+)",\s*x: (-?\d+),\s*y: (-?\d+),/g)]
      .map(([, sprite, x, y]) => [sprite, { x: Number(x), y: Number(y) }]),
  );

/** `crates/lunatic-client/src/atlas.rs`'s index, as much as art needs. */
function readAtlas(text) {
  const tile = field(text, "tile");
  const columns = field(text, "columns");
  const rowsPerPage = field(text, "rows_per_page");
  const pad = field(text, "pad", 0);
  const cells = field(text, "cells");
  const index = new Map(
    [...section(text, "sprites").matchAll(/\("([^"]+)", (\d+)\)/g)]
      .map(([, name, at]) => [name, Number(at)]),
  );
  const anim = new Map(
    [...section(text, "anim")
      .matchAll(/\("([^"]+)", \(\s*frames: \[([^\]]*)\],\s*once: (true|false),?\s*\)\)/g)]
      .map(([, name, frames, once]) => [name, {
        frames: [...frames.matchAll(/\d+/g)].map((held) => Number(held[0])),
        once: once === "true",
      }]),
  );
  const stride = tile + 2 * pad;
  const perPage = columns * rowsPerPage;
  const offsets = shifts(text, "offsets");
  const wornOffsets = shifts(text, "worn_offsets");
  return {
    tile, columns, pad, cells, index, anim, stride, perPage, offsets, wornOffsets,
    pages: Math.ceil(Math.max(cells, 1) / perPage),
    offset: (name) => at(tile, offsets.get(name)),
    wornOffset: (name) => at(tile, wornOffsets.get(name)),
    frameCount: (name) => anim.get(name)?.frames.length ?? 1,
    pageSize(page) {
      const onPage = Math.min(Math.max(Math.max(cells, 1) - page * perPage, 0), perPage);
      return { width: columns * stride, height: Math.max(Math.ceil(onPage / columns), 1) * stride };
    },
    locate(atCell) {
      const local = atCell % perPage;
      return {
        page: Math.floor(atCell / perPage),
        x: (local % columns) * stride + pad,
        y: Math.floor(local / columns) * stride + pad,
      };
    },
  };
}

/** A source-pixel shift as the client reads it: fractions of a cell. */
const at = (tile, shift) => ({ x: (shift?.x ?? 0) / tile, y: (shift?.y ?? 0) / tile });

/** 8-bit RGBA, no interlace -- the only shape `bake-atlas` publishes. */
function decodePng(bytes, label) {
  for (const [i, b] of [137, 80, 78, 71, 13, 10, 26, 10].entries())
    if (bytes[i] !== b) throw new Error(`${label} is not a PNG`);
  let head;
  const parts = [];
  for (let cursor = 8; cursor + 8 <= bytes.length;) {
    const length = bytes.readUInt32BE(cursor);
    const kind = bytes.toString("ascii", cursor + 4, cursor + 8);
    const body = bytes.subarray(cursor + 8, cursor + 8 + length);
    if (kind === "IHDR")
      head = {
        width: body.readUInt32BE(0), height: body.readUInt32BE(4),
        depth: body[8], colour: body[9], interlace: body[12],
      };
    else if (kind === "IDAT") parts.push(body);
    else if (kind === "IEND") break;
    cursor += 12 + length;
  }
  if (!head) throw new Error(`${label} has no IHDR`);
  if (head.depth !== 8 || head.colour !== 6 || head.interlace !== 0)
    throw new Error(
      `${label} is depth ${head.depth} colour type ${head.colour} interlace `
      + `${head.interlace}; atlas pages are 8-bit RGBA, not interlaced`,
    );
  const { width, height } = head;
  const raw = inflateSync(Buffer.concat(parts));
  const span = width * 4;
  if (raw.length !== height * (span + 1))
    throw new Error(`${label} inflates to ${raw.length} bytes, not ${height * (span + 1)}`);
  const data = Buffer.alloc(height * span);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (span + 1)];
    const line = raw.subarray(y * (span + 1) + 1, (y + 1) * (span + 1));
    const row = data.subarray(y * span, (y + 1) * span);
    const prior = y ? data.subarray((y - 1) * span, y * span) : null;
    for (let i = 0; i < span; i++) {
      const a = i >= 4 ? row[i - 4] : 0;
      const b = prior ? prior[i] : 0;
      const c = prior && i >= 4 ? prior[i - 4] : 0;
      row[i] = (line[i] + predictor(filter, a, b, c)) & 0xff;
    }
  }
  return { width, height, data };
}

/** PNG row filters 0-4 (None, Sub, Up, Average, Paeth). */
function predictor(kind, a, b, c) {
  if (kind === 0) return 0;
  if (kind === 1) return a;
  if (kind === 2) return b;
  if (kind === 3) return (a + b) >> 1;
  if (kind !== 4) throw new Error(`unknown PNG row filter ${kind}`);
  const p = a + b - c;
  const [pa, pb, pc] = [Math.abs(p - a), Math.abs(p - b), Math.abs(p - c)];
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}

/**
 * The atlas index and its pages, each accepted against the digest and
 * length `delivery.ron` pinned (`lunatic-client/src/delivery.rs`,
 * `Object::accept`). A partial store is disagreement, so it throws.
 */
function loadBake() {
  const atlas = readAtlas(readFileSync(join(assets, "atlas.ron"), "utf8"));
  const delivery = readFileSync(join(assets, "delivery.ron"), "utf8");
  const objects = [...section(delivery, "atlas")
    .matchAll(/sha256: "([a-f0-9]{64})",\s*bytes: (\d+),\s*ext: "([a-z0-9]+)",/g)];
  assert.equal(objects.length, atlas.pages,
    `delivery.ron pins ${objects.length} atlas pages; the index describes ${atlas.pages}`);
  const pages = objects.map(([, sha256, bytes, ext], page) => {
    const url = `obj/${sha256}.${ext}`;
    const raw = readFileSync(join(assets, url));
    assert.equal(raw.length, Number(bytes), `${url} is ${raw.length} bytes, not the pinned ${bytes}`);
    assert.equal(createHash("sha256").update(raw).digest("hex"), sha256,
      `${url} does not hash to the name it is served under`);
    const image = decodePng(raw, url);
    const size = atlas.pageSize(page);
    assert.deepEqual({ width: image.width, height: image.height }, size,
      `page ${page} is not the size the manifest describes`);
    return image;
  });
  return { atlas, pages };
}

let loaded;
const bake = () => (loaded ??= loadBake());

/** One 32x32 cell, cropped out of the page its frame landed on. */
function cell(name, frame = 0) {
  const { atlas, pages } = bake();
  const base = atlas.index.get(name);
  assert.notEqual(base, undefined, `sprite ${JSON.stringify(name)} missing from atlas`);
  const { page, x, y } = atlas.locate(base + frame);
  const image = pages[page];
  const out = Buffer.alloc(atlas.tile * atlas.tile * 4);
  for (let dy = 0; dy < atlas.tile; dy++) {
    const from = ((y + dy) * image.width + x) * 4;
    image.data.copy(out, dy * atlas.tile * 4, from, from + atlas.tile * 4);
  }
  return out;
}

// Greyscale means greyscale: the baked cable cell must carry NO colour of
// its own, or the runtime multiply lands on top of a tint that is already
// there and the wire is the wrong red.
test("tinted_art_is_baked_grey", { skip }, () => {
  for (const name of ["cable_l1_5", "cable_l2_5", "cable_l1_none"]) {
    const pixels = cell(name);
    let coloured = false;
    for (let i = 0; i < pixels.length && !coloured; i += 4)
      coloured = pixels[i + 3] > 0
        && (pixels[i] !== pixels[i + 1] || pixels[i + 1] !== pixels[i + 2]);
    assert.ok(!coloured,
      `${name} is baked with colour in it; the tint belongs at draw time `
      + "(rebake: cargo run -p xtask -- bake-atlas --tg <checkout>)");
  }
});

// Half of tg's art is a greyscale config: a flat silhouette whose only job
// is to take a colour, plus sibling layers carrying the actual shape. A
// real sprite has tonal variation; a mask does not. The rule fires only
// where the flat colour is also achromatic, which is what every unbaked
// greyscale config looks like and what no drawn sprite does.
test("no_sprite_is_a_bare_colour_mask", { skip }, () => {
  // Deliberately flat: a synthetic fill quad, the void, the ghost
  // silhouette, and the wind streak -- white with its whole shape in the
  // ALPHA, because the gas overlay multiplies it by the gas colour.
  const FLAT_BY_DESIGN = ["white", "space", "ghost", "wind_streak"];
  // Name prefixes whose whole family is flat paint: the renderer
  // multiplies each sprite by the colour its record carries.
  const FLAT_FAMILIES = ["decal_"];
  for (const name of bake().atlas.index.keys()) {
    if (FLAT_BY_DESIGN.includes(name) || FLAT_FAMILIES.some((p) => name.startsWith(p))) continue;
    const pixels = cell(name);
    const histogram = new Map();
    let area = 0;
    for (let i = 0; i < pixels.length; i += 4) {
      if (pixels[i + 3] === 0) continue;
      const key = (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
      histogram.set(key, (histogram.get(key) ?? 0) + 1);
      area++;
    }
    // Tiny sprites (in-hand fragments) have too few pixels for the ratio
    // to mean anything.
    if (area < 40) continue;
    let [colour, dominant] = [0, 0];
    for (const [key, count] of histogram) if (count > dominant) [colour, dominant] = [key, count];
    const channels = [(colour >> 16) & 0xff, (colour >> 8) & 0xff, colour & 0xff];
    // Chromatic: drawn art, however flat. A greyscale config's silhouette
    // is grey by construction, so this cannot excuse one.
    if (Math.max(...channels) - Math.min(...channels) > 6) continue;
    const frac = dominant / area;
    assert.ok(frac < 0.85,
      `${name} is ${(frac * 100).toFixed(0)}% one colour over ${area}px — that is a greyscale `
      + "MASK, not art. Check tg's code/datums/greyscale/json_configs for the sibling layers it "
      + "needs, and bake them with DmiBlend.");
  }
});

// The animation contract on the real baked atlas: a door's swing is tg's
// six tenths and plays ONCE, a running fan cycles forever, and every frame
// of both resolves to a cell that actually holds different art.
test("animated_sprites_carry_tgs_own_timing", { skip }, () => {
  const { atlas } = bake();
  const swing = atlas.anim.get("door_opening");
  assert.ok(swing, "the airlock animates");
  assert.equal(swing.frames.length, 6);
  assert.equal(swing.frames.reduce((a, b) => a + b, 0), 600, "tg's 0.6 SECONDS swing");
  assert.ok(swing.once, "a door swings once and stays where it lands");

  const fan = atlas.anim.get("vent_on");
  assert.ok(fan, "a running vent animates");
  assert.ok(!fan.once, "a fan does not stop turning");
  assert.equal(fan.frames.reduce((a, b) => a + b, 0), 320);
  assert.equal(atlas.anim.get("door"), undefined, "a shut door holds still");
  assert.equal(atlas.frameCount("door"), 1);

  // Distinct cells with distinct art: a "6-frame" animation baked from one
  // cell six times passes every timing assertion and still does not move.
  for (const name of ["door_opening", "vent_on"]) {
    const frames = atlas.frameCount(name);
    for (let f = 1; f < frames; f++)
      assert.ok(!cell(name, f - 1).equals(cell(name, f)),
        `${name}: frames ${f - 1} and ${f} are the same picture — the baker is reading one cell `
        + `${frames} times`);
  }
});

// The directional frame convention a wall mount picks a picture by: every
// face has its own picture and displacement, and a worn displacement never
// moves the world one.
test("embedded_atlas_covers_mounted_frames", { skip }, () => {
  const { atlas } = bake();
  for (const base of ["apc", "light_on", "light_off"])
    for (const suffix of ["s", "n", "e", "w"]) {
      const name = `${base}_${suffix}`;
      const index = atlas.index.get(name);
      assert.notEqual(index, undefined, `sprite ${JSON.stringify(name)} missing from atlas`);
      assert.ok(index < atlas.cells, `${name} resolves to a cell outside the atlas`);
    }
  assert.deepEqual(atlas.offset("apc_n"), { x: 0.0, y: -25.0 / 32.0 });
  assert.deepEqual(atlas.offset("apc_e"), { x: 25.0 / 32.0, y: 0.0 });
  assert.deepEqual(atlas.offset("light_on_n"), { x: 0.0, y: 0.0 });
  assert.deepEqual(atlas.wornOffset("belt_wrench"), { x: 0.0, y: 0.0 });
  assert.deepEqual(atlas.wornOffset("toolbelt"), { x: 0.0, y: 0.0 });
  assert.equal(atlas.tile, 32);
  assert.ok(!cell("light_on_n").equals(cell("light_off_n")),
    "the powered tube includes tg's visible light overlay");
  assert.ok(!cell("light_off_n").equals(cell("light_off_s")),
    "wallward light directions use distinct DMI frames");
});

/** The RPD's recipe roster, as the document resolves it through the atlas. */
const RPD_RECIPE_ICONS = [
  "pipe", "manual_valve_loose", "digital_valve_loose", "pump_loose", "volume_pump_loose",
  "passive_gate_loose", "pressure_valve_loose", "filter_fitting", "mixer_fitting",
  "connector_port_loose", "pipe_meter", "layer_adapter_loose", "color_adapter_loose",
  "temperature_gate_loose", "temperature_pump_loose", "heat_exchanger_loose",
  "air_scrubber_loose", "air_injector_loose",
];

// The recipe roster is content-authored while the document resolves those
// names through the atlas, so a typo turns one otherwise valid choice blank.
test("every_rpd_recipe_icon_exists_in_the_embedded_atlas", { skip }, () => {
  const { atlas } = bake();
  for (const name of RPD_RECIPE_ICONS)
    assert.ok(atlas.index.has(name),
      `the RPD recipe icon ${JSON.stringify(name)} is absent from the embedded atlas`);
});

test("loose_atmos_fittings_have_a_picture_for_every_rotation", { skip }, () => {
  const { atlas } = bake();
  // Every recipe icon that is a rotatable fitting: the straight pipe and
  // the meter carry no per-rotation family.
  for (const base of RPD_RECIPE_ICONS.filter((name) => name !== "pipe" && name !== "pipe_meter"))
    for (const suffix of ["s", "n", "e", "w"]) {
      const name = `${base}_${suffix}`;
      assert.ok(atlas.index.has(name),
        `rotating ${JSON.stringify(base)} would select absent sprite ${JSON.stringify(name)}`);
    }
});

// A working scrubber is not a still lit grille. tg's `scrub_on` and
// `scrub_purge` states are authored loops with different silhouettes and
// cadences; pin them for every facing so a later atlas cleanup cannot
// quietly fall back to frame zero again.
test("air_scrubbers_keep_their_tgstation_loops", { skip }, () => {
  const { atlas } = bake();
  for (const suffix of ["n", "s", "e", "w"]) {
    const on = atlas.anim.get(`scrubber_on_${suffix}`);
    assert.ok(on, `scrubber_on_${suffix} was baked as a still`);
    assert.deepEqual(on.frames, Array(24).fill(80),
      "tg's scrub_on has 24 evenly held 80ms frames");
    assert.ok(!on.once, "scrubbing is a steady loop, not a transition");

    const purge = atlas.anim.get(`scrubber_purge_${suffix}`);
    assert.ok(purge, `scrubber_purge_${suffix} was baked as a still`);
    assert.deepEqual(purge.frames, [200, 40, 40, 40, 40, 40, 40, 40],
      "tg's scrub_purge holds its first frame, then flashes seven fast frames");
    assert.ok(!purge.once, "siphoning is a steady loop, not a transition");
  }
});
