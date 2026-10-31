(() => {
  "use strict";

  const DATA = window.ELEMENTAL_GALLERY_DATA;
  if (!DATA) {
    document.getElementById("header-summary").textContent = "ERROR: gallery_data.js not loaded.";
    return;
  }

  // Amounts (mL, mol) where the drawn sprite and shell change; built by build_gallery.py.
  const TH_LIQUID = DATA.thresholds.liquid;
  const TH_GAS = DATA.thresholds.gas;

  const NORTH = 1, SOUTH = 2, EAST = 4, WEST = 8;
  const NE = 16, SE = 32, SW = 64, NW = 128;
  const JUNCTIONS = DATA.junctions;
  const JUNCTION_INDEX = new Map(JUNCTIONS.map((j, idx) => [j, idx]));
  const BLOCK_NAMES = ["0:convex", "1:vertical", "2:horizontal", "3:concave", "4:flat"];

  const GRID_W = 10;
  const GRID_H = 8;

  const SPRITE_MAP = new Map();
  for (const sp of DATA.sprites) {
    SPRITE_MAP.set(sp.id, sp);
  }

  const IMAGE_CACHE = new Map();
  const TINT_CANVAS_CACHE = new Map();

  const LIQUID_PRESETS = [
    { name: "Water", hex: "#4BA3E3", flammable: false },
    { name: "Crude Oil", hex: "#3B2F22", flammable: true },
    { name: "Cooking Grease", hex: "#D4A438", flammable: true },
    { name: "Blood", hex: "#A3121A", flammable: false },
    { name: "Sulfuric Acid", hex: "#6CE635", flammable: false },
    { name: "Mercury", hex: "#D8DCE3", flammable: false },
  ];

  const GAS_PRESETS = [
    { name: "Steam / Vapor", hex: "#D8EEFF", flammable: false, fireTint: null },
    { name: "Hydrocarbon Gas", hex: "#E5AA52", flammable: true, fireTint: null },
    { name: "Plasma Gas", hex: "#D95BFF", flammable: true, fireTint: "#E46BFF" },
    { name: "Hydrogen / Methane", hex: "#66C4FF", flammable: true, fireTint: "#55B8FF" },
    { name: "Soot Smoke", hex: "#5C5E66", flammable: false, fireTint: null },
    { name: "Chlorine / Miasma", hex: "#76C95B", flammable: false, fireTint: null },
  ];

  const SOLID_PRESETS = [
    { name: "Wheat Flour", hex: "#F5F0E1", flammable: "dust" },
    { name: "Coal / Charcoal", hex: "#353338", flammable: "campfire" },
    { name: "Campfire Wood/Tinder", hex: "#8A5E3B", flammable: "campfire" },
    { name: "Tunnel Rock Debris", hex: "#8A837C", flammable: false },
    { name: "Dry Farm Loam", hex: "#7D5838", flammable: false },
    { name: "Wet Irrigated Loam", hex: "#4A321F", flammable: false },
    { name: "Quartz / Ice Shards", hex: "#BFE6FA", flammable: false },
    { name: "Sulfur Powder", hex: "#E3CF3B", flammable: "campfire" },
  ];

  const state = {
    grid: [],
    selectedX: 4,
    selectedY: 4,
    gravity: "1g",
    bgMode: "plating",
    scale: 3,
    animSpeed: 1.0,
    playing: true,
    clockMs: 0,
    lastRafTs: 0,
    activeTint: "#4BA3E3",
    activeSubstanceName: "Water",
    activeFlammable: false,
    activeFireTint: null,
    slicerNeighborMask: NORTH | EAST | SOUTH | SE,
    slicerAssetId: "",
    slicerTint: "#4BA3E3",
    slicerBg: "plating",
    catalogLiveCanvases: [],
    slicer47Canvases: [],
  };

  function makeEmptyCell() {
    return {
      wall: false,
      decal: null,     // { spriteId, tint }
      solidBase: null, // { kind, spriteId, smoothGroup, tint, name, flammable }
      solidTop: null,  // { kind, spriteId, smoothGroup: null, tint, name, flammable }
      liquid: null,    // { volumeMl, tint, name, flammable, variant }
      fire: null,      // { regime, spriteId, smoothGroup, tint }
      gas: null,       // { moles, agitation, tint, name, flammable, fireTint }
    };
  }

  function resetGrid() {
    state.grid = [];
    for (let y = 0; y < GRID_H; y++) {
      const row = [];
      for (let x = 0; x < GRID_W; x++) {
        row.push(makeEmptyCell());
      }
      state.grid.push(row);
    }
  }

  function inBounds(x, y) {
    return x >= 0 && x < GRID_W && y >= 0 && y < GRID_H;
  }

  function loadImg(uri) {
    if (!uri) return Promise.resolve(null);
    if (IMAGE_CACHE.has(uri)) return Promise.resolve(IMAGE_CACHE.get(uri));
    return new Promise((resolve, reject) => {
      const im = new Image();
      im.onload = () => {
        IMAGE_CACHE.set(uri, im);
        resolve(im);
      };
      im.onerror = reject;
      im.src = uri;
    });
  }

  function normalizeHex(hex) {
    if (!hex) return "#FFFFFF";
    const h = hex.trim().toUpperCase();
    return /^#[0-9A-F]{6}$/.test(h) ? h : "#FFFFFF";
  }

  function parseHexRgb(hex) {
    const h = normalizeHex(hex).slice(1);
    return [
      parseInt(h.slice(0, 2), 16),
      parseInt(h.slice(2, 4), 16),
      parseInt(h.slice(4, 6), 16),
    ];
  }

  function getTintedSheet(uri, tintHex, isColorable) {
    const baseImg = IMAGE_CACHE.get(uri);
    if (!baseImg) return null;
    const normTint = isColorable ? normalizeHex(tintHex) : "#FFFFFF";
    if (normTint === "#FFFFFF") return baseImg;

    const key = uri + "|" + normTint;
    if (TINT_CANVAS_CACHE.has(key)) return TINT_CANVAS_CACHE.get(key);

    const [tr, tg, tb] = parseHexRgb(normTint);
    const cv = document.createElement("canvas");
    cv.width = baseImg.width;
    cv.height = baseImg.height;
    const ctx = cv.getContext("2d", { willReadFrequently: true });
    ctx.drawImage(baseImg, 0, 0);
    const imgData = ctx.getImageData(0, 0, cv.width, cv.height);
    const d = imgData.data;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] > 0) {
        d[i] = ((d[i] * tr + 127) / 255) | 0;
        d[i + 1] = ((d[i + 1] * tg + 127) / 255) | 0;
        d[i + 2] = ((d[i + 2] * tb + 127) / 255) | 0;
      }
    }
    ctx.putImageData(imgData, 0, 0);
    TINT_CANVAS_CACHE.set(key, cv);
    return cv;
  }

  function frameIndexForSprite(sp, clockMs) {
    if (!sp || sp.frame_count <= 1) return 0;
    const durs = sp.durations_ms;
    let total = 0;
    for (let i = 0; i < durs.length; i++) total += durs[i];
    if (total <= 0) return 0;
    let rem = clockMs % total;
    for (let i = 0; i < durs.length; i++) {
      if (rem < durs[i]) return i;
      rem -= durs[i];
    }
    return 0;
  }

  function sanitizeDiagonalMask(rawMask) {
    const n = !!(rawMask & NORTH);
    const s = !!(rawMask & SOUTH);
    const e = !!(rawMask & EAST);
    const w = !!(rawMask & WEST);
    let j = (n ? NORTH : 0) | (s ? SOUTH : 0) | (e ? EAST : 0) | (w ? WEST : 0);
    if (n && e && (rawMask & NE)) j |= NE;
    if (s && e && (rawMask & SE)) j |= SE;
    if (s && w && (rawMask & SW)) j |= SW;
    if (n && w && (rawMask & NW)) j |= NW;
    return j;
  }

  function computeJunctionOnGrid(predFn, x, y) {
    const n = inBounds(x, y - 1) && predFn(x, y - 1);
    const s = inBounds(x, y + 1) && predFn(x, y + 1);
    const e = inBounds(x + 1, y) && predFn(x + 1, y);
    const w = inBounds(x - 1, y) && predFn(x - 1, y);
    let j = (n ? NORTH : 0) | (s ? SOUTH : 0) | (e ? EAST : 0) | (w ? WEST : 0);
    if (n && e && inBounds(x + 1, y - 1) && predFn(x + 1, y - 1)) j |= NE;
    if (s && e && inBounds(x + 1, y + 1) && predFn(x + 1, y + 1)) j |= SE;
    if (s && w && inBounds(x - 1, y + 1) && predFn(x - 1, y + 1)) j |= SW;
    if (n && w && inBounds(x - 1, y - 1) && predFn(x - 1, y - 1)) j |= NW;
    return j;
  }

  function quadrantBlocksForJunction(j) {
    const specs = [
      { label: "NW (0,0)", v: !!(j & NORTH), h: !!(j & WEST), d: !!(j & NW) },
      { label: "NE (16,0)", v: !!(j & NORTH), h: !!(j & EAST), d: !!(j & NE) },
      { label: "SW (0,16)", v: !!(j & SOUTH), h: !!(j & WEST), d: !!(j & SW) },
      { label: "SE (16,16)", v: !!(j & SOUTH), h: !!(j & EAST), d: !!(j & SE) },
    ];
    return specs.map((q) => {
      let b = 4;
      if (!q.v && !q.h) b = 0;
      else if (q.v && !q.h) b = 1;
      else if (!q.v && q.h) b = 2;
      else if (q.v && q.h && !q.d) b = 3;
      return { ...q, block: b, blockName: BLOCK_NAMES[b] };
    });
  }

  function drawBackgroundTile(ctx, bgMode, dx, dy, size) {
    if (bgMode === "dark") {
      ctx.fillStyle = "#151824";
      ctx.fillRect(dx, dy, size, size);
      return;
    }
    if (bgMode === "light") {
      ctx.fillStyle = "#F1EAD4";
      ctx.fillRect(dx, dy, size, size);
      return;
    }
    if (bgMode === "checker") {
      const half = size / 2;
      ctx.fillStyle = "#252936";
      ctx.fillRect(dx, dy, size, size);
      ctx.fillStyle = "#343a4d";
      ctx.fillRect(dx, dy, half, half);
      ctx.fillRect(dx + half, dy + half, half, half);
      return;
    }
    const turf = DATA.turfs[bgMode] || DATA.turfs.plating;
    if (turf) {
      const im = IMAGE_CACHE.get(turf.data_uri);
      if (im) {
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(im, dx, dy, size, size);
        return;
      }
    }
    ctx.fillStyle = "#262830";
    ctx.fillRect(dx, dy, size, size);
  }

  function drawSpriteTile(ctx, spriteId, tintHex, junctionVal, dx, dy, size, clockMs) {
    const sp = SPRITE_MAP.get(spriteId);
    if (!sp) return null;
    const sheet = getTintedSheet(sp.atlas_data_uri, tintHex, sp.colorable);
    if (!sheet) return null;
    const fIdx = frameIndexForSprite(sp, clockMs);
    ctx.imageSmoothingEnabled = false;
    if (sp.kind === "single") {
      ctx.drawImage(sheet, fIdx * 32, 0, 32, 32, dx, dy, size, size);
      return { sp, fIdx, junction: null };
    } else {
      const jClean = sanitizeDiagonalMask(junctionVal || 0);
      const jIdx = JUNCTION_INDEX.has(jClean) ? JUNCTION_INDEX.get(jClean) : 0;
      ctx.drawImage(sheet, jIdx * 32, fIdx * 32, 32, 32, dx, dy, size, size);
      return { sp, fIdx, junction: jClean };
    }
  }

  // Resolve liquid cell into 1 or 2 layered draws (hierarchical wet smoothing!)
  function resolveLiquidDraws(x, y) {
    const cell = state.grid[y][x];
    if (!cell.liquid || cell.liquid.volumeMl < TH_LIQUID.splatter_min) return [];
    const liq = cell.liquid;
    const v = liq.volumeMl;
    const pick2 = (((x * 374761393 + y * 668265263 + (liq.variant || 0) * 1442695041) >>> 8) & 1);

    if (state.gravity === "0g") {
      let sid = "liquid_zerog_small_float";
      if (v >= TH_LIQUID.zerog_large_min) sid = "liquid_zerog_large_float";
      else if (v >= TH_LIQUID.zerog_mixed_min) sid = "liquid_zerog_mixed_float";
      return [{ spriteId: sid, tint: liq.tint, junction: null, role: "0g Laplace spheres" }];
    }

    // 1g Nested Wet Contour Shells:
    // - Shell 1 (Puddle): drawn UNCONDITIONALLY on all wet tiles >= 260 mL (connects across >= 260 mL)
    //   so shallow water/oil never drops out at the pool boundary!
    // - Shell 2 (Pool): drawn ON TOP on deep tiles >= 2200 mL (connects across >= 2200 mL)
    //   with a wide feathered alpha taper that deepens smoothly into the puddle below.
    // - Peripheral (< 260 mL): discrete spill (140..259), splash (65..139), splatter (10..64).
    const draws = [];
    if (v >= TH_LIQUID.puddle_min) {
      const jPuddle = computeJunctionOnGrid(
        (nx, ny) => {
          const nl = state.grid[ny][nx].liquid;
          return !!nl && nl.volumeMl >= TH_LIQUID.puddle_min && nl.tint === liq.tint;
        },
        x,
        y
      );
      draws.push({
        spriteId: "liquid_puddle_smooth_shimmer",
        tint: liq.tint,
        junction: jPuddle,
        role: `1g shallow wet shell (>=${TH_LIQUID.puddle_min} mL)`,
      });
      if (v >= TH_LIQUID.pool_min) {
        const jPool = computeJunctionOnGrid(
          (nx, ny) => {
            const nl = state.grid[ny][nx].liquid;
            return !!nl && nl.volumeMl >= TH_LIQUID.pool_min && nl.tint === liq.tint;
          },
          x,
          y
        );
        draws.push({
          spriteId: "liquid_pool_smooth_ripple",
          tint: liq.tint,
          junction: jPool,
          role: `1g ankle-deep+ pool shell (>=${TH_LIQUID.pool_min} mL)`,
        });
      }
      return draws;
    }

    if (v >= TH_LIQUID.spill_min) {
      const sid = pick2 === 0 ? "liquid_spill_1" : "liquid_spill_2";
      return [{ spriteId: sid, tint: liq.tint, junction: null, role: "1g discrete spill" }];
    }
    if (v >= TH_LIQUID.splash_min) {
      const sid = pick2 === 0 ? "liquid_splash_1" : "liquid_splash_2";
      return [{ spriteId: sid, tint: liq.tint, junction: null, role: "1g droplet splash" }];
    }
    const sid = pick2 === 0 ? "liquid_splatter_1" : "liquid_splatter_2";
    return [{ spriteId: sid, tint: liq.tint, junction: null, role: "1g peripheral splatter" }];
  }

  function resolveSolidDraws(x, y) {
    const cell = state.grid[y][x];
    const draws = [];
    if (cell.solidBase) {
      const sb = cell.solidBase;
      if (!sb.smoothGroup) {
        draws.push({ spriteId: sb.spriteId, tint: sb.tint, junction: null, role: sb.kind });
      } else {
        const j = computeJunctionOnGrid(
          (nx, ny) => {
            const nsb = state.grid[ny][nx].solidBase;
            return !!nsb && nsb.smoothGroup === sb.smoothGroup;
          },
          x,
          y
        );
        draws.push({ spriteId: sb.spriteId, tint: sb.tint, junction: j, role: sb.kind });
      }
    }
    if (cell.solidTop) {
      const st = cell.solidTop;
      draws.push({ spriteId: st.spriteId, tint: st.tint, junction: null, role: st.kind });
    }
    return draws;
  }

  function resolveFireDraws(x, y) {
    const f = state.grid[y][x].fire;
    if (!f) return [];
    if (!f.smoothGroup) {
      return [{ spriteId: f.spriteId, tint: f.tint || "#FFFFFF", junction: null, role: f.regime }];
    }
    const j = computeJunctionOnGrid(
      (nx, ny) => {
        const nf = state.grid[ny][nx].fire;
        return !!nf && nf.smoothGroup === f.smoothGroup;
      },
      x,
      y
    );
    return [{ spriteId: f.spriteId, tint: f.tint || "#FFFFFF", junction: j, role: f.regime }];
  }

  function resolveGasDraws(x, y) {
    const g = state.grid[y][x].gas;
    if (!g || g.moles < TH_GAS.mist_min) return [];
    const ag = g.agitation || "gentle";
    // Nested Gas Contour Shells:
    // Mist (>=0.35 mol) runs unbroken beneath Smoke (>=2.5 mol), which runs unbroken beneath Cloud (>=8.0 mol).
    // Each denser shell feathers smoothly into the continuous lower-density shell underneath!
    const draws = [];
    const jMist = computeJunctionOnGrid(
      (nx, ny) => {
        const ng = state.grid[ny][nx].gas;
        return !!ng && ng.moles >= TH_GAS.mist_min && ng.tint === g.tint;
      },
      x,
      y
    );
    draws.push({
      spriteId: `gas_mist_smooth_${ag}`,
      tint: g.tint,
      junction: jMist,
      role: `mist shell (${ag})`,
    });

    if (g.moles >= TH_GAS.smoke_min) {
      const jSmoke = computeJunctionOnGrid(
        (nx, ny) => {
          const ng = state.grid[ny][nx].gas;
          return !!ng && ng.moles >= TH_GAS.smoke_min && ng.tint === g.tint;
        },
        x,
        y
      );
      draws.push({
        spriteId: `gas_smoke_smooth_${ag}`,
        tint: g.tint,
        junction: jSmoke,
        role: `smoke shell (${ag})`,
      });
    }

    if (g.moles >= TH_GAS.cloud_min) {
      const jCloud = computeJunctionOnGrid(
        (nx, ny) => {
          const ng = state.grid[ny][nx].gas;
          return !!ng && ng.moles >= TH_GAS.cloud_min && ng.tint === g.tint;
        },
        x,
        y
      );
      draws.push({
        spriteId: `gas_cloud_smooth_${ag}`,
        tint: g.tint,
        junction: jCloud,
        role: `dense cloud core (${ag})`,
      });
    }
    return draws;
  }

  // === DYNAMIC GENERATORS ===
  function logPhysics(msg) {
    const box = document.getElementById("physics-log");
    if (box) box.textContent = msg;
  }

  // Wall-aware geodesic path distance on 10x8 grid (prevents diagonal corner cutting across walls)
  function computeGeodesicDistances(cx, cy) {
    const dist = Array.from({ length: GRID_H }, () => Array(GRID_W).fill(Infinity));
    if (!inBounds(cx, cy) || state.grid[cy][cx].wall) return dist;
    dist[cy][cx] = 0;
    const dirs = [
      [0, -1, 1.0], [0, 1, 1.0], [1, 0, 1.0], [-1, 0, 1.0],
      [1, -1, 1.34], [1, 1, 1.34], [-1, 1, 1.34], [-1, -1, 1.34],
    ];
    for (let pass = 0; pass < GRID_W * GRID_H; pass++) {
      let changed = false;
      for (let y = 0; y < GRID_H; y++) {
        for (let x = 0; x < GRID_W; x++) {
          if (dist[y][x] === Infinity) continue;
          for (const [dx, dy, cost] of dirs) {
            const nx = x + dx, ny = y + dy;
            if (!inBounds(nx, ny) || state.grid[ny][nx].wall) continue;
            if (dx !== 0 && dy !== 0 && state.grid[y][nx].wall && state.grid[ny][x].wall) continue;
            const jitter = 0.94 + (((nx * 37 + ny * 91 + cx * 13 + cy * 29) % 13) * 0.01);
            const nd = dist[y][x] + cost * jitter;
            if (nd < dist[ny][nx]) {
              dist[ny][nx] = nd;
              changed = true;
            }
          }
        }
      }
      if (!changed) break;
    }
    return dist;
  }

  function pourLiquidSpill(cx, cy, totalVolumeMl, flowFactor, tint, name, flammable) {
    if (!inBounds(cx, cy) || state.grid[cy][cx].wall) return;
    const normTint = normalizeHex(tint);
    const dist = computeGeodesicDistances(cx, cy);

    // Plateau-core stretched-exponential hydrostatic profile on isolated delta buffer (added[][]):
    // preserves existing unrelated liquids elsewhere on the grid!
    const coreR = Math.min(1.06, Math.max(0.0, (totalVolumeMl - 7000) / 19000));
    const sigma = 0.62 + flowFactor * 0.42;
    const raw = Array.from({ length: GRID_H }, () => Array(GRID_W).fill(0));
    let sumW = 0;
    for (let y = 0; y < GRID_H; y++) {
      for (let x = 0; x < GRID_W; x++) {
        if (dist[y][x] === Infinity) continue;
        const w = Math.exp(-Math.pow(Math.max(0, dist[y][x] - coreR) / sigma, 1.35));
        if (w >= 0.005) {
          raw[y][x] = w;
          sumW += w;
        }
      }
    }
    const added = Array.from({ length: GRID_H }, (_, y) =>
      Array.from({ length: GRID_W }, (_, x) => (sumW > 0 ? (raw[y][x] / sumW) * totalVolumeMl : 0))
    );

    // Eject discrete peripheral spill/splash/splatter droplets just outside the wet puddle rim
    const dirs8 = [[0, -1], [0, 1], [1, 0], [-1, 0], [1, -1], [1, 1], [-1, 1], [-1, -1]];
    for (let y = 0; y < GRID_H; y++) {
      for (let x = 0; x < GRID_W; x++) {
        if (state.grid[y][x].wall || added[y][x] >= TH_LIQUID.puddle_min) continue;
        let maxAdj = 0;
        for (const [dx, dy] of dirs8) {
          const nx = x + dx, ny = y + dy;
          if (inBounds(nx, ny) && added[ny][nx] > maxAdj) maxAdj = added[ny][nx];
        }
        const h = ((x * 73 + y * 137 + cx * 31 + cy * 59) >>> 0) % 100;
        if (maxAdj >= TH_LIQUID.puddle_min && added[y][x] < TH_LIQUID.spill_min) {
          if (h < 28) added[y][x] = Math.max(added[y][x], 185);
          else if (h < 56) added[y][x] = Math.max(added[y][x], 95);
          else if (h < 80) added[y][x] = Math.max(added[y][x], 38);
        }
      }
    }

    let wetTiles = 0, poolTiles = 0, puddleTiles = 0, dropletTiles = 0;
    for (let y = 0; y < GRID_H; y++) {
      for (let x = 0; x < GRID_W; x++) {
        if (state.grid[y][x].wall) continue;
        const addV = Math.round(added[y][x]);
        if (addV < 12) continue;
        const existing = state.grid[y][x].liquid;
        let finalV = addV;
        if (existing && existing.tint === normTint) {
          finalV = existing.volumeMl + addV;
        } else if (existing && existing.volumeMl > addV) {
          // Existing different-substance liquid dominates this tile; leave it intact!
          continue;
        }
        state.grid[y][x].liquid = {
          volumeMl: finalV,
          tint: normTint,
          name,
          flammable: !!flammable,
          variant: (cx * 7 + cy * 13) & 3,
        };
        wetTiles++;
        if (finalV >= TH_LIQUID.pool_min) poolTiles++;
        else if (finalV >= TH_LIQUID.puddle_min) puddleTiles++;
        else dropletTiles++;
      }
    }
    logPhysics(
      `[Spill Solver] Poured ${totalVolumeMl} mL ${name} (${normTint}) at (${cx},${cy}), flow=${flowFactor}.\n` +
      `Result (${state.gravity}): ${wetTiles} wet tiles -> ${poolTiles} deep pool (>=${TH_LIQUID.pool_min} mL), ` +
      `${puddleTiles} smooth puddle (${TH_LIQUID.puddle_min}..${TH_LIQUID.pool_min - 1} mL), ${dropletTiles} peripheral spill/splash/splatter (<${TH_LIQUID.puddle_min} mL).`
    );
  }

  function releaseGasPlume(cx, cy, totalMoles, agitation, tint, name, flammable, fireTint) {
    if (!inBounds(cx, cy) || state.grid[cy][cx].wall) return;
    const normTint = normalizeHex(tint);
    const dist = computeGeodesicDistances(cx, cy);
    const spread = agitation === "stirred" ? 1.08 : agitation === "still" ? 0.88 : 1.0;
    const coreR = Math.min(1.05, Math.max(0.0, (totalMoles - 24) / 80));
    const sigma = 0.82 * spread;

    const raw = Array.from({ length: GRID_H }, () => Array(GRID_W).fill(0));
    let sumW = 0;
    for (let y = 0; y < GRID_H; y++) {
      for (let x = 0; x < GRID_W; x++) {
        if (dist[y][x] === Infinity) continue;
        const w = Math.exp(-Math.pow(Math.max(0, dist[y][x] - coreR) / sigma, 1.35));
        if (w >= 0.012) {
          raw[y][x] = w;
          sumW += w;
        }
      }
    }

    let cCloud = 0, cSmoke = 0, cMist = 0;
    for (let y = 0; y < GRID_H; y++) {
      for (let x = 0; x < GRID_W; x++) {
        if (state.grid[y][x].wall || sumW <= 0) continue;
        const addM = Math.round(((raw[y][x] / sumW) * totalMoles) * 10) / 10;
        if (addM < TH_GAS.mist_min) continue;
        const existing = state.grid[y][x].gas;
        let finalM = addM;
        if (existing && existing.tint === normTint) {
          finalM = Math.round((existing.moles + addM) * 10) / 10;
        } else if (existing && existing.moles > addM) {
          // Existing denser gas plume of a different tint keeps its tile
          continue;
        }
        state.grid[y][x].gas = {
          moles: finalM,
          agitation,
          tint: normTint,
          name,
          flammable: !!flammable,
          fireTint: fireTint || null,
        };
        if (finalM >= TH_GAS.cloud_min) cCloud++;
        else if (finalM >= TH_GAS.smoke_min) cSmoke++;
        else cMist++;
      }
    }
    logPhysics(
      `[Gas Diffusion] Released ${totalMoles} mol ${name} (${agitation}) at (${cx},${cy}).\n` +
      `Plume shells: ${cCloud} dense cloud (>=${TH_GAS.cloud_min} mol), ${cSmoke} medium smoke (>=${TH_GAS.smoke_min} mol), ${cMist} light mist (>=${TH_GAS.mist_min} mol).`
    );
  }

  function depositSolid(cx, cy, kind, radius, tint, name, flammable) {
    const map = {
      flour_smooth: { spriteId: "solid_dusting_flour_smooth", smoothGroup: "flour", slot: "base" },
      flour_single: { spriteId: "solid_dusting_flour_single", smoothGroup: null, slot: "base" },
      debris_smooth: { spriteId: "solid_debris_jagged_smooth", smoothGroup: "debris", slot: "base" },
      debris_single: { spriteId: "solid_debris_jagged_single", smoothGroup: null, slot: "base" },
      soil_smooth: { spriteId: "solid_soil_smooth", smoothGroup: "soil", slot: "base" },
      soil_single: { spriteId: "solid_soil_patch_single", smoothGroup: null, slot: "base" },
      soil_tilled: { spriteId: "solid_soil_tilled_smooth", smoothGroup: "soil_tilled", slot: "base" },
      pile_large: { spriteId: "solid_pile_large", smoothGroup: null, slot: "top" },
      pile_small: { spriteId: "solid_pile_small", smoothGroup: null, slot: "top" },
      sprinkles: { spriteId: "solid_sprinkles", smoothGroup: null, slot: "top" },
      scattering: { spriteId: "solid_scattering", smoothGroup: null, slot: "top" },
      shards_large: { spriteId: "solid_shards_large", smoothGroup: null, slot: "top" },
      shards_small: { spriteId: "solid_shards_small", smoothGroup: null, slot: "top" },
    };
    const cfg = map[kind] || map.flour_smooth;
    const normTint = normalizeHex(tint);
    let count = 0;
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        const x = cx + dx, y = cy + dy;
        if (!inBounds(x, y) || state.grid[y][x].wall) continue;
        if (dx * dx + dy * dy <= radius * radius + 0.6) {
          const entry = {
            kind,
            spriteId: cfg.spriteId,
            smoothGroup: cfg.smoothGroup ? `${cfg.smoothGroup}:${normTint}` : null,
            tint: normTint,
            name,
            flammable: flammable || false,
          };
          if (cfg.slot === "base") {
            state.grid[y][x].solidBase = entry;
          } else {
            state.grid[y][x].solidTop = entry;
          }
          count++;
        }
      }
    }
    logPhysics(`[Solid Deposit] Placed ${count} tile(s) of ${name} (${cfg.spriteId}, slot=${cfg.slot}, tint ${normTint}).`);
  }

  function igniteCell(x, y) {
    const cell = state.grid[y][x];
    if (cell.wall) return false;

    // Priority 1: Combustible gas cloud oxidation
    if (cell.gas && (cell.gas.flammable || cell.gas.moles >= 3.0)) {
      cell.gas.agitation = "stirred";
      if (cell.gas.fireTint) {
        cell.fire = {
          regime: "Violent Gas Deflagration (Tintable)",
          spriteId: "fire_gas_smooth_tintable",
          smoothGroup: "fire_gas_tint",
          tint: cell.gas.fireTint,
        };
      } else {
        cell.fire = {
          regime: "Violent Gas Cloud Oxidation",
          spriteId: "fire_gas_smooth_violent",
          smoothGroup: "fire_gas",
          tint: "#FFFFFF",
        };
      }
      return true;
    }

    // Priority 2: Liquid oil / grease pool fire
    if (cell.liquid && cell.liquid.volumeMl >= 120) {
      cell.decal = { spriteId: "fire_scorch_mark", tint: "#FFFFFF" };
      if (cell.liquid.volumeMl >= TH_LIQUID.puddle_min && state.gravity === "1g") {
        cell.fire = {
          regime: "Evaporative Oil/Grease Pool Fire (O2 Rim + Soot Core)",
          spriteId: "fire_grease_smooth",
          smoothGroup: "fire_grease",
          tint: "#FFFFFF",
        };
      } else {
        cell.fire = {
          regime: "Discrete Liquid Spill Fire",
          spriteId: "fire_grease_single",
          smoothGroup: null,
          tint: "#FFFFFF",
        };
      }
      if (!cell.gas) {
        cell.gas = {
          moles: cell.liquid.volumeMl >= 1500 ? 4.8 : 1.8,
          agitation: "gentle",
          tint: "#4A4C54",
          name: "Incomplete Combustion Soot",
          flammable: false,
          fireTint: null,
        };
      }
      return true;
    }

    // Priority 3: Solid fuel (campfire over piles, flash dust burn over flour)
    const primarySolid = cell.solidTop || cell.solidBase;
    if (primarySolid) {
      cell.decal = { spriteId: "fire_scorch_mark", tint: "#FFFFFF" };
      const isFlour = (cell.solidBase && (cell.solidBase.kind === "flour_smooth" || cell.solidBase.kind === "flour_single")) ||
                      primarySolid.flammable === "dust";
      if (isFlour) {
        cell.fire = {
          regime: "Aerosolized Dust Deflagration",
          spriteId: "fire_gas_smooth_violent",
          smoothGroup: "fire_gas",
          tint: "#FFFFFF",
        };
        cell.gas = {
          moles: 4.5,
          agitation: "stirred",
          tint: "#E8DEC8",
          name: "Aerosolized Flour Cloud",
          flammable: true,
          fireTint: null,
        };
      } else {
        const sid = primarySolid.kind === "pile_large" ? "fire_campfire_roaring" : "fire_campfire_steady";
        cell.fire = {
          regime: "Solid-Fuel Campfire Diffusion Flame",
          spriteId: sid,
          smoothGroup: null,
          tint: "#FFFFFF",
        };
        if (!cell.gas) {
          cell.gas = {
            moles: 1.8,
            agitation: "gentle",
            tint: "#787B85",
            name: "Wood / Coal Smoke",
            flammable: false,
            fireTint: null,
          };
        }
      }
      return true;
    }

    // Fallback: standalone steady flame on bare tile
    cell.decal = { spriteId: "fire_scorch_mark", tint: "#FFFFFF" };
    cell.fire = {
      regime: "Surface Diffusion Flame",
      spriteId: "fire_campfire_steady",
      smoothGroup: null,
      tint: "#FFFFFF",
    };
    return true;
  }

  // === COMPOSITE SCENARIOS ===
  function loadScenario(name) {
    resetGrid();
    state.gravity = "1g";
    state.bgMode = "plating";

    if (name === "campfire") {
      state.bgMode = "rock_floor";
      // Continuous smooth ash apron (solidBase) + stacked timber/kindling/coals on top (solidTop)
      depositSolid(4, 4, "flour_smooth", 1, "#5C5B61", "Wood Ash Apron", false);
      state.grid[4][4].decal = { spriteId: "fire_scorch_mark", tint: "#FFFFFF" };
      state.grid[4][4].solidTop = { kind: "pile_large", spriteId: "solid_pile_large", smoothGroup: null, tint: "#754E2F", name: "Stacked Dry Timber", flammable: "campfire" };
      state.grid[4][4].fire = { regime: "Roaring Bonfire (Solid Fuel)", spriteId: "fire_campfire_roaring", smoothGroup: null, tint: "#FFFFFF" };

      state.grid[4][2].decal = { spriteId: "fire_scorch_mark", tint: "#FFFFFF" };
      state.grid[4][2].solidTop = { kind: "pile_small", spriteId: "solid_pile_small", smoothGroup: null, tint: "#754E2F", name: "Kindling Pile", flammable: "campfire" };
      state.grid[4][2].fire = { regime: "Steady Campfire", spriteId: "fire_campfire_steady", smoothGroup: null, tint: "#FFFFFF" };

      state.grid[4][6].decal = { spriteId: "fire_scorch_mark", tint: "#FFFFFF" };
      state.grid[4][6].solidTop = { kind: "pile_small", spriteId: "solid_pile_small", smoothGroup: null, tint: "#333136", name: "Glowing Charcoal Bed", flammable: "campfire" };
      state.grid[4][6].fire = { regime: "Dying Coal Embers", spriteId: "fire_campfire_embers", smoothGroup: null, tint: "#FFFFFF" };

      state.grid[4][8].decal = { spriteId: "fire_scorch_mark", tint: "#FFFFFF" };
      state.grid[4][8].solidTop = { kind: "scattering", spriteId: "solid_scattering", smoothGroup: null, tint: "#48A878", name: "Copper Sulfate Pellets", flammable: "campfire" };
      state.grid[4][8].fire = { regime: "Copper-Tinted Salt Flame", spriteId: "fire_campfire_tintable", smoothGroup: null, tint: "#50FF78" };

      releaseGasPlume(4, 4, 24, "gentle", "#808490", "Campfire Smoke Plume", false, null);
      state.selectedX = 4; state.selectedY = 4;
      logPhysics("Scenario [Campfire]: Continuous wood-ash apron (`solidBase`) + fuel heaps (`solidTop`) over `fire_scorch_mark`, showing 4 solid-oxidation states: Roaring (x=4), Steady (x=2), Embers (x=6), and Copper-Green Tintable Flame (x=8) beneath gently rolling smoke.");
    } else if (name === "grease_fire") {
      state.bgMode = "floor";
      pourLiquidSpill(4, 4, 22500, 0.44, "#3D2E1E", "Heavy Hydrocarbon Grease / Oil", true);
      for (let y = 0; y < GRID_H; y++) {
        for (let x = 0; x < GRID_W; x++) {
          const liq = state.grid[y][x].liquid;
          if (liq && liq.volumeMl >= TH_LIQUID.puddle_min) {
            state.grid[y][x].decal = { spriteId: "fire_scorch_mark", tint: "#FFFFFF" };
            state.grid[y][x].fire = {
              regime: "Evaporative Oil/Grease Pool Fire (O2 Rim + Soot Core)",
              spriteId: "fire_grease_smooth",
              smoothGroup: "fire_grease",
              tint: "#FFFFFF",
            };
          }
        }
      }
      releaseGasPlume(4, 4, 54, "gentle", "#52555E", "Incomplete Combustion Soot Plume", false, null);
      state.selectedX = 4; state.selectedY = 4;
      logPhysics("Scenario [Liquid Oil / Grease Fire]: Multi-tile oil pool+puddle (`#3D2E1E`) burning with `fire_grease_smooth` (bright O2-fed perimeter rim + soot-tipped interior) beneath a 3-tier soot plume (`mist -> smoke -> cloud` nested shells).");
    } else if (name === "smoke_gradient") {
      state.bgMode = "plating";
      releaseGasPlume(2, 4, 92, "gentle", "#DCEEFF", "Billowing Steam / Vapor Plume", false, null);
      releaseGasPlume(7, 3, 86, "stirred", "#78808C", "Turbulent Exhaust Smoke", false, null);
      state.selectedX = 2; state.selectedY = 4;
      logPhysics("Scenario [Billowing Gas & Smoke Density Gradient]: Two distinct plumes (`#DCEEFF` steam & `#78808C` smoke), each seamlessly blending `mist` (>=0.35 mol) -> `smoke` (>=2.5 mol) -> `dense cloud` (>=8.0 mol) via Nested Contour Shells and 8-frame rolling advection.");
    } else if (name === "gas_oxidation") {
      state.bgMode = "plating";
      for (let x = 2; x <= 7; x++) {
        state.grid[1][x].wall = true;
        state.grid[6][x].wall = true;
      }
      releaseGasPlume(4, 3, 110, "stirred", "#E6AC55", "Pressurized Hydrocarbon Vapor", true, null);
      for (let y = 0; y < GRID_H; y++) {
        for (let x = 0; x < GRID_W; x++) {
          const g = state.grid[y][x].gas;
          if (g && g.moles >= 3.0) {
            state.grid[y][x].fire = {
              regime: "Violent Premixed Gas Deflagration",
              spriteId: "fire_gas_smooth_violent",
              smoothGroup: "fire_gas",
              tint: "#FFFFFF",
            };
          }
        }
      }
      state.selectedX = 4; state.selectedY = 3;
      logPhysics("Scenario [Violent Gas Cloud Oxidation]: Rapidly stirred combustible gas cloud (`cloud -> smoke -> mist` shells) violently oxidizing (`fire_gas_smooth_violent`) inside a station corridor.");
    } else if (name === "plasma_firestorm") {
      state.bgMode = "reinforced_floor";
      releaseGasPlume(5, 4, 125, "stirred", "#D95BFF", "Superheated Plasma Cloud", true, "#EE78FF");
      for (let y = 0; y < GRID_H; y++) {
        for (let x = 0; x < GRID_W; x++) {
          const g = state.grid[y][x].gas;
          if (g && g.moles >= 3.2) {
            state.grid[y][x].fire = {
              regime: "Tintable Plasma Deflagration",
              spriteId: "fire_gas_smooth_tintable",
              smoothGroup: "fire_gas_tint",
              tint: "#EE78FF",
            };
          }
        }
      }
      depositSolid(5, 4, "shards_large", 0, "#D452FF", "Shattered Solid Plasma Crystal", "campfire");
      state.selectedX = 5; state.selectedY = 4;
      logPhysics("Scenario [Plasma Cloud Deflagration]: Demonstrates neutral-greyscale `fire_gas_smooth_tintable` multiplied by `#EE78FF` over a 3-tier `#D95BFF` plasma cloud + shattered plasma crystal shards.");
    } else if (name === "spill_balance") {
      state.bgMode = "floor";
      state.grid[2][6].wall = true;
      state.grid[3][6].wall = true;
      state.grid[4][6].wall = true;
      pourLiquidSpill(4, 3, 27500, 0.56, "#4BA3E3", "Clean Water", false);
      state.selectedX = 4; state.selectedY = 3;
      logPhysics("Scenario [Balanced Large Spill (1g)]: 27,500 mL water breach balancing out around a bulkhead wall: ankle-deep `liquid_pool_smooth_ripple` core (>=2200 mL) -> unbroken `liquid_puddle_smooth_shimmer` apron (>=260 mL) -> peripheral `spill`, `splash`, and `splatter` droplets.");
    } else if (name === "zerog_cabin") {
      state.gravity = "0g";
      state.bgMode = "plating";
      pourLiquidSpill(2, 3, 11500, 0.45, "#4BA3E3", "Coolant Water (0g)", false);
      pourLiquidSpill(7, 5, 6500, 0.38, "#A3121A", "Venous Blood (0g)", false);
      releaseGasPlume(5, 2, 16, "still", "#CFEAFF", "Frozen Cabin Vapor Mist", false, null);
      state.selectedX = 2; state.selectedY = 3;
      logPhysics("Scenario [Zero-G Cabin Leak (0g)]: Non-destructive multi-substance microgravity cabin: blue `#4BA3E3` Coolant Water spheres around (2,3) and crimson `#A3121A` Venous Blood spheres around (7,5) across `large`, `mixed`, and `small` 0g droplets alongside frozen mist.");
    } else if (name === "flour_mill") {
      state.bgMode = "floor";
      depositSolid(4, 4, "flour_smooth", 2, "#F5F0E1", "Spilled Wheat Flour", "dust");
      state.grid[4][4].solidTop = { kind: "pile_large", spriteId: "solid_pile_large", smoothGroup: null, tint: "#F5F0E1", name: "Ruptured Flour Sack Heap", flammable: "dust" };
      state.grid[2][2].solidTop = { kind: "sprinkles", spriteId: "solid_sprinkles", smoothGroup: null, tint: "#F5F0E1", name: "Flour Sprinkles", flammable: "dust" };
      state.grid[6][5].solidTop = { kind: "sprinkles", spriteId: "solid_sprinkles", smoothGroup: null, tint: "#F5F0E1", name: "Flour Sprinkles", flammable: "dust" };
      releaseGasPlume(4, 4, 12, "gentle", "#F5F0E1", "Suspended Flour Dust", true, null);
      state.selectedX = 4; state.selectedY = 4;
      logPhysics("Scenario [Spilled Flour Dusting]: Continuous smooth flour sheet (`solidBase`) with central faceted heap (`solidTop` — no hole in sheet!), peripheral `solid_sprinkles`, and suspended dust mist. Click 'Ignite All Fuels' to trigger a dust deflagration!");
    } else if (name === "tunnel_debris") {
      state.bgMode = "rock_floor";
      for (let x = 0; x < GRID_W; x++) {
        state.grid[1][x].wall = true;
        state.grid[6][x].wall = true;
      }
      depositSolid(3, 3, "debris_smooth", 2, "#8E867D", "Jagged Tunnel Rubble", false);
      depositSolid(6, 4, "debris_smooth", 1, "#8E867D", "Jagged Tunnel Rubble", false);
      state.grid[3][2].solidTop = { kind: "shards_large", spriteId: "solid_shards_large", smoothGroup: null, tint: "#B8DCED", name: "Fractured Quartz Shards", flammable: false };
      state.grid[5][5].solidTop = { kind: "scattering", spriteId: "solid_scattering", smoothGroup: null, tint: "#C86D3B", name: "Native Copper Ore Scattering", flammable: false };
      releaseGasPlume(5, 3, 14, "still", "#78C868", "Stagnant Tunnel Miasma", false, null);
      state.selectedX = 4; state.selectedY = 3;
      logPhysics("Scenario [Jagged Tunnel Debris]: Smooth multi-tile angular rubble (`solid_debris_jagged_smooth`) layering a mined rock corridor alongside sharp `solid_shards_large`, chiseled `solid_scattering`, and stagnant miasma mist.");
    } else if (name === "farm_plot") {
      state.bgMode = "plating";
      for (let y = 2; y <= 5; y++) {
        for (let x = 1; x <= 4; x++) {
          state.grid[y][x].solidBase = {
            kind: "soil_tilled",
            spriteId: "solid_soil_tilled_smooth",
            smoothGroup: "soil_tilled_dry",
            tint: "#7D5838",
            name: "Tilled Loam (Dry)",
            flammable: false,
          };
        }
        for (let x = 5; x <= 8; x++) {
          state.grid[y][x].solidBase = {
            kind: "soil_tilled",
            spriteId: "solid_soil_tilled_smooth",
            smoothGroup: "soil_tilled_wet",
            tint: "#4A321F",
            name: "Tilled Loam (Irrigated)",
            flammable: false,
          };
        }
      }
      state.grid[3][6].liquid = { volumeMl: 950, tint: "#4BA3E3", name: "Irrigation Water", flammable: false, variant: 0 };
      state.grid[4][6].liquid = { volumeMl: 950, tint: "#4BA3E3", name: "Irrigation Water", flammable: false, variant: 1 };
      state.grid[6][3].solidBase = { kind: "soil_smooth", spriteId: "solid_soil_smooth", smoothGroup: "soil", tint: "#7D5838", name: "Spilled Potting Soil", flammable: false };
      state.grid[6][4].solidBase = { kind: "soil_smooth", spriteId: "solid_soil_smooth", smoothGroup: "soil", tint: "#7D5838", name: "Spilled Potting Soil", flammable: false };
      state.grid[6][2].solidTop = { kind: "sprinkles", spriteId: "solid_sprinkles", smoothGroup: null, tint: "#D5F0B8", name: "Nitrate Fertilizer Granules", flammable: false };
      state.selectedX = 5; state.selectedY = 3;
      logPhysics("Scenario [Tilled Farm Plot]: Side-by-side comparison of dry (`#7D5838`) vs irrigated (`#4A321F`) east-west furrowed `solid_soil_tilled_smooth` beds, uncultivated `solid_soil_smooth` spill, irrigation puddle, and crystalline fertilizer granules.");
    }

    document.getElementById("env-gravity").value = state.gravity;
    document.getElementById("env-bg").value = state.bgMode;
    updateInspector();
  }

  // === RENDER SANDBOX ===
  function renderSandbox() {
    const cv = document.getElementById("sandbox-canvas");
    const tilePx = 32 * state.scale;
    const targetW = GRID_W * tilePx;
    const targetH = GRID_H * tilePx;
    if (cv.width !== targetW || cv.height !== targetH) {
      cv.width = targetW;
      cv.height = targetH;
    }
    const ctx = cv.getContext("2d");
    ctx.imageSmoothingEnabled = false;

    const visGround = document.getElementById("vis-ground").checked;
    const visDecal = document.getElementById("vis-decal").checked;
    const visSolid = document.getElementById("vis-solid").checked;
    const visLiquid = document.getElementById("vis-liquid").checked;
    const visFire = document.getElementById("vis-fire").checked;
    const visGas = document.getElementById("vis-gas").checked;
    const visGrid = document.getElementById("vis-grid").checked;
    const visJunctions = document.getElementById("vis-junctions").checked;
    const visQuadrants = document.getElementById("vis-quadrants").checked;

    for (let y = 0; y < GRID_H; y++) {
      for (let x = 0; x < GRID_W; x++) {
        const dx = x * tilePx;
        const dy = y * tilePx;
        const cell = state.grid[y][x];

        if (visGround) {
          drawBackgroundTile(ctx, state.bgMode, dx, dy, tilePx);
        } else {
          ctx.fillStyle = "#11141d";
          ctx.fillRect(dx, dy, tilePx, tilePx);
        }

        if (cell.wall) {
          drawBackgroundTile(ctx, "wall", dx, dy, tilePx);
          continue;
        }

        let topJunction = null;
        if (visDecal && cell.decal) {
          drawSpriteTile(ctx, cell.decal.spriteId, cell.decal.tint, null, dx, dy, tilePx, state.clockMs);
        }
        if (visSolid && (cell.solidBase || cell.solidTop)) {
          for (const d of resolveSolidDraws(x, y)) {
            drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, dx, dy, tilePx, state.clockMs);
            if (d.junction !== null) topJunction = d.junction;
          }
        }
        if (visLiquid && cell.liquid) {
          for (const d of resolveLiquidDraws(x, y)) {
            drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, dx, dy, tilePx, state.clockMs);
            if (d.junction !== null) topJunction = d.junction;
          }
        }
        const gasUnderFire = !!(cell.gas && cell.gas.flammable && cell.fire);
        if (gasUnderFire && visGas && cell.gas) {
          for (const d of resolveGasDraws(x, y)) {
            drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, dx, dy, tilePx, state.clockMs);
            if (d.junction !== null) topJunction = d.junction;
          }
        }
        if (visFire && cell.fire) {
          for (const d of resolveFireDraws(x, y)) {
            drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, dx, dy, tilePx, state.clockMs);
            if (d.junction !== null) topJunction = d.junction;
          }
        }
        if (!gasUnderFire && visGas && cell.gas) {
          for (const d of resolveGasDraws(x, y)) {
            drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, dx, dy, tilePx, state.clockMs);
            if (d.junction !== null) topJunction = d.junction;
          }
        }

        if (visQuadrants) {
          ctx.strokeStyle = "rgba(86, 180, 255, 0.28)";
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(dx + tilePx / 2 + 0.5, dy);
          ctx.lineTo(dx + tilePx / 2 + 0.5, dy + tilePx);
          ctx.moveTo(dx, dy + tilePx / 2 + 0.5);
          ctx.lineTo(dx + tilePx, dy + tilePx / 2 + 0.5);
          ctx.stroke();
        }

        if (visJunctions && topJunction !== null) {
          ctx.fillStyle = "rgba(12, 16, 24, 0.78)";
          ctx.fillRect(dx + 2, dy + 2, 34, 14);
          ctx.fillStyle = "#8cd6fd";
          ctx.font = "10px monospace";
          ctx.fillText(`j=${topJunction}`, dx + 4, dy + 12);
        }
      }
    }

    if (visGrid) {
      ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
      ctx.lineWidth = 1;
      for (let x = 0; x <= GRID_W; x++) {
        ctx.beginPath();
        ctx.moveTo(x * tilePx + 0.5, 0);
        ctx.lineTo(x * tilePx + 0.5, targetH);
        ctx.stroke();
      }
      for (let y = 0; y <= GRID_H; y++) {
        ctx.beginPath();
        ctx.moveTo(0, y * tilePx + 0.5);
        ctx.lineTo(targetW, y * tilePx + 0.5);
        ctx.stroke();
      }
    }

    // Highlight selected tile
    ctx.strokeStyle = "#56b4ff";
    ctx.lineWidth = 2;
    ctx.strokeRect(state.selectedX * tilePx + 1, state.selectedY * tilePx + 1, tilePx - 2, tilePx - 2);

    renderInspectedTilePreview();
  }

  function renderInspectedTilePreview() {
    const cv = document.getElementById("insp-tile-canvas");
    const ctx = cv.getContext("2d");
    const x = state.selectedX, y = state.selectedY;
    const size = 128;
    ctx.imageSmoothingEnabled = false;
    drawBackgroundTile(ctx, state.bgMode, 0, 0, size);
    const cell = state.grid[y][x];
    if (cell.wall) {
      drawBackgroundTile(ctx, "wall", 0, 0, size);
      return;
    }
    if (cell.decal) drawSpriteTile(ctx, cell.decal.spriteId, cell.decal.tint, null, 0, 0, size, state.clockMs);
    for (const d of resolveSolidDraws(x, y)) drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, 0, 0, size, state.clockMs);
    for (const d of resolveLiquidDraws(x, y)) drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, 0, 0, size, state.clockMs);
    const gasUnderFire = !!(cell.gas && cell.gas.flammable && cell.fire);
    if (gasUnderFire) {
      for (const d of resolveGasDraws(x, y)) drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, 0, 0, size, state.clockMs);
    }
    for (const d of resolveFireDraws(x, y)) drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, 0, 0, size, state.clockMs);
    if (!gasUnderFire) {
      for (const d of resolveGasDraws(x, y)) drawSpriteTile(ctx, d.spriteId, d.tint, d.junction, 0, 0, size, state.clockMs);
    }

    // Draw subtle 16x16 quadrant crosshair
    ctx.strokeStyle = "rgba(86, 180, 255, 0.35)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(64.5, 0); ctx.lineTo(64.5, 128);
    ctx.moveTo(0, 64.5); ctx.lineTo(128, 64.5);
    ctx.stroke();
  }

  function updateInspector() {
    const x = state.selectedX, y = state.selectedY;
    document.getElementById("insp-coords").textContent = `(x=${x}, y=${y})`;
    const cell = state.grid[y][x];
    const tbody = document.querySelector("#insp-layers-table tbody");
    tbody.innerHTML = "";

    const addLayerRow = (layerName, spriteId, tint, junction) => {
      const sp = SPRITE_MAP.get(spriteId);
      const fIdx = sp ? frameIndexForSprite(sp, state.clockMs) + 1 : 1;
      const fTot = sp ? sp.frame_count : 1;
      const tr = document.createElement("tr");
      const jText = junction !== null ? ` [j=${junction}]` : "";
      const modeText = sp && sp.colorable ? `multiply ${tint}` : "authored .gpl";
      tr.innerHTML =
        `<td>${layerName}</td>` +
        `<td>${spriteId}${jText}<br/><span class="small">f${fIdx}/${fTot}</span></td>` +
        `<td><span class="swatch-chip" style="background:${tint};"></span>${modeText}</td>`;
      tbody.appendChild(tr);
    };

    addLayerRow("0:Turf", state.bgMode, "#FFFFFF", null);
    if (cell.wall) {
      addLayerRow("1:Fixture", "wall (bulkhead)", "#FFFFFF", null);
    } else {
      if (cell.decal) addLayerRow("1:Scorch", cell.decal.spriteId, cell.decal.tint, null);
      const sDraws = resolveSolidDraws(x, y);
      for (const d of sDraws) addLayerRow("2:Solid", d.spriteId, d.tint, d.junction);
      const lDraws = resolveLiquidDraws(x, y);
      for (const d of lDraws) addLayerRow("3:Liquid", d.spriteId, d.tint, d.junction);
      const fDraws = resolveFireDraws(x, y);
      const gDraws = resolveGasDraws(x, y);
      const gasUnderFire = !!(cell.gas && cell.gas.flammable && cell.fire);
      if (gasUnderFire) {
        for (const d of gDraws) addLayerRow("4:Gas (Fuel)", d.spriteId, d.tint, d.junction);
        for (const d of fDraws) addLayerRow("5:Fire", d.spriteId, d.tint, d.junction);
      } else {
        for (const d of fDraws) addLayerRow("4:Fire", d.spriteId, d.tint, d.junction);
        for (const d of gDraws) addLayerRow("5:Gas", d.spriteId, d.tint, d.junction);
      }

      // Find top-most smooth layer in true compositing order to explain its 47-junction cut
      const orderedDraws = gasUnderFire
        ? [...sDraws, ...lDraws, ...gDraws, ...fDraws]
        : [...sDraws, ...lDraws, ...fDraws, ...gDraws];
      const allSmooth = orderedDraws.filter((d) => d.junction !== null);
      const jBox = document.getElementById("insp-junction-box");
      if (allSmooth.length > 0) {
        const top = allSmooth[allSmooth.length - 1];
        const j = top.junction;
        const jIdx = JUNCTION_INDEX.get(j);
        const quads = quadrantBlocksForJunction(j);
        jBox.innerHTML =
          `<div><strong>${top.spriteId}</strong> &rarr; junction=<strong>${j}</strong> (atlas index ${jIdx}/46)</div>` +
          `<div style="margin-top:4px;">` +
          quads.map((q) => `${q.label}: <strong>${q.blockName}</strong> (v=${+q.v},h=${+q.h},d=${+q.d})`).join("<br/>") +
          `</div>`;
      } else {
        jBox.textContent = "No 47-junction smooth layer on this tile (single-tile sprites only).";
      }
    }

    // Physics & Engine Color Math table
    const pBody = document.querySelector("#insp-physics-table tbody");
    pBody.innerHTML = "";
    const addPhys = (k, v) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `<th>${k}</th><td>${v}</td>`;
      pBody.appendChild(tr);
    };
    addPhys("Gravity Regime", state.gravity === "1g" ? "1g Deck (hydrostatic spreading)" : "0g Microgravity (Laplace spheres)");
    if (cell.liquid) {
      const depthMm = (cell.liquid.volumeMl / 1000).toFixed(2);
      const [r, g, b] = parseHexRgb(cell.liquid.tint);
      addPhys("Liquid State", `${cell.liquid.name}: ${cell.liquid.volumeMl} mL (${depthMm} mm film on 1m² tile)`);
      addPhys("sRGB Multiply", `tint (${r},${g},${b}) * greyscale #D9D9D9(217) -> (${((217*r+127)/255)|0}, ${((217*g+127)/255)|0}, ${((217*b+127)/255)|0})`);
    }
    if (cell.solidBase || cell.solidTop) {
      const parts = [];
      if (cell.solidBase) parts.push(`${cell.solidBase.name} [${cell.solidBase.kind}]`);
      if (cell.solidTop) parts.push(`${cell.solidTop.name} [${cell.solidTop.kind}]`);
      addPhys("Solid State", parts.join(" + "));
    }
    if (cell.gas) {
      addPhys("Gas State", `${cell.gas.name}: ${cell.gas.moles} mol, agitation=${cell.gas.agitation}`);
    }
    if (cell.fire) {
      addPhys("Oxidation Regime", cell.fire.regime);
    }
  }

  // === TAB 2: 47-JUNCTION SLICER ===
  function initSlicerTab() {
    const sel = document.getElementById("slicer-asset-select");
    const smoothSprites = DATA.sprites.filter((s) => s.kind === "smooth_strip");
    sel.innerHTML = "";
    for (const sp of smoothSprites) {
      const opt = document.createElement("option");
      opt.value = sp.id;
      opt.textContent = `[${sp.element}] ${sp.id}`;
      sel.appendChild(opt);
    }
    state.slicerAssetId = smoothSprites.length ? smoothSprites[0].id : "";

    sel.addEventListener("change", () => {
      state.slicerAssetId = sel.value;
      const sp = SPRITE_MAP.get(state.slicerAssetId);
      if (sp && sp.sample_tints && sp.sample_tints.length) {
        state.slicerTint = sp.sample_tints[0].hex;
        document.getElementById("slicer-tint-picker").value = state.slicerTint.toLowerCase();
      }
      renderSlicerTab();
    });

    document.getElementById("slicer-tint-picker").addEventListener("input", (e) => {
      state.slicerTint = e.target.value.toUpperCase();
      renderSlicerTab();
    });

    document.getElementById("slicer-reset-tint").addEventListener("click", () => {
      state.slicerTint = "#FFFFFF";
      document.getElementById("slicer-tint-picker").value = "#ffffff";
      renderSlicerTab();
    });

    document.getElementById("slicer-bg-select").addEventListener("change", (e) => {
      state.slicerBg = e.target.value;
      renderSlicerTab();
    });

    const padBtns = document.querySelectorAll("#slicer-neighbor-pad button[data-bit]");
    padBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        const bit = parseInt(btn.dataset.bit, 10);
        state.slicerNeighborMask ^= bit;
        btn.classList.toggle("active", !!(state.slicerNeighborMask & bit));
        renderSlicerTab();
      });
    });

    // Build 47-junction grid cells
    const grid47 = document.getElementById("slicer-47-grid");
    grid47.innerHTML = "";
    state.slicer47Canvases = [];
    for (let idx = 0; idx < JUNCTIONS.length; idx++) {
      const jVal = JUNCTIONS[idx];
      const cell = document.createElement("div");
      cell.className = "junction-cell";
      cell.dataset.junction = String(jVal);
      const cv = document.createElement("canvas");
      cv.className = "pixel";
      cv.width = 64;
      cv.height = 64;
      const lbl = document.createElement("div");
      lbl.textContent = `#${idx} j=${jVal}`;
      cell.appendChild(cv);
      cell.appendChild(lbl);
      cell.addEventListener("click", () => {
        state.slicerNeighborMask = jVal;
        padBtns.forEach((b) => {
          const bit = parseInt(b.dataset.bit, 10);
          b.classList.toggle("active", !!(jVal & bit));
        });
        renderSlicerTab();
      });
      grid47.appendChild(cell);
      state.slicer47Canvases.push({ jVal, cv, cell });
    }
  }

  function renderSlicerTab() {
    const sp = SPRITE_MAP.get(state.slicerAssetId);
    if (!sp) return;
    const fIdx = frameIndexForSprite(sp, state.clockMs);

    // 1. Source 5-block strip
    const stripCv = document.getElementById("slicer-strip-canvas");
    const sCtx = stripCv.getContext("2d");
    sCtx.imageSmoothingEnabled = false;
    for (let b = 0; b < 5; b++) {
      drawBackgroundTile(sCtx, state.slicerBg, b * 96, 0, 96);
    }
    const stripSheet = getTintedSheet(sp.strip_data_uri, state.slicerTint, sp.colorable);
    if (stripSheet) {
      sCtx.drawImage(stripSheet, fIdx * 160, 0, 160, 32, 0, 0, 480, 96);
    }
    // Block & quadrant guide lines
    for (let b = 0; b < 5; b++) {
      sCtx.strokeStyle = "rgba(255,255,255,0.45)";
      sCtx.strokeRect(b * 96 + 0.5, 0.5, 95, 95);
      sCtx.strokeStyle = "rgba(86,180,255,0.35)";
      sCtx.beginPath();
      sCtx.moveTo(b * 96 + 48.5, 0); sCtx.lineTo(b * 96 + 48.5, 96);
      sCtx.moveTo(b * 96, 48.5); sCtx.lineTo(b * 96 + 96, 48.5);
      sCtx.stroke();
    }

    // 2. Assembled result tile
    const cleanJ = sanitizeDiagonalMask(state.slicerNeighborMask);
    const resCv = document.getElementById("slicer-result-canvas");
    const rCtx = resCv.getContext("2d");
    rCtx.imageSmoothingEnabled = false;
    drawBackgroundTile(rCtx, state.slicerBg, 0, 0, 128);
    drawSpriteTile(rCtx, sp.id, state.slicerTint, cleanJ, 0, 0, 128, state.clockMs);
    rCtx.strokeStyle = "rgba(86,180,255,0.45)";
    rCtx.beginPath();
    rCtx.moveTo(64.5, 0); rCtx.lineTo(64.5, 128);
    rCtx.moveTo(0, 64.5); rCtx.lineTo(128, 64.5);
    rCtx.stroke();

    const quads = quadrantBlocksForJunction(cleanJ);
    document.getElementById("slicer-formula-readout").innerHTML =
      `Raw 8-neighbor mask: <strong>${state.slicerNeighborMask}</strong><br/>` +
      `Diagonal-gated canonical junction: <strong>${cleanJ}</strong> (index ${JUNCTION_INDEX.get(cleanJ)}/46)<br/><br/>` +
      quads.map((q) => `${q.label} &larr; <strong>${q.blockName}</strong>`).join("<br/>");

    // 3. All 47 junction cells
    for (const item of state.slicer47Canvases) {
      const cCtx = item.cv.getContext("2d");
      cCtx.imageSmoothingEnabled = false;
      drawBackgroundTile(cCtx, state.slicerBg, 0, 0, 64);
      drawSpriteTile(cCtx, sp.id, state.slicerTint, item.jVal, 0, 0, 64, state.clockMs);
      item.cell.classList.toggle("selected", item.jVal === cleanJ);
    }
  }

  // === TAB 3: COMPLETE ASSET CATALOG ===
  function rebuildCatalogCards() {
    const domFilter = document.getElementById("cat-filter-domain").value;
    const kindFilter = document.getElementById("cat-filter-kind").value;
    const container = document.getElementById("catalog-cards");
    container.innerHTML = "";
    state.catalogLiveCanvases = [];

    const patch3x3 = [
      [38, 110, 74],
      [55, 255, 203],
      [21, 157, 137],
    ];

    for (const sp of DATA.sprites) {
      if (domFilter !== "all" && sp.element !== domFilter) continue;
      if (kindFilter !== "all" && sp.kind !== kindFilter) continue;

      const card = document.createElement("div");
      card.className = "asset-card";

      const defaultSampleHex =
        sp.sample_tints && sp.sample_tints.length ? sp.sample_tints[0].hex : sp.default_tint || "#FFFFFF";

      const head = document.createElement("div");
      head.className = "asset-card-head";
      head.innerHTML =
        `<div><strong class="mono">${sp.id}</strong><div class="small">${sp.title || ""}</div></div>` +
        `<div style="display:flex;gap:4px;">` +
        `<span class="tag info">${sp.kind === "smooth_strip" ? "160x32 -> 47" : "32x32"}</span>` +
        `<span class="tag ${sp.telemetry.passes_bare_mask_gate ? "ok" : "fire"}">domRGB ${(sp.telemetry.dominant_rgb_share * 100).toFixed(0)}%</span>` +
        `</div>`;
      card.appendChild(head);

      const prevRow = document.createElement("div");
      prevRow.className = "asset-previews";

      const singleCv = document.createElement("canvas");
      singleCv.className = "pixel";
      singleCv.width = 96;
      singleCv.height = 96;
      prevRow.appendChild(singleCv);

      let patchCv = null;
      if (sp.kind === "smooth_strip") {
        patchCv = document.createElement("canvas");
        patchCv.className = "pixel";
        patchCv.width = 96;
        patchCv.height = 96;
        prevRow.appendChild(patchCv);
      }

      const metaDiv = document.createElement("div");
      metaDiv.className = "mono small";
      const tel = sp.telemetry;
      const seamNote = sp.junction_telemetry
        ? `<br/>j255 domRGB: ${(sp.junction_telemetry.j255_interior.dominant_rgb_share * 100).toFixed(0)}% | seam MAE H:${sp.junction_telemetry.j255_edge_alpha_mae_h} V:${sp.junction_telemetry.j255_edge_alpha_mae_v}`
        : "";
      metaDiv.innerHTML =
        `frames: ${sp.frame_count} (${sp.durations_ms[0]}ms) | colorable: ${sp.colorable}<br/>` +
        `px: ${tel.active_px} | alpha: ${tel.alpha.min}/${tel.alpha.avg}/${tel.alpha.max}<br/>` +
        `luma: ${tel.luma.min}/${tel.luma.avg}/${tel.luma.max} (T:${tel.luma.top} B:${tel.luma.bottom})` +
        seamNote;
      prevRow.appendChild(metaDiv);
      card.appendChild(prevRow);

      if (sp.description) {
        const desc = document.createElement("div");
        desc.className = "small";
        desc.textContent = sp.description;
        card.appendChild(desc);
      }

      const pathLine = document.createElement("div");
      pathLine.className = "mono small";
      pathLine.style.fontSize = "10px";
      pathLine.textContent = sp.ase_relpath;
      card.appendChild(pathLine);

      container.appendChild(card);
      state.catalogLiveCanvases.push({ sp, singleCv, patchCv, sampleHex: defaultSampleHex, patch3x3 });
    }
  }

  function renderCatalogLive() {
    const bgMode = document.getElementById("cat-bg-mode").value;
    const useTint = document.getElementById("cat-use-tint").checked;
    for (const item of state.catalogLiveCanvases) {
      const { sp, singleCv, patchCv, sampleHex, patch3x3 } = item;
      const tint = useTint && sp.colorable ? sampleHex : "#FFFFFF";
      const ctx = singleCv.getContext("2d");
      ctx.imageSmoothingEnabled = false;
      drawBackgroundTile(ctx, bgMode, 0, 0, 96);
      drawSpriteTile(ctx, sp.id, tint, 0, 0, 0, 96, state.clockMs);

      if (patchCv) {
        const pCtx = patchCv.getContext("2d");
        pCtx.imageSmoothingEnabled = false;
        for (let gy = 0; gy < 3; gy++) {
          for (let gx = 0; gx < 3; gx++) {
            drawBackgroundTile(pCtx, bgMode, gx * 32, gy * 32, 32);
            drawSpriteTile(pCtx, sp.id, tint, patch3x3[gy][gx], gx * 32, gy * 32, 32, state.clockMs);
          }
        }
      }
    }
  }

  // === TAB 4: SOLID MORPHOLOGY & SUBSTANCE MATRIX ===
  function buildSubstancesTable() {
    const tbody = document.querySelector("#substances-table tbody");
    tbody.innerHTML = "";
    for (const sub of DATA.solid_substances) {
      const tr = document.createElement("tr");
      const cv = document.createElement("canvas");
      cv.className = "pixel";
      cv.width = 64;
      cv.height = 64;
      const ctx = cv.getContext("2d");
      ctx.imageSmoothingEnabled = false;
      drawBackgroundTile(ctx, "plating", 0, 0, 64);
      drawSpriteTile(ctx, sub.sprite, sub.hex, 0, 0, 0, 64, 0);

      tr.innerHTML =
        `<td><strong>${sub.name}</strong></td>` +
        `<td><span class="swatch-chip" style="background:${sub.hex};"></span>${sub.hex}</td>` +
        `<td><span class="tag">${sub.morphology}</span></td>` +
        `<td>${sub.sprite}</td>` +
        `<td class="sub-cv-slot"></td>` +
        `<td>${sub.notes}</td>` +
        `<td><button class="sub-try-btn">Test in Sandbox</button></td>`;
      tr.querySelector(".sub-cv-slot").appendChild(cv);
      tr.querySelector(".sub-try-btn").addEventListener("click", () => {
        setActiveTint(sub.hex, sub.name, false, null);
        document.getElementById("tool-mode").value = "dump_solid";
        updateToolParamVisibility();
        const kindMap = {
          solid_dusting_flour_smooth: "flour_smooth",
          solid_dusting_flour_single: "flour_single",
          solid_debris_jagged_smooth: "debris_smooth",
          solid_debris_jagged_single: "debris_single",
          solid_soil_smooth: "soil_smooth",
          solid_soil_patch_single: "soil_single",
          solid_soil_tilled_smooth: "soil_tilled",
          solid_pile_large: "pile_large",
          solid_pile_small: "pile_small",
          solid_sprinkles: "sprinkles",
          solid_scattering: "scattering",
          solid_shards_large: "shards_large",
          solid_shards_small: "shards_small",
        };
        const chosenKind = kindMap[sub.sprite] || "flour_smooth";
        const chosenRad = chosenKind.endsWith("_single") ? 0 : 1;
        document.getElementById("solid-kind").value = chosenKind;
        document.getElementById("solid-radius").value = String(chosenRad);
        document.getElementById("solid-radius-val").textContent = `r=${chosenRad}`;
        switchTab("sandbox");
        depositSolid(state.selectedX, state.selectedY, chosenKind, chosenRad, sub.hex, sub.name, false);
        updateInspector();
      });
      tbody.appendChild(tr);
    }
  }

  // === UI WIRING ===
  function setActiveTint(hex, name, flammable, fireTint) {
    state.activeTint = normalizeHex(hex);
    if (name) state.activeSubstanceName = name;
    state.activeFlammable = flammable || false;
    state.activeFireTint = fireTint || null;
    document.getElementById("active-tint-color").value = state.activeTint.toLowerCase();
    document.getElementById("active-tint-hex").value = state.activeTint;
  }

  function buildPresetPills(containerId, items) {
    const el = document.getElementById(containerId);
    el.innerHTML = "";
    for (const item of items) {
      const b = document.createElement("button");
      b.innerHTML = `<span class="swatch-chip" style="background:${item.hex};"></span>${item.name}`;
      b.addEventListener("click", () => {
        setActiveTint(item.hex, item.name, item.flammable, item.fireTint);
      });
      el.appendChild(b);
    }
  }

  function updateToolParamVisibility() {
    const mode = document.getElementById("tool-mode").value;
    document.getElementById("tool-params-liquid").style.display = mode === "pour_liquid" ? "block" : "none";
    document.getElementById("tool-params-gas").style.display = mode === "release_gas" ? "block" : "none";
    document.getElementById("tool-params-solid").style.display = mode === "dump_solid" ? "block" : "none";
  }

  function switchTab(tabName) {
    document.querySelectorAll("#main-tabs button").forEach((b) => {
      b.classList.toggle("active", b.dataset.tab === tabName);
    });
    document.querySelectorAll(".tab-view").forEach((sec) => {
      sec.classList.toggle("active", sec.id === `tab-${tabName}`);
    });
    if (tabName === "slicer") renderSlicerTab();
    if (tabName === "catalog") renderCatalogLive();
  }

  function applyActiveToolAt(x, y) {
    state.selectedX = x;
    state.selectedY = y;
    const mode = document.getElementById("tool-mode").value;
    if (mode === "pour_liquid") {
      const vol = parseInt(document.getElementById("liq-volume").value, 10);
      const visc = parseFloat(document.getElementById("liq-viscosity").value);
      pourLiquidSpill(x, y, vol, visc, state.activeTint, state.activeSubstanceName, state.activeFlammable);
    } else if (mode === "release_gas") {
      const moles = parseFloat(document.getElementById("gas-moles").value);
      const ag = document.getElementById("gas-agitation").value;
      releaseGasPlume(x, y, moles, ag, state.activeTint, state.activeSubstanceName, state.activeFlammable, state.activeFireTint);
    } else if (mode === "dump_solid") {
      const kind = document.getElementById("solid-kind").value;
      const rad = parseInt(document.getElementById("solid-radius").value, 10);
      depositSolid(x, y, kind, rad, state.activeTint, state.activeSubstanceName, state.activeFlammable);
    } else if (mode === "ignite") {
      igniteCell(x, y);
      logPhysics(`[Ignition] Oxidized fuel at (${x},${y}).`);
    } else if (mode === "toggle_wall") {
      const cell = state.grid[y][x];
      const nextWall = !cell.wall;
      state.grid[y][x] = makeEmptyCell();
      state.grid[y][x].wall = nextWall;
      logPhysics(`[Bulkhead] Tile (${x},${y}) wall=${nextWall}.`);
    } else if (mode === "erase_tile") {
      state.grid[y][x] = makeEmptyCell();
      logPhysics(`[Erase] Cleared tile (${x},${y}).`);
    }
    updateInspector();
  }

  async function boot() {
    const uris = [];
    for (const sp of DATA.sprites) {
      if (sp.atlas_data_uri) uris.push(sp.atlas_data_uri);
      if (sp.strip_data_uri) uris.push(sp.strip_data_uri);
    }
    for (const k of Object.keys(DATA.turfs)) {
      uris.push(DATA.turfs[k].data_uri);
    }
    await Promise.all(uris.map(loadImg));

    const c = DATA.counts_by_domain;
    document.getElementById("header-summary").textContent =
      `${DATA.total_sprites} authored .aseprite assets (${c.gasses} gas, ${c.liquids} liquid, ${c.solids} solid, ${c.fire} fire) | tales-from-space.gpl | 47-junction BitmaskSlice`;

    buildPresetPills("liq-tint-pills", LIQUID_PRESETS);
    buildPresetPills("gas-tint-pills", GAS_PRESETS);
    buildPresetPills("solid-tint-pills", SOLID_PRESETS);

    // Tabs
    document.querySelectorAll("#main-tabs button").forEach((btn) => {
      btn.addEventListener("click", () => switchTab(btn.dataset.tab));
    });

    // Scenarios
    document.querySelectorAll("#scenario-buttons button").forEach((btn) => {
      btn.addEventListener("click", () => loadScenario(btn.dataset.scenario));
    });

    // Tool controls
    document.getElementById("tool-mode").addEventListener("change", () => {
      const mode = document.getElementById("tool-mode").value;
      updateToolParamVisibility();
      if (mode === "pour_liquid") setActiveTint(LIQUID_PRESETS[0].hex, LIQUID_PRESETS[0].name, LIQUID_PRESETS[0].flammable, null);
      if (mode === "release_gas") setActiveTint(GAS_PRESETS[0].hex, GAS_PRESETS[0].name, GAS_PRESETS[0].flammable, GAS_PRESETS[0].fireTint);
      if (mode === "dump_solid") setActiveTint(SOLID_PRESETS[0].hex, SOLID_PRESETS[0].name, SOLID_PRESETS[0].flammable, null);
    });

    document.getElementById("liq-volume").addEventListener("input", (e) => {
      document.getElementById("liq-volume-val").textContent = `${e.target.value} mL`;
    });
    document.getElementById("gas-moles").addEventListener("input", (e) => {
      document.getElementById("gas-moles-val").textContent = `${e.target.value} mol`;
    });
    document.getElementById("solid-radius").addEventListener("input", (e) => {
      document.getElementById("solid-radius-val").textContent = `r=${e.target.value}`;
    });

    document.getElementById("active-tint-color").addEventListener("input", (e) => {
      setActiveTint(e.target.value, "Custom Tint", state.activeFlammable, state.activeFireTint);
    });
    document.getElementById("active-tint-hex").addEventListener("change", (e) => {
      setActiveTint(e.target.value, "Custom Tint", state.activeFlammable, state.activeFireTint);
    });

    document.getElementById("btn-ignite-all").addEventListener("click", () => {
      let ignited = 0;
      for (let y = 0; y < GRID_H; y++) {
        for (let x = 0; x < GRID_W; x++) {
          const cell = state.grid[y][x];
          if (cell.liquid || cell.solidBase || cell.solidTop || (cell.gas && cell.gas.moles >= 2.5)) {
            if (igniteCell(x, y)) ignited++;
          }
        }
      }
      logPhysics(`[Global Ignition] Oxidized ${ignited} fuel-bearing tiles using regime-matched fire overlays.`);
      updateInspector();
    });

    document.getElementById("btn-extinguish").addEventListener("click", () => {
      for (let y = 0; y < GRID_H; y++) {
        for (let x = 0; x < GRID_W; x++) {
          state.grid[y][x].fire = null;
        }
      }
      logPhysics("[Extinguish] Removed active fire overlays; scorch marks & matter preserved.");
      updateInspector();
    });

    document.getElementById("btn-random-spill").addEventListener("click", () => {
      const lp = LIQUID_PRESETS[Math.floor(Math.random() * LIQUID_PRESETS.length)];
      const gp = GAS_PRESETS[Math.floor(Math.random() * GAS_PRESETS.length)];
      const rx = 2 + Math.floor(Math.random() * (GRID_W - 4));
      const ry = 2 + Math.floor(Math.random() * (GRID_H - 4));
      pourLiquidSpill(rx, ry, 5000 + Math.floor(Math.random() * 12000), 0.46, lp.hex, lp.name, lp.flammable);
      releaseGasPlume(rx, ry, 18 + Math.floor(Math.random() * 45), "gentle", gp.hex, gp.name, gp.flammable, gp.fireTint);
      state.selectedX = rx; state.selectedY = ry;
      updateInspector();
    });

    document.getElementById("btn-clear-grid").addEventListener("click", () => {
      resetGrid();
      logPhysics("[Clear] Reset 10x8 sandbox grid.");
      updateInspector();
    });

    // Environment & toolbar
    document.getElementById("env-gravity").addEventListener("change", (e) => {
      state.gravity = e.target.value;
      logPhysics(`[Gravity] Switched to ${state.gravity}: liquids re-evaluated between hydrostatic films and 0g Laplace spheres.`);
      updateInspector();
    });
    document.getElementById("env-bg").addEventListener("change", (e) => {
      state.bgMode = e.target.value;
      updateInspector();
    });
    document.getElementById("env-scale").addEventListener("change", (e) => {
      state.scale = parseInt(e.target.value, 10);
    });
    document.getElementById("env-speed").addEventListener("change", (e) => {
      state.animSpeed = parseFloat(e.target.value) || 1.0;
    });
    document.getElementById("btn-anim-toggle").addEventListener("click", (e) => {
      state.playing = !state.playing;
      e.target.textContent = state.playing ? "Playing" : "Paused";
      e.target.classList.toggle("active", state.playing);
    });
    document.getElementById("btn-anim-step").addEventListener("click", () => {
      state.playing = false;
      const btn = document.getElementById("btn-anim-toggle");
      btn.textContent = "Paused";
      btn.classList.remove("active");
      state.clockMs += 100;
      updateInspector();
      renderSandbox();
    });

    // Canvas mouse interaction
    const cv = document.getElementById("sandbox-canvas");
    const coordsFromEvent = (ev) => {
      const rect = cv.getBoundingClientRect();
      const sx = cv.width / rect.width;
      const sy = cv.height / rect.height;
      const tilePx = 32 * state.scale;
      const gx = Math.floor(((ev.clientX - rect.left) * sx) / tilePx);
      const gy = Math.floor(((ev.clientY - rect.top) * sy) / tilePx);
      return [Math.max(0, Math.min(GRID_W - 1, gx)), Math.max(0, Math.min(GRID_H - 1, gy))];
    };

    cv.addEventListener("click", (ev) => {
      const [gx, gy] = coordsFromEvent(ev);
      applyActiveToolAt(gx, gy);
    });
    cv.addEventListener("mousemove", (ev) => {
      const [gx, gy] = coordsFromEvent(ev);
      if (gx !== state.selectedX || gy !== state.selectedY) {
        state.selectedX = gx;
        state.selectedY = gy;
        updateInspector();
      }
    });

    // Tab 2, 3, 4 init
    initSlicerTab();
    document.getElementById("cat-filter-domain").addEventListener("change", rebuildCatalogCards);
    document.getElementById("cat-filter-kind").addEventListener("change", rebuildCatalogCards);
    rebuildCatalogCards();
    buildSubstancesTable();

    // Load default flagship composite scenario
    loadScenario("grease_fire");

    // Animation loop
    const tick = (ts) => {
      if (!state.lastRafTs) state.lastRafTs = ts;
      const dt = ts - state.lastRafTs;
      state.lastRafTs = ts;
      if (state.playing) {
        state.clockMs += Math.min(dt, 100) * state.animSpeed;
      }
      const activeTab = document.querySelector("#main-tabs button.active")?.dataset.tab;
      if (activeTab === "sandbox") renderSandbox();
      else if (activeTab === "slicer") renderSlicerTab();
      else if (activeTab === "catalog") renderCatalogLive();
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }

  boot().catch((err) => {
    console.error(err);
    document.getElementById("header-summary").textContent = "Boot error: " + err.message;
  });
})();
