/* Tales from Space — Terrestrial Art Workbench: Core State, 47-Junction Slicer, Tint Cache & Renderer */
(() => {
  "use strict";

  const DATA = window.WORKBENCH_DATA;
  if (!DATA) throw new Error("Missing window.WORKBENCH_DATA from workbench_data.js");

  const GRID_W = 14, GRID_H = 10, TILE_PX = 32;
  const NORTH = 1, SOUTH = 2, EAST = 4, WEST = 8, NE = 16, SE = 32, SW = 64, NW = 128;
  const JUNCTIONS = DATA.junctions;
  const J_INDEX = new Map(JUNCTIONS.map((j, idx) => [j, idx]));

  const PHASE_LABELS = [
    "F1: Surge In", "F2: Surge Mid", "F3: Surge High", "F4: Crest Approach",
    "F5: Peak Turnaround", "F6: Hover & Soak", "F7: Gentle Ebb", "F8: Backwash Sheet",
    "F9: Drain Mid", "F10: Shallows Roll", "F11: Trough Hover", "F12: Swell Gather",
  ];

  const PICKER_SPECS = [
    { key: "silicate", label: "Silicate / Soil" }, { key: "silicate_low", label: "Low Regolith / Sand" },
    { key: "ice", label: "Ice Sheet" }, { key: "cliff", label: "Stepped Cliff" },
    { key: "ocean", label: "Ocean Body" }, { key: "backwash", label: "Wet Backwash" },
    { key: "swash", label: "Swash / Lace" }, { key: "grass", label: "Grass Decal" },
    { key: "moss", label: "Moss Decal" }, { key: "haze", label: "Gas Haze" },
  ];

  const isSmoothKind = (kind) => kind === "smooth_strip";
  const isTerrestrialSource = (src) => src === "terrestrial";

  const TERRESTRIAL_ASSETS = DATA.terrestrial || [];
  const EXISTING_ASSETS = DATA.existing || [];
  const ALL_ASSETS = [...TERRESTRIAL_ASSETS, ...EXISTING_ASSETS];
  const ASSET_MAP = new Map(ALL_ASSETS.map((a) => [a.id, a]));
  const LOADED_IMAGES = new Map();
  const LOADED_STRIPS = new Map();
  const TINT_CELL_CACHE = new Map();
  const MAX_CACHE_ENTRIES = 2800;

  // =========================================================================
  // 47-Junction Bitmask Slicer & sRGB Multiply Tint Cache
  // =========================================================================
  function sanitizeMask(mask) {
    let out = mask & (NORTH | SOUTH | EAST | WEST);
    if ((mask & NW) && (mask & NORTH) && (mask & WEST)) out |= NW;
    if ((mask & NE) && (mask & NORTH) && (mask & EAST)) out |= NE;
    if ((mask & SE) && (mask & SOUTH) && (mask & EAST)) out |= SE;
    if ((mask & SW) && (mask & SOUTH) && (mask & WEST)) out |= SW;
    return out;
  }

  function computeJunction(pred, x, y, gw, gh, clampBorder = false, minX = 0, maxX = gw - 1) {
    const ok = (nx, ny) => {
      if (nx >= minX && nx <= maxX && ny >= 0 && ny < gh) return pred(nx, ny);
      if (!clampBorder) return false;
      return pred(Math.min(Math.max(nx, minX), maxX), Math.min(Math.max(ny, 0), gh - 1));
    };
    let mask = 0;
    if (ok(x, y - 1)) mask |= NORTH;
    if (ok(x, y + 1)) mask |= SOUTH;
    if (ok(x + 1, y)) mask |= EAST;
    if (ok(x - 1, y)) mask |= WEST;
    if (ok(x + 1, y - 1)) mask |= NE;
    if (ok(x + 1, y + 1)) mask |= SE;
    if (ok(x - 1, y + 1)) mask |= SW;
    if (ok(x - 1, y - 1)) mask |= NW;
    return sanitizeMask(mask);
  }

  function quadrantBlocks(junction) {
    const j = sanitizeMask(junction);
    const pick = (v, h, d) => (!v && !h ? 0 : v && !h ? 1 : !v && h ? 2 : !d ? 3 : 4);
    return {
      tl: pick(Boolean(j & NORTH), Boolean(j & WEST), Boolean(j & NW)),
      tr: pick(Boolean(j & NORTH), Boolean(j & EAST), Boolean(j & NE)),
      bl: pick(Boolean(j & SOUTH), Boolean(j & WEST), Boolean(j & SW)),
      br: pick(Boolean(j & SOUTH), Boolean(j & EAST), Boolean(j & SE)),
    };
  }

  function parseHexRgb(hex) {
    const h = (hex || "#FFFFFF").replace("#", "").trim();
    return h.length === 6 ? [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)] : [255, 255, 255];
  }

  function resolveAssetFrame(rec, globalFrame) {
    const fc = rec.frame_count || 1;
    if (fc <= 1) return 0;
    if (rec.rewind) {
      const cycleLen = fc * 2 - 2;
      const pos = globalFrame % cycleLen;
      return pos < fc ? pos : cycleLen - pos;
    }
    return globalFrame % fc;
  }

  function getTintedCell(assetId, junction, globalFrame, tintHex) {
    const rec = ASSET_MAP.get(assetId);
    const img = LOADED_IMAGES.get(assetId);
    if (!rec || !img) return null;

    const smooth = isSmoothKind(rec.kind);
    const fIdx = resolveAssetFrame(rec, globalFrame);
    const jKey = smooth ? sanitizeMask(junction) : 0;
    const normTint = rec.colorable ? (tintHex || rec.default_tint || "#FFFFFF").toUpperCase() : "#FFFFFF";
    const cacheKey = `${assetId}|${jKey}|${fIdx}|${normTint}`;
    const cached = TINT_CELL_CACHE.get(cacheKey);
    if (cached) return cached;

    if (TINT_CELL_CACHE.size > MAX_CACHE_ENTRIES) {
      TINT_CELL_CACHE.delete(TINT_CELL_CACHE.keys().next().value);
    }

    const cw = rec.cell_w, ch = rec.cell_h;
    const off = document.createElement("canvas");
    off.width = cw;
    off.height = ch;
    const octx = off.getContext("2d", { willReadFrequently: true });
    octx.imageSmoothingEnabled = false;

    if (smooth && img.width >= cw * 47) {
      const col = J_INDEX.get(jKey) ?? 46;
      octx.drawImage(img, col * cw, fIdx * ch, cw, ch, 0, 0, cw, ch);
    } else if (smooth && img.width === 160 && cw === 32) {
      const qb = quadrantBlocks(jKey), sy = fIdx * 32;
      octx.drawImage(img, qb.tl * 32, sy, 16, 16, 0, 0, 16, 16);
      octx.drawImage(img, qb.tr * 32 + 16, sy, 16, 16, 16, 0, 16, 16);
      octx.drawImage(img, qb.bl * 32, sy + 16, 16, 16, 0, 16, 16, 16);
      octx.drawImage(img, qb.br * 32 + 16, sy + 16, 16, 16, 16, 16, 16, 16);
    } else {
      octx.drawImage(img, fIdx * cw, 0, cw, ch, 0, 0, cw, ch);
    }

    if (normTint !== "#FFFFFF") {
      const [tr, tg, tb] = parseHexRgb(normTint);
      const imgData = octx.getImageData(0, 0, cw, ch);
      const d = imgData.data;
      for (let i = 0; i < d.length; i += 4) {
        if (d[i + 3] > 0) {
          d[i] = ((d[i] * tr + 127) / 255) | 0;
          d[i + 1] = ((d[i + 1] * tg + 127) / 255) | 0;
          d[i + 2] = ((d[i + 2] * tb + 127) / 255) | 0;
        }
      }
      octx.putImageData(imgData, 0, 0);
    }

    TINT_CELL_CACHE.set(cacheKey, off);
    return off;
  }

  function drawThumbToCanvas(cv, assetId, tintHex) {
    const rec = ASSET_MAP.get(assetId);
    if (!rec) return;
    const ctx = cv.getContext("2d");
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = "#121622";
    ctx.fillRect(0, 0, cv.width, cv.height);
    const cell = getTintedCell(assetId, isSmoothKind(rec.kind) ? 0 : 255, 4, tintHex);
    if (!cell) return;
    const scale = Math.min(cv.width / cell.width, cv.height / cell.height);
    const dw = Math.max(1, Math.round(cell.width * scale)), dh = Math.max(1, Math.round(cell.height * scale));
    ctx.drawImage(cell, ((cv.width - dw) / 2) | 0, ((cv.height - dh) / 2) | 0, dw, dh);
  }

  function fillMatBackground(ctx, w, h, mode) {
    if (mode === "dark" || mode === "light") {
      ctx.fillStyle = mode === "dark" ? "#141722" : "#EFE8D5";
      ctx.fillRect(0, 0, w, h);
    } else if (mode === "mars" || mode === "earth") {
      const hex = mode === "mars" ? "#B85C3C" : "#CBB68C";
      const tile = getTintedCell("terrain_silicate_rough_smooth", 255, 0, hex);
      ctx.fillStyle = hex;
      ctx.fillRect(0, 0, w, h);
      if (tile) {
        for (let py = 0; py < h; py += 64) for (let px = 0; px < w; px += 64) ctx.drawImage(tile, px, py, 64, 64);
      }
    } else {
      const sz = 12;
      for (let py = 0; py < h; py += sz) {
        for (let px = 0; px < w; px += sz) {
          ctx.fillStyle = (((px / sz) + (py / sz)) & 1) ? "#262d40" : "#181d2a";
          ctx.fillRect(px, py, sz, sz);
        }
      }
    }
  }

  function preloadAllImages() {
    const loadOne = (uri, map, id) => new Promise((resolve) => {
      const im = new Image();
      im.onload = () => { map.set(id, im); resolve(); };
      im.onerror = () => resolve();
      im.src = uri;
    });
    const promises = [];
    for (const rec of ALL_ASSETS) {
      if (rec.atlas_data_uri) promises.push(loadOne(rec.atlas_data_uri, LOADED_IMAGES, rec.id));
      if (rec.strip_data_uri) promises.push(loadOne(rec.strip_data_uri, LOADED_STRIPS, rec.id));
    }
    return Promise.all(promises);
  }

  // =========================================================================
  // Workbench State & 6 Planetary Scene Presets (14x10)
  // =========================================================================
  function createEmptyGrid() {
    return Array.from({ length: GRID_H }, () => Array.from({ length: GRID_W }, () => ({
      base: "silicate", cliff: false, grass: false, moss: false,
      deck: null, hazard: null, matter: null, singleMatter: null,
      hedge: false, prop: null, campfire: false, haze: false,
    })));
  }

  const state = {
    activeTab: "diorama",
    activePresetId: "mars_cryo",
    splitMode: false,
    editSplitSide: "primary",
    sandyForeshore: false,
    zoom: 3,
    playing: true,
    frameIdx: 4,
    showGrid: false,
    hoverTile: null,
    isPainting: false,
    paintErase: false,
    activeBrushCategory: "terrain",
    activeBrushId: "terrain_silicate",
    layers: {
      terrain: true, ocean: true, backwash: true, swash: true, lace: true,
      cliffs: true, station: true, decals: true, matter: true, props: true, haze: true,
    },
    tintsPrimary: { ...DATA.biomePresets.mars_cryo_ammonia },
    tintsSecondary: { ...DATA.biomePresets.earth_coastal_meadow },
    grid: createEmptyGrid(),
    browserSearch: "",
    browserSource: "all",
    browserCategory: "all",
    selectedAssetId: TERRESTRIAL_ASSETS[0] ? TERRESTRIAL_ASSETS[0].id : "terrain_silicate_rough_smooth",
    neighborMask: 23,
    inspTint: "#B85C3C",
    inspMat: "mars",
  };

  function activeTintBag() {
    return (state.splitMode && state.editSplitSide === "secondary") ? state.tintsSecondary : state.tintsPrimary;
  }

  function fillRect(grid, x0, y0, x1, y1, fn) {
    for (let y = Math.max(0, y0); y <= Math.min(GRID_H - 1, y1); y++) {
      for (let x = Math.max(0, x0); x <= Math.min(GRID_W - 1, x1); x++) fn(grid[y][x], x, y);
    }
  }

  function placePropsXY(grid, entries) {
    for (const [x, y, id, tintRole, tint] of entries) {
      const p = { id };
      if (tintRole) p.tintRole = tintRole;
      if (tint) p.tint = tint;
      grid[y][x].prop = p;
    }
  }

  const SCENE_PRESETS = [
    {
      id: "mars_cryo",
      label: "1. Mars Cryo-NH3 & Pier",
      build() {
        state.splitMode = false;
        state.sandyForeshore = false;
        state.tintsPrimary = { ...DATA.biomePresets.mars_cryo_ammonia };
        const g = createEmptyGrid();
        fillRect(g, 0, 0, 4, 1, (c) => { c.cliff = true; });
        fillRect(g, 0, 2, 3, 2, (c) => { c.cliff = true; });
        fillRect(g, 0, 3, 1, 3, (c) => { c.cliff = true; });
        for (const [x, y] of [[0,0],[1,0],[2,0],[0,1],[1,1],[2,3],[3,3]]) g[y][x].moss = true;
        for (const [x, y] of [[5,0],[5,1],[6,1],[4,3]]) g[y][x].base = "low";

        fillRect(g, 7, 0, 13, 0, (c) => { c.base = "ice"; });
        fillRect(g, 8, 1, 13, 1, (c) => { c.base = "ice"; });
        fillRect(g, 9, 2, 13, 2, (c) => { c.base = "ice"; });
        fillRect(g, 11, 3, 13, 3, (c) => { c.base = "ice"; });
        for (const [x, y] of [[9,3],[10,3]]) g[y][x].base = "ocean";
        fillRect(g, 7, 4, 13, 5, (c) => { c.base = "ocean"; });
        fillRect(g, 5, 6, 13, 9, (c) => { c.base = "ocean"; });

        for (const [x, y] of [[7,0],[7,1],[8,1],[8,2],[9,2]]) {
          g[y][x].matter = { id: "solid_dusting_flour_smooth", tint: "#E8F4F8", alpha: 0.48 };
        }
        g[2][10].singleMatter = { id: "solid_shards_large", tintRole: "ice" };
        g[3][12].singleMatter = { id: "solid_shards_large", tintRole: "ice" };

        fillRect(g, 0, 5, 2, 8, (c, x) => { c.deck = x === 2 ? "plating" : "floor"; });
        for (const [wx, wy] of [[0,4],[1,4],[2,4],[3,4],[3,5],[3,7],[3,8],[0,9],[1,9],[2,9],[3,9]]) {
          g[wy][wx].deck = "plating";
          g[wy][wx].prop = { id: "wall" };
        }
        g[6][3].deck = "plating";
        for (const [px, py] of [[4,5],[4,6],[4,7],[4,8]]) g[py][px].deck = "plating";
        g[5][4].hazard = "decal_hazard_s";
        g[8][1].hazard = "decal_hazard_s";
        g[8][2].hazard = "decal_hazard_s";
        g[6][4].hazard = "decal_hazard_e";
        for (const px of [5, 6, 7]) g[6][px].deck = "catwalk";

        for (const [x, y] of [[2,6],[3,6],[4,6]]) g[y][x].matter = { id: "liquid_puddle_smooth_shimmer", tintRole: "ocean", alpha: 0.85 };
        for (const [x, y] of [[4,7],[4,8]]) g[y][x].matter = { id: "solid_debris_jagged_smooth", tintRole: "silicate", alpha: 0.80 };
        g[7][2].singleMatter = { id: "solid_scattering", tintRole: "silicate" };

        placePropsXY(g, [
          [2, 4, "apc"], [3, 6, "airlock_glass_closed"],
          [1, 5, "canister_ammonia"], [4, 5, "canister_ammonia"], [0, 7, "crate_steel"],
          [1, 1, "prop_rough_outcrop_1", "cliff"], [3, 0, "basalt2", "cliff"],
          [3, 1, "siderite_growth1"], [5, 2, "siderite_growth2"],
          [5, 3, "prop_rough_outcrop_1", "silicate"], [6, 2, "basalt1", "silicate"],
          [2, 3, "lavarocks_siderite1"], [7, 2, "lavarocks_siderite2"],
          [11, 1, "ore_vent_ice"], [9, 1, "prop_rough_outcrop_2", "ice"],
          [12, 2, "prop_rough_outcrop_2", "ice"], [6, 4, "geyser", null, "#9EA858"],
        ]);
        fillRect(g, 7, 4, 10, 5, (c) => { c.haze = true; });
        fillRect(g, 8, 6, 11, 7, (c) => { c.haze = true; });
        state.grid = g;
      },
    },
    {
      id: "mars_pack",
      label: "2. Mars Pack NH3 colours",
      build() {
        SCENE_PRESETS[0].build();
        state.tintsPrimary = { ...DATA.biomePresets.mars_pack_ammonia };
      },
    },
    {
      id: "mars_polar",
      label: "3. Mars Polar Ice Bay",
      build() {
        state.splitMode = false;
        state.sandyForeshore = false;
        state.tintsPrimary = { ...DATA.biomePresets.mars_polar_ice };
        const g = createEmptyGrid();
        fillRect(g, 0, 0, 13, 2, (c) => { c.base = "ice"; });
        fillRect(g, 9, 3, 13, 9, (c) => { c.base = "ice"; });
        fillRect(g, 0, 0, 3, 1, (c) => { c.base = "silicate"; c.cliff = true; });
        fillRect(g, 0, 2, 4, 9, (c) => { c.base = "silicate"; });
        for (const [x, y] of [[3,3],[4,3],[3,4]]) g[y][x].base = "low";
        fillRect(g, 5, 3, 9, 5, (c) => { c.base = "ocean"; });
        fillRect(g, 4, 6, 10, 9, (c) => { c.base = "ocean"; });

        for (const [wx, wy] of [[1,5],[2,5],[3,5],[1,6],[1,7],[1,8],[2,8],[3,8]]) {
          g[wy][wx].deck = "plating";
          g[wy][wx].prop = { id: "wall" };
        }
        g[6][2].deck = "floor"; g[7][2].deck = "floor";
        g[6][3].deck = "plating"; g[7][3].deck = "plating";
        fillRect(g, 4, 6, 5, 7, (c) => { c.deck = "glass_floor"; });

        placePropsXY(g, [
          [3, 6, "airlock_glass_closed"], [2, 6, "canister_ammonia"], [2, 5, "apc"],
          [7, 1, "ore_vent_ice"], [11, 1, "ore_vent_ice"],
          [10, 2, "prop_rough_outcrop_2", "ice"], [11, 5, "prop_rough_outcrop_2", "ice"],
          [2, 3, "basalt1", "silicate"], [1, 4, "basalt2", "silicate"],
        ]);
        g[2][8].singleMatter = { id: "solid_shards_large", tintRole: "ice" };
        g[4][10].singleMatter = { id: "solid_shards_small", tintRole: "ice" };
        fillRect(g, 6, 4, 8, 6, (c) => { c.haze = true; });
        state.grid = g;
      },
    },
    {
      id: "earth_meadow",
      label: "4. Earth Meadow & Outpost",
      build() {
        state.splitMode = false;
        state.sandyForeshore = true;
        state.tintsPrimary = { ...DATA.biomePresets.earth_coastal_meadow };
        const g = createEmptyGrid();
        fillRect(g, 0, 0, 4, 1, (c) => { c.cliff = true; });
        fillRect(g, 0, 2, 3, 2, (c) => { c.cliff = true; });
        fillRect(g, 0, 3, 1, 3, (c) => { c.cliff = true; });
        fillRect(g, 12, 0, 13, 1, (c) => { c.cliff = true; });

        fillRect(g, 9, 4, 13, 4, (c) => { c.base = "ocean"; });
        fillRect(g, 7, 5, 13, 6, (c) => { c.base = "ocean"; });
        fillRect(g, 6, 7, 13, 9, (c) => { c.base = "ocean"; });
        for (const [x, y] of [[9,3],[10,3],[11,3],[12,3],[13,3],[7,4],[8,4],[6,5],[6,6],[5,7],[5,8],[5,9]]) g[y][x].base = "low";

        fillRect(g, 4, 0, 11, 2, (c) => { c.grass = true; });
        for (const [x, y] of [[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[8,3],[6,4],[4,6],[5,6],[4,7]]) g[y][x].grass = true;
        for (const [x, y] of [[0,0],[1,0],[2,0],[0,1],[1,1],[12,0],[13,0],[1,7],[3,5],[3,7]]) g[y][x].moss = true;

        for (const [wx, wy] of [[0,4],[1,4],[2,4],[2,5],[2,7],[2,8],[0,9],[1,9],[2,9]]) {
          g[wy][wx].deck = "plating";
          g[wy][wx].prop = { id: "reinforced_wall" };
        }
        fillRect(g, 0, 5, 1, 8, (c, x, y) => { c.deck = (x === 1 && y === 7) ? "open_floor" : "floor"; });
        g[6][2].deck = "plating";
        for (const [px, py] of [[3,5],[3,6],[3,7],[4,6],[4,7],[5,6]]) g[py][px].deck = "plating";
        for (const hx of [3, 4, 5]) g[3][hx].hedge = true;
        fillRect(g, 4, 4, 5, 5, (c) => { c.matter = { id: "solid_soil_tilled_smooth", tint: "#6B4C35", alpha: 1.0 }; });
        for (const [x, y] of [[3,6],[4,6]]) g[y][x].matter = { id: "liquid_puddle_smooth_shimmer", tint: "#5F9BD5", alpha: 0.82 };

        placePropsXY(g, [
          [2, 6, "airlock_closed"], [0, 5, "crate_hydro"], [3, 4, "canister_blue"],
          [4, 2, "tree1"], [8, 2, "tree2"], [11, 1, "bush1"], [11, 3, "palm1"],
          [6, 1, "ywflowers_1"], [6, 2, "ppflowers_1"], [10, 1, "ppflowers_1"], [10, 2, "brflowers_1"],
          [7, 1, "lavendergrass_1"], [6, 3, "lavendergrass_1"], [5, 1, "fernybush_1"], [9, 2, "fernybush_1"],
          [7, 4, "reedbush_1"], [6, 6, "reedbush_2"],
          [1, 1, "prop_rough_outcrop_1", "cliff"], [12, 1, "prop_rough_outcrop_2", "cliff"],
          [2, 3, "rock1"], [12, 2, "rock2"], [10, 0, "rock3"],
        ]);
        g[3][9].singleMatter = { id: "solid_pile_small", tint: "#6B5746" };
        g[3][9].campfire = true;
        state.grid = g;
      },
    },
    {
      id: "earth_jungle",
      label: "5. Earth Jungle Campfire",
      build() {
        state.splitMode = false;
        state.sandyForeshore = true;
        state.tintsPrimary = { ...DATA.biomePresets.earth_lush_jungle };
        const g = createEmptyGrid();
        fillRect(g, 0, 0, 2, 1, (c) => { c.cliff = true; c.moss = true; });
        fillRect(g, 11, 0, 13, 2, (c) => { c.cliff = true; c.moss = true; });
        fillRect(g, 8, 5, 13, 9, (c) => { c.base = "ocean"; });
        fillRect(g, 4, 7, 7, 9, (c) => { c.base = "ocean"; });
        for (const [x, y] of [[7,5],[7,6],[6,6],[5,6],[4,6],[3,7],[3,8],[3,9]]) g[y][x].base = "low";

        for (let y = 0; y < GRID_H; y++) {
          for (let x = 0; x < GRID_W; x++) {
            if (g[y][x].base === "silicate" && !g[y][x].cliff) {
              g[y][x].grass = true;
              if ((x + y) % 3 === 0) g[y][x].moss = true;
            }
          }
        }
        g[4][5].grass = false; g[4][5].moss = false;
        g[4][5].singleMatter = { id: "solid_pile_small", tint: "#5C4D42" };
        g[4][5].campfire = true;

        placePropsXY(g, [
          [3, 2, "tree1"], [9, 2, "tree2"], [1, 6, "tree1"], [7, 4, "rocks1"], [2, 4, "bush1"],
          [12, 1, "prop_rough_outcrop_1", "cliff"], [7, 5, "reedbush_1"], [4, 6, "reedbush_2"],
          [3, 7, "reedbush_1"], [6, 3, "fernybush_2"], [4, 3, "ywflowers_2"], [6, 2, "ppflowers_2"],
          [2, 5, "busha1"], [1, 8, "bushb1"],
        ]);
        fillRect(g, 8, 6, 12, 8, (c) => { c.haze = true; });
        fillRect(g, 5, 8, 7, 9, (c) => { c.haze = true; });
        state.grid = g;
      },
    },
    {
      id: "twin_split",
      label: "6. Twin-Biome Split (Mars | Earth)",
      build() {
        state.splitMode = true;
        state.sandyForeshore = false;
        state.tintsPrimary = { ...DATA.biomePresets.mars_cryo_ammonia };
        state.tintsSecondary = { ...DATA.biomePresets.earth_coastal_meadow };
        const g = createEmptyGrid();
        for (let y = 0; y < GRID_H; y++) {
          for (let x = 0; x < 7; x++) {
            const mx = 13 - x;
            const isCliff = (y <= 1 && x <= 3) || (y === 2 && x <= 2) || (y === 3 && x <= 1);
            const isTopShelf = (y <= 1 && x >= 5) || (y === 2 && x === 6);
            const isOcean = (y === 4 && x >= 4) || (y === 5 && x >= 3) || (y >= 6 && x >= 2);
            const isLow = (x === 4 && y === 1) || (x === 3 && y === 2);

            g[y][x].cliff = isCliff; g[y][mx].cliff = isCliff;
            if (isOcean) { g[y][x].base = "ocean"; g[y][mx].base = "ocean"; }
            else if (isTopShelf) { g[y][x].base = "ice"; g[y][mx].base = "silicate"; }
            else if (isLow) { g[y][x].base = "low"; g[y][mx].base = "low"; }

            if ((y === 5 || y === 8) && x <= 1) {
              g[y][x].deck = "plating"; g[y][x].prop = { id: "wall" };
              g[y][mx].deck = "plating"; g[y][mx].prop = { id: "reinforced_wall" };
            }
            if ((y === 6 || y === 7) && x === 0) { g[y][x].deck = "floor"; g[y][mx].deck = "floor"; }
            if (y === 6 && x === 1) {
              g[y][x].deck = "plating"; g[y][x].prop = { id: "airlock_glass_closed" };
              g[y][mx].deck = "plating"; g[y][mx].prop = { id: "airlock_closed" };
            }
            if (y === 7 && x === 1) {
              g[y][x].deck = "plating"; g[y][x].prop = { id: "wall" };
              g[y][mx].deck = "plating"; g[y][mx].prop = { id: "reinforced_wall" };
            }
            if (y === 6 && (x === 2 || x === 3)) { g[y][x].deck = "catwalk"; g[y][mx].deck = "catwalk"; }
            if (!isOcean && !isCliff && !(y >= 5 && y <= 8 && x <= 1) && y <= 5) g[y][mx].grass = true;
          }
        }
        for (const [x, y] of [[1,1],[12,1],[0,0],[13,0]]) g[y][x].moss = true;
        placePropsXY(g, [
          [1, 1, "prop_rough_outcrop_1", "cliff"], [12, 1, "prop_rough_outcrop_1", "cliff"],
          [4, 2, "prop_rough_outcrop_2", "silicate"], [9, 2, "prop_rough_outcrop_2", "cliff"],
          [2, 1, "siderite_growth1"], [5, 1, "ore_vent_ice"], [3, 3, "geyser", null, "#9EA858"], [0, 7, "canister_ammonia"],
          [8, 2, "tree1"], [10, 3, "bush1"], [8, 3, "palm1"], [8, 1, "ywflowers_1"],
          [9, 3, "ppflowers_1"], [10, 4, "reedbush_1"], [13, 7, "crate_hydro"],
        ]);
        for (const [hx, hy] of [[4,4],[5,4],[4,5],[5,5]]) g[hy][hx].haze = true;
        state.grid = g;
      },
    },
  ];

  // =========================================================================
  // Brush Catalog & Tile Painting
  // =========================================================================
  const STRUCTURAL_HULL_IDS = new Set(["wall", "reinforced_wall", "airlock_closed", "airlock_glass_closed"]);
  const PLATING_UNDERLAY_DECKS = new Set(["open_floor", "wall", "reinforced_wall", "airlock_closed", "airlock_glass_closed"]);

  const BRUSH_CATEGORIES = [
    { id: "terrain", label: "Terrain & Cliff" },
    { id: "decals", label: "Nature Decals" },
    { id: "station", label: "Station & Hull" },
    { id: "matter", label: "TfS Matter" },
    { id: "props", label: "Flora & Props" },
  ];

  const RAW_BRUSHES = [
    { id: "terrain_silicate", cat: "terrain", label: "Silicate Shelf", thumb: "terrain_silicate_rough_smooth", tintRole: "silicate", apply: (c) => { c.base = "silicate"; } },
    { id: "terrain_low", cat: "terrain", label: "Low Regolith / Sand", thumb: "terrain_silicate_rough_smooth", tintRole: "silicate_low", apply: (c) => { c.base = "low"; c.cliff = false; } },
    { id: "terrain_ice", cat: "terrain", label: "Calving Ice Sheet", thumb: "terrain_ice_sheet_smooth", tintRole: "ice", apply: (c) => { c.base = "ice"; } },
    { id: "terrain_ocean", cat: "terrain", label: "Ocean + Swash", thumb: "ocean_body_smooth", tintRole: "ocean", apply: (c) => { c.base = "ocean"; c.cliff = false; } },
    { id: "cliff_add", cat: "terrain", label: "Stepped Cliff", thumb: "terrain_cliff_stepped_smooth", tintRole: "cliff", apply: (c) => { if (c.base === "ocean") c.base = "silicate"; c.cliff = true; } },
    { id: "cliff_erase", cat: "terrain", label: "Erase Cliff", thumb: "terrain_silicate_rough_smooth", tintRole: "silicate_low", apply: (c) => { c.cliff = false; } },

    { id: "decal_grass", cat: "decals", label: "Smooth Grass Decal", thumb: "solid_grass_smooth", tintRole: "grass", apply: (c) => { c.grass = true; } },
    { id: "decal_moss", cat: "decals", label: "Smooth Moss Decal", thumb: "solid_moss_smooth", tintRole: "moss", apply: (c) => { c.moss = true; } },
    { id: "decal_erase", cat: "decals", label: "Erase Nature Decals", thumb: "rock_floor", apply: (c) => { c.grass = false; c.moss = false; } },

    { id: "deck_plating", cat: "station", label: "Station Plating", thumb: "plating", apply: (c) => { c.deck = "plating"; } },
    { id: "deck_floor", cat: "station", label: "Tiled Floor", thumb: "floor", apply: (c) => { c.deck = "floor"; } },
    { id: "deck_open", cat: "station", label: "Open Grid Floor", thumb: "open_floor", apply: (c) => { c.deck = "open_floor"; } },
    { id: "deck_catwalk", cat: "station", label: "Catwalk Pier", thumb: "catwalk", apply: (c) => { c.deck = "catwalk"; } },
    { id: "deck_glass", cat: "station", label: "Glass Floor Window", thumb: "glass_floor", apply: (c) => { c.deck = "glass_floor"; } },
    { id: "pr_wall", cat: "station", label: "Station Wall", thumb: "wall", apply: (c) => { if (!c.deck) c.deck = "plating"; c.prop = { id: "wall" }; } },
    { id: "pr_rwall", cat: "station", label: "Reinforced Wall", thumb: "reinforced_wall", apply: (c) => { if (!c.deck) c.deck = "plating"; c.prop = { id: "reinforced_wall" }; } },
    { id: "pr_airlk", cat: "station", label: "Glass Airlock", thumb: "airlock_glass_closed", apply: (c) => { if (!c.deck) c.deck = "plating"; c.prop = { id: "airlock_glass_closed" }; } },
    { id: "pr_airlk_solid", cat: "station", label: "Solid Airlock", thumb: "airlock_closed", apply: (c) => { if (!c.deck) c.deck = "plating"; c.prop = { id: "airlock_closed" }; } },
    { id: "deck_hazard", cat: "station", label: "Hazard Stripe (S)", thumb: "decal_hazard_s", apply: (c) => { if (!c.deck) c.deck = "plating"; c.hazard = "decal_hazard_s"; } },
    { id: "deck_erase", cat: "station", label: "Erase Deck / Hull", thumb: "space", apply: (c) => { c.deck = null; c.hazard = null; if (c.prop && STRUCTURAL_HULL_IDS.has(c.prop.id)) c.prop = null; } },

    { id: "mat_puddle", cat: "matter", label: "Shimmer Puddle", thumb: "liquid_puddle_smooth_shimmer", tintRole: "ocean", apply: (c) => { c.matter = { id: "liquid_puddle_smooth_shimmer", tintRole: "ocean", alpha: 0.85 }; } },
    { id: "mat_frost", cat: "matter", label: "Frost / Flour Drift", thumb: "solid_dusting_flour_smooth", tintRole: "ice", apply: (c) => { c.matter = { id: "solid_dusting_flour_smooth", tint: "#E8F4F8", alpha: 0.48 }; } },
    { id: "mat_debris", cat: "matter", label: "Jagged Scree", thumb: "solid_debris_jagged_smooth", tintRole: "silicate", apply: (c) => { c.matter = { id: "solid_debris_jagged_smooth", tintRole: "silicate", alpha: 0.82 }; } },
    { id: "mat_tilled", cat: "matter", label: "Tilled Soil Plot", thumb: "solid_soil_tilled_smooth", apply: (c) => { c.matter = { id: "solid_soil_tilled_smooth", tint: "#6B4C35", alpha: 1.0 }; } },
    { id: "mat_shards", cat: "matter", label: "Ice Shards (Large)", thumb: "solid_shards_large", tintRole: "ice", apply: (c) => { c.singleMatter = { id: "solid_shards_large", tintRole: "ice" }; } },
    { id: "mat_campfire", cat: "matter", label: "Campfire + Stones", thumb: "fire_campfire_steady", apply: (c) => { c.singleMatter = { id: "solid_pile_small", tint: "#6B5746" }; c.campfire = true; } },
    { id: "mat_haze", cat: "matter", label: "Gas Mist Haze", thumb: "gas_mist_smooth_gentle", tintRole: "haze", apply: (c) => { c.haze = true; } },
    { id: "mat_erase", cat: "matter", label: "Erase Matter/Haze", thumb: "space", apply: (c) => { c.matter = null; c.singleMatter = null; c.campfire = false; c.haze = false; } },

    { id: "pr_outcrop1", cat: "props", label: "Outcrop 1 (Tint)", thumb: "prop_rough_outcrop_1", tintRole: "silicate", apply: (c) => { c.prop = { id: "prop_rough_outcrop_1", tintRole: "silicate" }; } },
    { id: "pr_outcrop2", cat: "props", label: "Outcrop 2 (Tint)", thumb: "prop_rough_outcrop_2", tintRole: "cliff", apply: (c) => { c.prop = { id: "prop_rough_outcrop_2", tintRole: "cliff" }; } },
    { id: "pr_rock1", cat: "props", label: "TG Rock 1 (32)", thumb: "rock1", apply: (c) => { c.prop = { id: "rock1" }; } },
    { id: "pr_rock2", cat: "props", label: "TG Rock 2 (32)", thumb: "rock2", apply: (c) => { c.prop = { id: "rock2" }; } },
    { id: "pr_rock3", cat: "props", label: "TG Rock 3 (32)", thumb: "rock3", apply: (c) => { c.prop = { id: "rock3" }; } },
    { id: "pr_rocks1", cat: "props", label: "TG Rocks 1 (64x64)", thumb: "rocks1", apply: (c) => { c.prop = { id: "rocks1" }; } },
    { id: "pr_basalt1", cat: "props", label: "TG Basalt Spire 1", thumb: "basalt1", tintRole: "cliff", apply: (c) => { c.prop = { id: "basalt1", tintRole: "cliff" }; } },
    { id: "pr_basalt2", cat: "props", label: "TG Basalt Crag 2", thumb: "basalt2", tintRole: "cliff", apply: (c) => { c.prop = { id: "basalt2", tintRole: "cliff" }; } },
    { id: "pr_tree1", cat: "props", label: "Canopy Tree 1 (96)", thumb: "tree1", apply: (c) => { c.prop = { id: "tree1" }; } },
    { id: "pr_tree2", cat: "props", label: "Canopy Tree 2 (96)", thumb: "tree2", apply: (c) => { c.prop = { id: "tree2" }; } },
    { id: "pr_bush1", cat: "props", label: "Leafy Thicket (64)", thumb: "bush1", apply: (c) => { c.prop = { id: "bush1" }; } },
    { id: "pr_palm1", cat: "props", label: "Palm Tree (32x64)", thumb: "palm1", apply: (c) => { c.prop = { id: "palm1" }; } },
    { id: "pr_pine1", cat: "props", label: "Snow Pine 1 (64x96)", thumb: "pine_1", apply: (c) => { c.prop = { id: "pine_1" }; } },
    { id: "pr_pine2", cat: "props", label: "Snow Pine 2 (64x96)", thumb: "pine_2", apply: (c) => { c.prop = { id: "pine_2" }; } },
    { id: "pr_hedge", cat: "props", label: "TG Hedge (Smooth)", thumb: "tg_hedge", apply: (c) => { c.hedge = true; } },
    { id: "pr_ywfl", cat: "props", label: "Yellow Wildflowers", thumb: "ywflowers_1", apply: (c) => { c.prop = { id: "ywflowers_1" }; } },
    { id: "pr_ppfl", cat: "props", label: "Purple Wildflowers", thumb: "ppflowers_1", apply: (c) => { c.prop = { id: "ppflowers_1" }; } },
    { id: "pr_lav", cat: "props", label: "Lavender Grass", thumb: "lavendergrass_1", apply: (c) => { c.prop = { id: "lavendergrass_1" }; } },
    { id: "pr_fern", cat: "props", label: "Ferny Bush", thumb: "fernybush_1", apply: (c) => { c.prop = { id: "fernybush_1" }; } },
    { id: "pr_reed", cat: "props", label: "Shoreline Reeds", thumb: "reedbush_1", apply: (c) => { c.prop = { id: "reedbush_1" }; } },
    { id: "pr_sid1", cat: "props", label: "Siderite Spire 1", thumb: "siderite_growth1", apply: (c) => { c.prop = { id: "siderite_growth1" }; } },
    { id: "pr_icev", cat: "props", label: "Ice Ore Vent", thumb: "ore_vent_ice", apply: (c) => { c.prop = { id: "ore_vent_ice" }; } },
    { id: "pr_geys", cat: "props", label: "Ammonia Geyser", thumb: "geyser", apply: (c) => { c.prop = { id: "geyser", tint: "#9EA858" }; } },
    { id: "pr_can_nh3", cat: "props", label: "NH3 Canister", thumb: "canister_ammonia", apply: (c) => { c.prop = { id: "canister_ammonia" }; } },
    { id: "pr_can_blu", cat: "props", label: "Blue Canister", thumb: "canister_blue", apply: (c) => { c.prop = { id: "canister_blue" }; } },
    { id: "pr_hydro", cat: "props", label: "Hydro Crate", thumb: "crate_hydro", apply: (c) => { c.prop = { id: "crate_hydro" }; } },
    { id: "pr_apc", cat: "props", label: "Wall APC", thumb: "apc", apply: (c) => { c.prop = { id: "apc" }; } },
    { id: "pr_erase", cat: "props", label: "Erase Prop/Flora", thumb: "space", apply: (c) => { if (c.prop && !STRUCTURAL_HULL_IDS.has(c.prop.id)) c.prop = null; c.hedge = false; } },
  ];

  const BRUSHES = RAW_BRUSHES.filter((b) => b.thumb === "space" || ASSET_MAP.has(b.thumb));
  const BRUSH_MAP = new Map(BRUSHES.map((b) => [b.id, b]));

  function applyPaintAt(x, y, eraseMode) {
    if (x < 0 || x >= GRID_W || y < 0 || y >= GRID_H) return;
    const cell = state.grid[y][x];
    const br = BRUSH_MAP.get(state.activeBrushId);
    if (!br) return;
    if (!eraseMode) { br.apply(cell); return; }
    if (br.id === "cliff_add" || br.id === "cliff_erase") { cell.cliff = false; }
    else if (br.cat === "terrain") { cell.base = "silicate"; }
    else if (br.cat === "decals") { cell.grass = false; cell.moss = false; }
    else if (br.cat === "station") { cell.deck = null; cell.hazard = null; if (cell.prop && STRUCTURAL_HULL_IDS.has(cell.prop.id)) cell.prop = null; }
    else if (br.cat === "matter") { cell.matter = null; cell.singleMatter = null; cell.campfire = false; cell.haze = false; }
    else if (br.cat === "props") { if (cell.prop && !STRUCTURAL_HULL_IDS.has(cell.prop.id)) cell.prop = null; cell.hedge = false; }
  }

  // =========================================================================
  // Core 14x10 Stage / Tilemap Compositor & Animation Loop
  // =========================================================================
  const offDiorama = document.createElement("canvas");
  offDiorama.width = GRID_W * TILE_PX;
  offDiorama.height = GRID_H * TILE_PX;
  const offCtx = offDiorama.getContext("2d");
  offCtx.imageSmoothingEnabled = false;

  const mainCanvas = document.getElementById("diorama-canvas");
  const mainCtx = mainCanvas.getContext("2d");
  const tintsAt = (x) => (state.splitMode && x >= 7) ? state.tintsSecondary : state.tintsPrimary;
  const sandyShoreAt = (x) => state.splitMode ? (x >= 7) : state.sandyForeshore;

  function canvasCoordsToTile(ev) {
    const rect = mainCanvas.getBoundingClientRect();
    const px = (ev.clientX - rect.left) * (mainCanvas.width / rect.width);
    const py = (ev.clientY - rect.top) * (mainCanvas.height / rect.height);
    const step = TILE_PX * state.zoom;
    const tx = Math.floor(px / step), ty = Math.floor(py / step);
    return (tx < 0 || tx >= GRID_W || ty < 0 || ty >= GRID_H) ? null : { x: tx, y: ty };
  }

  function renderDiorama1x() {
    const g = state.grid, f = state.frameIdx, L = state.layers;
    offCtx.fillStyle = "#141722";
    offCtx.fillRect(0, 0, offDiorama.width, offDiorama.height);

    const boundsFor = (x) => state.splitMode ? (x < 7 ? [0, 6] : [7, 13]) : [0, GRID_W - 1];
    const eachTile = (fn) => {
      for (let y = 0; y < GRID_H; y++) {
        for (let x = 0; x < GRID_W; x++) {
          const [minX, maxX] = boundsFor(x);
          fn(g[y][x], x, y, minX, maxX, tintsAt(x));
        }
      }
    };
    const blitCell = (id, jv, tint, x, y, alpha = 1.0) => {
      const cell = getTintedCell(id, jv, f, tint);
      if (!cell) return;
      if (alpha < 1.0) { offCtx.save(); offCtx.globalAlpha = alpha; offCtx.drawImage(cell, x * 32, y * 32); offCtx.restore(); }
      else offCtx.drawImage(cell, x * 32, y * 32);
    };
    const isCalvingEdge = (x, y) => {
      if (g[y][x].base !== "ice") return false;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx, ny = y + dy;
          if ((dx || dy) && nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H && g[ny][nx].base === "ocean") return true;
        }
      }
      return false;
    };

    if (L.terrain || L.ocean) {
      const quads = [
        [0, 0, [[-1, 0], [0, -1], [-1, -1]]], [16, 0, [[1, 0], [0, -1], [1, -1]]],
        [0, 16, [[-1, 0], [0, 1], [-1, 1]]], [16, 16, [[1, 0], [0, 1], [1, 1]]],
      ];
      eachTile((c, x, y, _minX, _maxX, t) => {
        const isOceanTile = c.base === "ocean";
        if (!L.terrain && !isOceanTile) return;
        blitCell("terrain_silicate_rough_smooth", 255, t.silicate_low, x, y);
        if (!isOceanTile) return;
        const sil255 = getTintedCell("terrain_silicate_rough_smooth", 255, f, t.silicate);
        const ice255 = getTintedCell("terrain_ice_sheet_smooth", 255, f, t.ice);
        const silicateUnderOcean = !sandyShoreAt(x);
        for (const [qx, qy, dirs] of quads) {
          let hasIce = false, hasSil = false;
          for (const [dx, dy] of dirs) {
            const nx = x + dx, ny = y + dy;
            if (nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H) {
              if (L.terrain && g[ny][nx].base === "ice") hasIce = true;
              if ((L.terrain && g[ny][nx].base === "silicate") || (L.station && Boolean(g[ny][nx].deck))) hasSil = true;
            }
          }
          if (hasIce && ice255) offCtx.drawImage(ice255, qx, qy, 16, 16, x * 32 + qx, y * 32 + qy, 16, 16);
          else if (silicateUnderOcean && hasSil && sil255) offCtx.drawImage(sil255, qx, qy, 16, 16, x * 32 + qx, y * 32 + qy, 16, 16);
        }
      });
    }

    if (L.ocean) {
      const calvingAt = (nx, ny) => L.terrain && isCalvingEdge(nx, ny);
      eachTile((c, x, y, minX, maxX, t) => {
        if (c.base !== "ocean" && !calvingAt(x, y)) return;
        const jv = computeJunction((nx, ny) => g[ny][nx].base === "ocean" || calvingAt(nx, ny), x, y, GRID_W, GRID_H, true, minX, maxX);
        blitCell("ocean_body_smooth", jv, t.ocean, x, y);
      });
    }

    if (L.terrain) {
      eachTile((c, x, y, minX, maxX, t) => {
        if (c.base === "silicate") {
          const silUnder = !sandyShoreAt(x);
          const jv = computeJunction((nx, ny) => {
            const nb = g[ny][nx].base;
            return nb === "silicate" || nb === "ice" || (silUnder && nb === "ocean");
          }, x, y, GRID_W, GRID_H, true, minX, maxX);
          blitCell("terrain_silicate_rough_smooth", jv, t.silicate, x, y);
        } else if (c.base === "ice") {
          const jv = computeJunction((nx, ny) => g[ny][nx].base === "ice", x, y, GRID_W, GRID_H, true, minX, maxX);
          blitCell("terrain_ice_sheet_smooth", jv, t.ice, x, y);
        }
      });
    }

    if (L.station) {
      eachTile((c, x, y) => {
        const d = c.deck, p = c.prop;
        if (!d || d === "catwalk" || d === "glass_floor") {
          if (p && STRUCTURAL_HULL_IDS.has(p.id)) blitCell("plating", 255, "#FFFFFF", x, y);
          return;
        }
        if (PLATING_UNDERLAY_DECKS.has(d)) blitCell("plating", 255, "#FFFFFF", x, y);
        blitCell(d, 255, "#FFFFFF", x, y);
      });
    }

    if (L.backwash || L.swash || L.lace) {
      eachTile((c, x, y, minX, maxX, t) => {
        if (c.base !== "ocean") return;
        const jv = computeJunction((nx, ny) => g[ny][nx].base === "ocean", x, y, GRID_W, GRID_H, true, minX, maxX);
        if (jv === 255) return;
        if (L.backwash) blitCell("ocean_backwash_smooth", jv, t.backwash || "#594936", x, y);
        if (L.swash) blitCell("ocean_swash_smooth", jv, t.swash, x, y);
        if (L.lace) blitCell("ocean_foam_lace_smooth", jv, t.swash, x, y);
      });
    }

    if (L.station) {
      eachTile((c, x, y, minX, maxX) => {
        const d = c.deck;
        if (d !== "catwalk" && d !== "glass_floor") return;
        const jv = computeJunction((nx, ny) => g[ny][nx].deck === d || (d === "catwalk" && g[ny][nx].deck === "plating"), x, y, GRID_W, GRID_H, false, minX, maxX);
        blitCell(d, jv, "#FFFFFF", x, y);
      });
    }

    if (L.decals) {
      eachTile((c, x, y, minX, maxX, t) => {
        if (c.cliff) return;
        if (c.grass) blitCell("solid_grass_smooth", computeJunction((nx, ny) => g[ny][nx].grass && !g[ny][nx].cliff, x, y, GRID_W, GRID_H, false, minX, maxX), t.grass, x, y);
        if (c.moss) blitCell("solid_moss_smooth", computeJunction((nx, ny) => g[ny][nx].moss && !g[ny][nx].cliff, x, y, GRID_W, GRID_H, false, minX, maxX), t.moss, x, y);
      });
    }

    if (L.station) eachTile((c, x, y) => { if (c.hazard) blitCell(c.hazard, 255, "#FFFFFF", x, y); });

    if (L.cliffs) {
      eachTile((c, x, y, minX, maxX, t) => {
        if (!c.cliff) return;
        blitCell("terrain_cliff_stepped_smooth", computeJunction((nx, ny) => g[ny][nx].cliff, x, y, GRID_W, GRID_H, true, minX, maxX), t.cliff, x, y);
        if (L.decals && c.grass) blitCell("solid_grass_smooth", computeJunction((nx, ny) => g[ny][nx].grass && g[ny][nx].cliff, x, y, GRID_W, GRID_H, true, minX, maxX), t.grass, x, y);
        if (L.decals && c.moss) blitCell("solid_moss_smooth", computeJunction((nx, ny) => g[ny][nx].moss && g[ny][nx].cliff, x, y, GRID_W, GRID_H, true, minX, maxX), t.moss, x, y);
      });
    }

    if (L.matter) {
      eachTile((c, x, y, minX, maxX, t) => {
        if (c.matter) {
          const m = c.matter;
          const jv = computeJunction((nx, ny) => g[ny][nx].matter && g[ny][nx].matter.id === m.id, x, y, GRID_W, GRID_H, false, minX, maxX);
          blitCell(m.id, jv, m.tint || (m.tintRole ? t[m.tintRole] : "#FFFFFF"), x, y, m.alpha ?? 1.0);
        }
        if (c.singleMatter) {
          const sm = c.singleMatter;
          blitCell(sm.id, 255, sm.tint || (sm.tintRole ? t[sm.tintRole] : "#FFFFFF"), x, y);
        }
      });
    }

    if (L.props || L.station) {
      for (let y = 0; y < GRID_H; y++) {
        if (L.props) {
          for (let x = 0; x < GRID_W; x++) {
            if (!g[y][x].hedge) continue;
            const [minX, maxX] = boundsFor(x);
            blitCell("tg_hedge", computeJunction((nx, ny) => g[ny][nx].hedge, x, y, GRID_W, GRID_H, false, minX, maxX), "#FFFFFF", x, y);
          }
        }
        for (let x = 0; x < GRID_W; x++) {
          const p = g[y][x].prop;
          if (!p) continue;
          if (STRUCTURAL_HULL_IDS.has(p.id) ? !L.station : !L.props) continue;
          const rec = ASSET_MAP.get(p.id);
          if (!rec) continue;
          const tint = p.tint || (p.tintRole ? tintsAt(x)[p.tintRole] : "#FFFFFF");
          const cell = getTintedCell(p.id, 255, f, tint);
          if (cell) offCtx.drawImage(cell, x * 32 + rec.offset_x, y * 32 + rec.offset_y);
        }
      }
    }

    if (L.matter) eachTile((c, x, y) => { if (c.campfire) blitCell("fire_campfire_steady", 255, "#FFFFFF", x, y); });
    if (L.haze) {
      eachTile((c, x, y, minX, maxX, t) => {
        if (!c.haze) return;
        blitCell("gas_mist_smooth_gentle", computeJunction((nx, ny) => g[ny][nx].haze, x, y, GRID_W, GRID_H, false, minX, maxX), t.haze, x, y, 0.45);
      });
    }
  }

  function drawMainCanvas() {
    renderDiorama1x();
    const z = state.zoom, targetW = GRID_W * TILE_PX * z, targetH = GRID_H * TILE_PX * z;
    if (mainCanvas.width !== targetW || mainCanvas.height !== targetH) {
      mainCanvas.width = targetW;
      mainCanvas.height = targetH;
    }
    mainCtx.imageSmoothingEnabled = false;
    mainCtx.clearRect(0, 0, targetW, targetH);
    mainCtx.drawImage(offDiorama, 0, 0, targetW, targetH);

    if (state.splitMode) {
      const splitX = 7 * TILE_PX * z;
      mainCtx.save();
      mainCtx.strokeStyle = "rgba(255, 240, 180, 0.85)";
      mainCtx.lineWidth = Math.max(1, z >= 3 ? 2 : 1);
      mainCtx.setLineDash([6, 5]);
      mainCtx.beginPath();
      mainCtx.moveTo(splitX, 0);
      mainCtx.lineTo(splitX, targetH);
      mainCtx.stroke();
      mainCtx.restore();
    }

    if (state.showGrid) {
      mainCtx.save();
      mainCtx.strokeStyle = "rgba(180, 200, 240, 0.22)";
      mainCtx.lineWidth = 1;
      const step = TILE_PX * z;
      for (let x = 1; x < GRID_W; x++) {
        mainCtx.beginPath(); mainCtx.moveTo(x * step + 0.5, 0); mainCtx.lineTo(x * step + 0.5, targetH); mainCtx.stroke();
      }
      for (let y = 1; y < GRID_H; y++) {
        mainCtx.beginPath(); mainCtx.moveTo(0, y * step + 0.5); mainCtx.lineTo(targetW, y * step + 0.5); mainCtx.stroke();
      }
      mainCtx.restore();
    }

    if (state.hoverTile) {
      const { x, y } = state.hoverTile, step = TILE_PX * z;
      mainCtx.save();
      mainCtx.strokeStyle = "rgba(110, 196, 232, 0.92)";
      mainCtx.lineWidth = 2;
      mainCtx.strokeRect(x * step + 1, y * step + 1, step - 2, step - 2);
      mainCtx.restore();
    }
  }

  function startAnimationLoop(onFrameTick) {
    let lastTickMs = performance.now();
    function rafLoop(now) {
      if (state.playing && now - lastTickMs >= 200) {
        const steps = Math.floor((now - lastTickMs) / 200);
        lastTickMs += steps * 200;
        for (let s = 0; s < steps; s++) state.frameIdx = (state.frameIdx + 1) % 24;
        if (onFrameTick) onFrameTick();
      } else if (!state.playing) {
        lastTickMs = now;
      }
      if (state.activeTab === "diorama") drawMainCanvas();
      requestAnimationFrame(rafLoop);
    }
    requestAnimationFrame(rafLoop);
  }

  window.TerrestrialWorkbench = {
    DATA, GRID_W, GRID_H, TILE_PX,
    NORTH, SOUTH, EAST, WEST, NE, SE, SW, NW,
    JUNCTIONS, J_INDEX, PHASE_LABELS, PICKER_SPECS,
    TERRESTRIAL_ASSETS, EXISTING_ASSETS, ALL_ASSETS, ASSET_MAP,
    LOADED_IMAGES, LOADED_STRIPS,
    BRUSH_CATEGORIES, BRUSHES, BRUSH_MAP,
    SCENE_PRESETS, state, mainCanvas,
    isSmoothKind, isTerrestrialSource,
    sanitizeMask, computeJunction, quadrantBlocks,
    resolveAssetFrame, getTintedCell, drawThumbToCanvas, fillMatBackground,
    preloadAllImages, createEmptyGrid, activeTintBag,
    applyPaintAt, canvasCoordsToTile, renderDiorama1x, drawMainCanvas, startAnimationLoop,
  };
})();
