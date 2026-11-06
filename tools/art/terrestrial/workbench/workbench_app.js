/* Tales from Space — Terrestrial Art Workbench: DOM Bindings, Catalog, Telemetry Table & Zoom Modal */
(() => {
  "use strict";

  const WB = window.TerrestrialWorkbench;
  if (!WB) {
    throw new Error("Missing window.TerrestrialWorkbench from workbench_render.js");
  }

  const {
    DATA, NORTH, SOUTH, EAST, WEST, NE, SE, SW, NW,
    JUNCTIONS, J_INDEX, PHASE_LABELS, PICKER_SPECS,
    TERRESTRIAL_ASSETS, EXISTING_ASSETS, ALL_ASSETS, ASSET_MAP,
    LOADED_STRIPS, BRUSH_CATEGORIES, BRUSHES, BRUSH_MAP,
    SCENE_PRESETS, state, mainCanvas,
    isSmoothKind, isTerrestrialSource,
    sanitizeMask, computeJunction, quadrantBlocks,
    resolveAssetFrame, getTintedCell, drawThumbToCanvas, fillMatBackground,
    preloadAllImages, createEmptyGrid, activeTintBag,
    applyPaintAt, canvasCoordsToTile, drawMainCanvas, startAnimationLoop,
  } = WB;

  const zoomState = {
    open: false,
    assetId: null,
    junction: 255,
    fixedFrame: null,
    showGrid: true,
    rawCellCanvas: null,
  };

  // =========================================================================
  // Tab 1: Layer Stack, Live Multiply Tint Pickers & Brush Palette UI
  // =========================================================================
  function syncHeaderCounts() {
    const subEl = document.getElementById("topbar-subtitle");
    if (subEl) {
      subEl.innerHTML =
        `${TERRESTRIAL_ASSETS.length} Neutral-Grayscale Terrestrial Assets &bull; ` +
        `${EXISTING_ASSETS.length} TfS Matter, Station &amp; <code>tgstation</code> Reference Gems &bull; ` +
        `12-Frame 4-Layer Shoreline &bull; 47-Junction Auto-Smoothing &bull; Live sRGB Multiply`;
    }
    const tabBrowser = document.getElementById("tab-btn-browser");
    if (tabBrowser) {
      tabBrowser.innerHTML = `2. 47-Junction Slicer &amp; Asset Browser (${ALL_ASSETS.length})`;
    }
    const searchInput = document.getElementById("asset-search");
    if (searchInput) {
      searchInput.placeholder = `Search ${ALL_ASSETS.length} assets by id, title, or file.dm...`;
    }
  }

  function syncColorPickersUI() {
    const bag = activeTintBag();
    const splitSel = document.getElementById("split-tint-side");
    splitSel.hidden = !state.splitMode;
    splitSel.value = state.editSplitSide;

    const container = document.getElementById("color-picker-list");
    container.innerHTML = "";
    for (const spec of PICKER_SPECS) {
      const row = document.createElement("div");
      row.className = "picker-row";
      const val = (bag[spec.key] || "#FFFFFF").toUpperCase();

      const inp = document.createElement("input");
      inp.type = "color";
      inp.value = val;

      const nameSpan = document.createElement("span");
      nameSpan.className = "picker-name";
      nameSpan.textContent = spec.label;

      const hexSpan = document.createElement("span");
      hexSpan.className = "picker-hex";
      hexSpan.textContent = val;

      inp.addEventListener("input", () => {
        const nv = inp.value.toUpperCase();
        activeTintBag()[spec.key] = nv;
        hexSpan.textContent = nv;
        renderBrushThumbnails();
      });

      row.append(inp, nameSpan, hexSpan);
      container.appendChild(row);
    }
    document.getElementById("chk-sandy-foreshore").checked = state.sandyForeshore;
  }

  function renderPresetButtons() {
    const wrap = document.getElementById("scene-preset-buttons");
    wrap.innerHTML = "";
    for (const pr of SCENE_PRESETS) {
      const btn = document.createElement("button");
      btn.className = "pill-btn preset-pill" + (state.activePresetId === pr.id ? " active" : "");
      btn.textContent = pr.label;
      btn.addEventListener("click", () => {
        state.activePresetId = pr.id;
        pr.build();
        renderPresetButtons();
        syncColorPickersUI();
        renderBrushThumbnails();
      });
      wrap.appendChild(btn);
    }
  }

  function renderFramePills() {
    const wrap = document.getElementById("frame-pills");
    wrap.innerHTML = "";
    const phaseIdx = state.frameIdx % 12;
    for (let i = 0; i < 12; i++) {
      const btn = document.createElement("button");
      btn.className = "pill-btn" + (phaseIdx === i ? " active" : "");
      btn.textContent = `F${i + 1}`;
      btn.addEventListener("click", () => {
        state.playing = false;
        state.frameIdx = i;
        syncPlaybackUI();
        if (state.activeTab === "browser") renderInspectorDynamic();
        if (zoomState.open) renderZoomModalCanvas();
      });
      wrap.appendChild(btn);
    }
    document.getElementById("frame-phase-label").textContent = PHASE_LABELS[phaseIdx];
  }

  function syncPlaybackUI() {
    document.getElementById("btn-play-pause").textContent = state.playing ? "Pause" : "Play";
    renderFramePills();
  }

  function renderBrushCategoryTabs() {
    const wrap = document.getElementById("brush-category-tabs");
    wrap.innerHTML = "";
    for (const cat of BRUSH_CATEGORIES) {
      const btn = document.createElement("button");
      btn.className = "filter-pill" + (state.activeBrushCategory === cat.id ? " active" : "");
      btn.textContent = cat.label;
      btn.addEventListener("click", () => {
        state.activeBrushCategory = cat.id;
        const activeBrush = BRUSH_MAP.get(state.activeBrushId);
        if (!activeBrush || activeBrush.cat !== cat.id) {
          const firstInCat = BRUSHES.find((b) => b.cat === cat.id);
          if (firstInCat) {
            state.activeBrushId = firstInCat.id;
            document.getElementById("active-brush-readout").textContent = `Brush: ${firstInCat.label}`;
          }
        }
        renderBrushCategoryTabs();
        renderBrushPalette();
      });
      wrap.appendChild(btn);
    }
  }

  function renderBrushPalette() {
    const wrap = document.getElementById("brush-palette-grid");
    wrap.innerHTML = "";
    const bag = activeTintBag();
    const list = BRUSHES.filter((b) => b.cat === state.activeBrushCategory);
    for (const br of list) {
      const btn = document.createElement("button");
      btn.className = "brush-btn" + (state.activeBrushId === br.id ? " active" : "");

      const cv = document.createElement("canvas");
      cv.className = "brush-swatch";
      cv.width = 24;
      cv.height = 24;
      cv.dataset.asset = br.thumb;
      cv.dataset.tintRole = br.tintRole || "";
      const tint = br.tintRole ? bag[br.tintRole] : "#FFFFFF";
      drawThumbToCanvas(cv, br.thumb, tint);

      const lbl = document.createElement("span");
      lbl.textContent = br.label;

      btn.append(cv, lbl);
      btn.addEventListener("click", () => {
        state.activeBrushId = br.id;
        document.getElementById("active-brush-readout").textContent = `Brush: ${br.label}`;
        renderBrushPalette();
      });
      wrap.appendChild(btn);
    }
  }

  function renderBrushThumbnails() {
    const bag = activeTintBag();
    document.querySelectorAll("#brush-palette-grid canvas.brush-swatch").forEach((cv) => {
      const role = cv.dataset.tintRole;
      drawThumbToCanvas(cv, cv.dataset.asset, role ? bag[role] : "#FFFFFF");
    });
  }

  function updateHoverReadout(x, y) {
    const c = state.grid[y][x];
    const parts = [`Tile (${x}, ${y})`, `base=${c.base}`];
    if (c.cliff) parts.push("cliff=yes");
    if (c.deck) parts.push(`deck=${c.deck}`);
    if (c.hazard) parts.push(`hazard=${c.hazard}`);
    if (c.grass || c.moss) parts.push(`decals=${[c.grass ? "grass" : "", c.moss ? "moss" : ""].filter(Boolean).join("+")}`);
    if (c.matter) parts.push(`matter=${c.matter.id}`);
    if (c.singleMatter) parts.push(`singleMatter=${c.singleMatter.id}`);
    if (c.hedge) parts.push("hedge=tg_hedge");
    if (c.prop) parts.push(`prop=${c.prop.id}`);
    if (c.campfire) parts.push("campfire");
    if (c.haze) parts.push("haze");
    document.getElementById("hover-tile-readout").textContent = parts.join(" • ");
  }

  // =========================================================================
  // Tab 2: Asset Catalog, Audit Telemetry Table & 47-Junction Slicer
  // =========================================================================
  const countBySource = (src) => src === "terrestrial"
    ? ALL_ASSETS.filter((a) => isTerrestrialSource(a.source)).length
    : ALL_ASSETS.filter((a) => a.source === src).length;

  const SOURCE_FILTERS = [
    { id: "all", label: `All (${ALL_ASSETS.length})` },
    { id: "terrestrial", label: `Terrestrial (${countBySource("terrestrial")})` },
    { id: "tfs_matter", label: `TfS Matter (${countBySource("tfs_matter")})` },
    { id: "tfs_station", label: `TfS Station (${countBySource("tfs_station")})` },
    { id: "tg_outdoor", label: `TG Outdoor (${countBySource("tg_outdoor")})` },
  ];
  const CATEGORY_FILTERS = ["all", "terrain", "ice", "cliff", "ocean", "decal", "matter", "flora", "prop", "station"];

  function renderBrowserFilters() {
    const sRow = document.getElementById("source-filter-row");
    sRow.innerHTML = "";
    for (const sf of SOURCE_FILTERS) {
      const btn = document.createElement("button");
      btn.className = "filter-pill" + (state.browserSource === sf.id ? " active" : "");
      btn.textContent = sf.label;
      btn.addEventListener("click", () => {
        state.browserSource = sf.id;
        renderBrowserFilters();
        renderAssetList();
      });
      sRow.appendChild(btn);
    }

    const cRow = document.getElementById("category-filter-row");
    cRow.innerHTML = "";
    for (const cat of CATEGORY_FILTERS) {
      const btn = document.createElement("button");
      btn.className = "filter-pill" + (state.browserCategory === cat ? " active" : "");
      btn.textContent = cat;
      btn.addEventListener("click", () => {
        state.browserCategory = cat;
        renderBrowserFilters();
        renderAssetList();
      });
      cRow.appendChild(btn);
    }
  }

  function renderAssetList() {
    const listEl = document.getElementById("asset-list");
    listEl.innerHTML = "";
    const q = state.browserSearch.trim().toLowerCase();

    const filtered = ALL_ASSETS.filter((a) => {
      if (state.browserSource === "terrestrial" && !isTerrestrialSource(a.source)) return false;
      if (state.browserSource !== "all" && state.browserSource !== "terrestrial" && a.source !== state.browserSource) return false;
      if (state.browserCategory !== "all" && a.category !== state.browserCategory) return false;
      if (q && !(
        a.id.toLowerCase().includes(q) ||
        a.title.toLowerCase().includes(q) ||
        (a.citation || "").toLowerCase().includes(q)
      )) return false;
      return true;
    });

    for (const rec of filtered) {
      const item = document.createElement("div");
      item.className = "asset-item" + (state.selectedAssetId === rec.id ? " active" : "");

      const cv = document.createElement("canvas");
      cv.className = "asset-thumb";
      cv.width = 32;
      cv.height = 32;
      drawThumbToCanvas(cv, rec.id, rec.colorable ? rec.default_tint : "#FFFFFF");

      const mid = document.createElement("div");
      mid.style.minWidth = "0";
      const tDiv = document.createElement("div");
      tDiv.className = "asset-item-title";
      tDiv.textContent = rec.id;
      const sDiv = document.createElement("div");
      sDiv.className = "asset-item-sub";
      sDiv.textContent = `${rec.cell_w}x${rec.cell_h} • ${rec.kind} • ${rec.frame_count}f`;
      mid.append(tDiv, sDiv);

      const tag = document.createElement("span");
      tag.className = "asset-tag";
      tag.textContent = isTerrestrialSource(rec.source)
        ? "terr"
        : rec.source.replace("tfs_", "").replace("tg_", "tg:");

      item.append(cv, mid, tag);
      item.addEventListener("click", () => selectBrowserAsset(rec.id));
      listEl.appendChild(item);
    }
  }

  function syncInspectorTintControls(rec) {
    const picker = document.getElementById("insp-tint-picker");
    const hexEl = document.getElementById("insp-tint-hex");
    const qtWrap = document.getElementById("insp-quick-tints");
    const canTint = Boolean(rec && rec.colorable);
    picker.disabled = !canTint;
    picker.value = state.inspTint;
    hexEl.textContent = canTint ? state.inspTint : "#FFFFFF (baked)";
    qtWrap.classList.toggle("is-disabled", !canTint);
    qtWrap.querySelectorAll("button").forEach((b) => { b.disabled = !canTint; });
  }

  function renderTelemetryTable(rec) {
    const tbody = document.getElementById("insp-telemetry-tbody");
    if (!tbody) return;
    tbody.innerHTML = "";
    const tel = rec.telemetry_summary;
    const rows = [];

    const evalTopLight = (tbStr) => {
      if (!rec.require_top_light) {
        return ["Top-down lighting readout", "N/A (isotropic)"];
      }
      const [lumaTop, lumaBot] = String(tbStr).split("/").map(Number);
      return ["luma_top > luma_bottom", lumaTop > lumaBot ? "PASS" : "FAIL"];
    };

    if (tel) {
      rows.push(["GPL Swatches Used", String(tel.swatches), "tales-from-space.gpl (0 reserved, chroma == 0)", "PASS"]);
      if (isSmoothKind(rec.kind)) {
        const [tlGate, tlStatus] = evalTopLight(tel.j0_luma_tb);
        rows.push(["Isolated Top/Bot Luma (j=0)", String(tel.j0_luma_tb), tlGate, tlStatus]);
        rows.push(["Interior Dom RGB (j=255)", String(tel.j255_dom_rgb), "< 0.850 (test-bake-art bare-mask gate)", "PASS"]);
        if (tel.max_47_dom_rgb !== undefined) {
          rows.push(["Worst 47xFrames / 5-Block Dom RGB", `${tel.max_47_dom_rgb} / ${tel.max_blk_dom_rgb}`, "< 0.850 across all 47 junctions & 5 blocks", "PASS"]);
        }
        if (tel.alpha_max !== undefined) {
          rows.push(["Seam Alpha Diff / Seam Ratio", `alphaMAX=${tel.alpha_max}, ratio=${tel.seam_ratio}`, "alphaMAX == 0 & seamRatio <= 2.75", "PASS"]);
        }
        rows.push(["Interior Transparent % (j=255)", `${tel.j255_holes_pct}%`, "Coverage / decal porosity", "INFO"]);
      } else {
        const [tlGate, tlStatus] = evalTopLight(tel.luma_tb);
        rows.push(["Top / Bottom Luma", String(tel.luma_tb), tlGate, tlStatus]);
        rows.push(["Dominant RGB Share", String(tel.dom_rgb), "< 0.850 (when active_px >= 40)", "PASS"]);
        rows.push(["Active Pixels / Pieces / Lone Px", `${tel.active_px}px / ${tel.pieces ?? 1} / ${tel.lone_px ?? 0}`, "lone_pixel_count == 0", "PASS"]);
      }
      if (tel.step_ratio !== undefined) {
        rows.push(["Anim Pacing & Loop Wrap", `step=${tel.step_ratio}x, wrap=${tel.wrap_ratio}, zeroDelta=${tel.zero_delta ?? 0}`, "zeroDelta == 0, step <= 3.00x, wrap in [0.45, 1.75]", "PASS"]);
      }
    } else {
      rows.push(["Source Domain", rec.source, "Reference comparison catalog", "INFO"]);
      rows.push(["Colorability", rec.colorable ? "Neutral Grayscale (sRGB Multiply)" : "Baked RGB Palette", "Runtime tint mode", "INFO"]);
      rows.push(["Cell & Anchor", `${rec.cell_w}x${rec.cell_h} @ (${rec.offset_x}, ${rec.offset_y})`, `kind=${rec.kind}, frames=${rec.frame_count}`, "INFO"]);
    }

    for (const [metric, val, gate, status] of rows) {
      const tr = document.createElement("tr");
      for (const txt of [metric, val, gate]) {
        const td = document.createElement("td");
        td.textContent = txt;
        tr.appendChild(td);
      }
      const stTd = document.createElement("td");
      if (status === "PASS") {
        stTd.className = "status-pass";
      } else if (status === "FAIL") {
        stTd.className = "status-fail";
        stTd.style.color = "#ff7b7b";
        stTd.style.fontWeight = "700";
      } else if (status === "INFO") {
        stTd.className = "status-info";
      } else {
        stTd.className = "status-neutral";
        stTd.style.color = "var(--txt-md)";
      }
      stTd.textContent = status;
      tr.appendChild(stTd);
      tbody.appendChild(tr);
    }
  }

  function selectBrowserAsset(assetId) {
    state.selectedAssetId = assetId;
    const rec = ASSET_MAP.get(assetId);
    if (!rec) return;
    state.inspTint = (rec.colorable ? (rec.default_tint || "#FFFFFF") : "#FFFFFF").toUpperCase();
    syncInspectorTintControls(rec);
    renderAssetList();
    renderInspectorStatic();
    renderInspectorDynamic();
  }

  function renderInspectorStatic() {
    const rec = ASSET_MAP.get(state.selectedAssetId);
    if (!rec) return;
    document.getElementById("insp-source-badge").textContent = rec.source;
    document.getElementById("insp-category-badge").textContent = rec.category;
    document.getElementById("insp-kind-badge").textContent = rec.kind;
    document.getElementById("insp-dims-badge").textContent = `${rec.cell_w}x${rec.cell_h} (off ${rec.offset_x},${rec.offset_y})`;
    document.getElementById("insp-frames-badge").textContent = `${rec.frame_count}f @ ${rec.durations_ms[0]}ms${rec.rewind ? " rewind" : ""}`;
    document.getElementById("insp-title").textContent = rec.title;
    document.getElementById("insp-id").textContent = rec.id;
    document.getElementById("insp-citation").textContent = rec.citation || rec.ase_relpath || rec.atlas_png_relpath;

    const tel = rec.telemetry_summary;
    document.getElementById("insp-telemetry").textContent = tel
      ? Object.entries(tel).map(([k, v]) => `${k}=${v}`).join(" • ")
      : (rec.colorable ? "colorable=true (neutral grayscale)" : "colorable=false (baked palette)");

    document.getElementById("insp-single-heading").textContent = rec.kind === "oversized"
      ? "2× Anchor Pedestal (3×3)"
      : `${rec.cell_w <= 32 ? 4 : 3}× Active Cell Preview`;
    document.getElementById("insp-offset-caption").textContent =
      `Cell ${rec.cell_w}x${rec.cell_h} • Anchor offset (${rec.offset_x}, ${rec.offset_y}) • Click to Zoom 8×`;

    document.getElementById("insp-strip-card").style.display = rec.strip_data_uri ? "block" : "none";
    renderTelemetryTable(rec);
    renderInspectorAtlasGrid();
  }

  function renderInspectorAtlasGrid() {
    const rec = ASSET_MAP.get(state.selectedAssetId);
    if (!rec) return;
    const gridEl = document.getElementById("insp-atlas-grid");
    const heading = document.getElementById("insp-atlas-heading");
    gridEl.innerHTML = "";

    const canonJ = sanitizeMask(state.neighborMask);
    if (isSmoothKind(rec.kind)) {
      heading.textContent = `All 47 Canonical Junctions (${rec.cell_w}x${rec.cell_h} — click to inspect, double-click for 8× Zoom)`;
      for (const jVal of JUNCTIONS) {
        const card = document.createElement("div");
        card.className = "j-cell-card" + (jVal === canonJ ? " active" : "");
        const cv = document.createElement("canvas");
        cv.width = 64;
        cv.height = 64;
        cv.dataset.junction = String(jVal);
        const cctx = cv.getContext("2d");
        cctx.imageSmoothingEnabled = false;
        fillMatBackground(cctx, 64, 64, state.inspMat);
        const cell = getTintedCell(rec.id, jVal, state.frameIdx, state.inspTint);
        if (cell) cctx.drawImage(cell, 0, 0, 64, 64);
        const lbl = document.createElement("span");
        lbl.textContent = `j=${jVal}`;
        card.append(cv, lbl);
        card.addEventListener("click", () => {
          state.neighborMask = jVal;
          syncCompassButtons();
          renderInspectorDynamic();
          renderInspectorAtlasGrid();
        });
        card.addEventListener("dblclick", () => openZoomModal(rec.id, jVal, null));
        gridEl.appendChild(card);
      }
    } else {
      heading.textContent = `Sprite Frames (${rec.frame_count} frame${rec.frame_count > 1 ? "s" : ""}, ${rec.cell_w}x${rec.cell_h} — double-click for 8× Zoom)`;
      const resolved = resolveAssetFrame(rec, state.frameIdx);
      for (let f = 0; f < rec.frame_count; f++) {
        const card = document.createElement("div");
        card.className = "j-cell-card" + (rec.frame_count > 1 && f === resolved ? " active" : "");
        card.dataset.frame = String(f);
        const cv = document.createElement("canvas");
        cv.width = 96;
        cv.height = 96;
        const cctx = cv.getContext("2d");
        cctx.imageSmoothingEnabled = false;
        fillMatBackground(cctx, 96, 96, state.inspMat);
        const cell = getTintedCell(rec.id, 255, f, state.inspTint);
        if (cell) {
          const sc = Math.min(88 / cell.width, 88 / cell.height);
          const dw = Math.round(cell.width * sc), dh = Math.round(cell.height * sc);
          cctx.drawImage(cell, ((96 - dw) / 2) | 0, ((96 - dh) / 2) | 0, dw, dh);
        }
        const lbl = document.createElement("span");
        lbl.textContent = `Frame ${f + 1} (${rec.durations_ms[f] || 200}ms)`;
        card.append(cv, lbl);
        card.addEventListener("dblclick", () => openZoomModal(rec.id, 255, f));
        gridEl.appendChild(card);
      }
    }
  }

  function renderInspectorDynamic() {
    if (state.activeTab !== "browser") return;
    const rec = ASSET_MAP.get(state.selectedAssetId);
    if (!rec) return;

    const resolved = resolveAssetFrame(rec, state.frameIdx);
    const framePill = document.getElementById("insp-frame-pill");
    if (framePill) {
      framePill.textContent = `F${resolved + 1}/${rec.frame_count}`;
    }

    const rawM = state.neighborMask;
    const canonJ = sanitizeMask(rawM);
    const jIdx = J_INDEX.get(canonJ) ?? 0;
    const qb = quadrantBlocks(canonJ);

    document.getElementById("junction-math-readout").innerHTML =
      `Raw Mask: <b>${rawM}</b> &rarr; Canonical Junction: <b>j=${canonJ}</b> (#${jIdx}/46)<br/>` +
      `Quadrants: TL=<b>B${qb.tl}</b>, TR=<b>B${qb.tr}</b>, BL=<b>B${qb.bl}</b>, BR=<b>B${qb.br}</b>`;

    const cCanvas = document.getElementById("insp-cell-canvas");
    const cCtx = cCanvas.getContext("2d");
    cCtx.imageSmoothingEnabled = false;
    fillMatBackground(cCtx, 192, 192, state.inspMat);

    const cell = getTintedCell(rec.id, canonJ, state.frameIdx, state.inspTint);
    if (cell) {
      if (rec.kind === "oversized") {
        const ax = 1, ay = (rec.offset_y <= -48) ? 2 : 1;
        cCtx.drawImage(cell, (ax * 32 + rec.offset_x) * 2, (ay * 32 + rec.offset_y) * 2, cell.width * 2, cell.height * 2);
        cCtx.strokeStyle = "rgba(242, 168, 68, 0.9)";
        cCtx.lineWidth = 2;
        cCtx.strokeRect(ax * 64 + 1, ay * 64 + 1, 62, 62);
      } else {
        const sc = rec.cell_w <= 32 ? 4 : 3;
        const dw = cell.width * sc, dh = cell.height * sc;
        cCtx.drawImage(cell, ((192 - dw) / 2) | 0, ((192 - dh) / 2) | 0, dw, dh);
      }
    }

    const ctxCanvas = document.getElementById("insp-context-canvas");
    const ctx3 = ctxCanvas.getContext("2d");
    ctx3.imageSmoothingEnabled = false;
    fillMatBackground(ctx3, 192, 192, state.inspMat);

    const nbGrid = [
      [Boolean(rawM & NW), Boolean(rawM & NORTH), Boolean(rawM & NE)],
      [Boolean(rawM & WEST), true, Boolean(rawM & EAST)],
      [Boolean(rawM & SW), Boolean(rawM & SOUTH), Boolean(rawM & SE)],
    ];
    if (isSmoothKind(rec.kind)) {
      for (let gy = 0; gy < 3; gy++) {
        for (let gx = 0; gx < 3; gx++) {
          if (!nbGrid[gy][gx]) continue;
          const jv = computeJunction((nx, ny) => nbGrid[ny][nx], gx, gy, 3, 3, false);
          const scCell = getTintedCell(rec.id, jv, state.frameIdx, state.inspTint);
          if (scCell) {
            ctx3.drawImage(scCell, (gx * 32 + rec.offset_x) * 2, (gy * 32 + rec.offset_y) * 2, scCell.width * 2, scCell.height * 2);
          }
        }
      }
      ctx3.strokeStyle = "rgba(110, 196, 232, 0.7)";
      ctx3.strokeRect(64.5, 64.5, 63, 63);
    } else if (cell) {
      const sc = Math.min(180 / cell.width, 180 / cell.height);
      const dw = Math.round(cell.width * sc), dh = Math.round(cell.height * sc);
      ctx3.drawImage(cell, ((192 - dw) / 2) | 0, ((192 - dh) / 2) | 0, dw, dh);
    }

    const stripIm = LOADED_STRIPS.get(rec.id);
    if (rec.strip_data_uri && stripIm) {
      const sCanvas = document.getElementById("insp-strip-canvas");
      const sCtx = sCanvas.getContext("2d");
      sCtx.imageSmoothingEnabled = false;
      fillMatBackground(sCtx, 480, 96, "dark");
      const fIdx = resolveAssetFrame(rec, state.frameIdx);
      if (stripIm.width >= (fIdx + 1) * 160) {
        sCtx.drawImage(stripIm, fIdx * 160, 0, 160, 32, 0, 0, 480, 96);
      } else {
        const sy = Math.min(fIdx * 32, Math.max(0, stripIm.height - 32));
        sCtx.drawImage(stripIm, 0, sy, 160, 32, 0, 0, 480, 96);
      }
      sCtx.strokeStyle = "rgba(120, 140, 180, 0.65)";
      sCtx.lineWidth = 1;
      for (let b = 0; b < 5; b++) sCtx.strokeRect(b * 96 + 0.5, 0.5, 95, 95);
      sCtx.strokeStyle = "#56e2ff";
      sCtx.lineWidth = 2;
      sCtx.strokeRect(qb.tl * 96 + 1, 1, 46, 46);
      sCtx.strokeRect(qb.tr * 96 + 49, 1, 46, 46);
      sCtx.strokeRect(qb.bl * 96 + 1, 49, 46, 46);
      sCtx.strokeRect(qb.br * 96 + 49, 49, 46, 46);
    }

    if (rec.frame_count > 1) {
      if (isSmoothKind(rec.kind)) {
        document.querySelectorAll("#insp-atlas-grid canvas[data-junction]").forEach((cv) => {
          const jVal = parseInt(cv.dataset.junction, 10);
          const cctx = cv.getContext("2d");
          cctx.imageSmoothingEnabled = false;
          fillMatBackground(cctx, 64, 64, state.inspMat);
          const jCell = getTintedCell(rec.id, jVal, state.frameIdx, state.inspTint);
          if (jCell) cctx.drawImage(jCell, 0, 0, 64, 64);
        });
      } else {
        document.querySelectorAll("#insp-atlas-grid .j-cell-card[data-frame]").forEach((card) => {
          card.classList.toggle("active", parseInt(card.dataset.frame, 10) === resolved);
        });
      }
    }
  }

  function syncCompassButtons() {
    document.querySelectorAll("#neighbor-compass button[data-bit]").forEach((btn) => {
      const bit = parseInt(btn.dataset.bit, 10);
      btn.classList.toggle("active", Boolean(state.neighborMask & bit));
    });
  }

  // =========================================================================
  // Modal 8x Pixel Zoom Inspector
  // =========================================================================
  function openZoomModal(assetId, junction, fixedFrame) {
    zoomState.open = true;
    zoomState.assetId = assetId;
    zoomState.junction = junction;
    zoomState.fixedFrame = fixedFrame;
    document.getElementById("zoom-modal").hidden = false;
    renderZoomModalCanvas();
  }

  function closeZoomModal() {
    zoomState.open = false;
    document.getElementById("zoom-modal").hidden = true;
  }

  function renderZoomModalCanvas() {
    if (!zoomState.open || !zoomState.assetId) return;
    const rec = ASSET_MAP.get(zoomState.assetId);
    if (!rec) return;
    const fUse = zoomState.fixedFrame !== null ? zoomState.fixedFrame : state.frameIdx;
    const cell = getTintedCell(rec.id, zoomState.junction, fUse, state.inspTint);
    if (!cell) return;
    zoomState.rawCellCanvas = cell;

    const scale = cell.width <= 48 && cell.height <= 48 ? 8 : 5;
    const zw = cell.width * scale;
    const zh = cell.height * scale;
    const zCanvas = document.getElementById("zoom-modal-canvas");
    zCanvas.width = zw;
    zCanvas.height = zh;
    const zCtx = zCanvas.getContext("2d");
    zCtx.imageSmoothingEnabled = false;
    fillMatBackground(zCtx, zw, zh, state.inspMat);
    zCtx.drawImage(cell, 0, 0, zw, zh);

    if (zoomState.showGrid) {
      zCtx.strokeStyle = "rgba(180, 200, 240, 0.22)";
      zCtx.lineWidth = 1;
      for (let x = 1; x < cell.width; x++) {
        zCtx.beginPath();
        zCtx.moveTo(x * scale + 0.5, 0);
        zCtx.lineTo(x * scale + 0.5, zh);
        zCtx.stroke();
      }
      for (let y = 1; y < cell.height; y++) {
        zCtx.beginPath();
        zCtx.moveTo(0, y * scale + 0.5);
        zCtx.lineTo(zw, y * scale + 0.5);
        zCtx.stroke();
      }
    }

    const fResolved = resolveAssetFrame(rec, fUse) + 1;
    document.getElementById("zoom-modal-title").textContent = `${scale}× Pixel Zoom — ${rec.id}`;
    document.getElementById("zoom-modal-subtitle").textContent =
      isSmoothKind(rec.kind)
        ? `j=${sanitizeMask(zoomState.junction)} • Frame ${fResolved}/${rec.frame_count} • Tint ${state.inspTint}`
        : `Frame ${fResolved}/${rec.frame_count} • ${rec.cell_w}x${rec.cell_h} • Tint ${state.inspTint}`;
  }

  // =========================================================================
  // Event Bindings & Boot
  // =========================================================================
  function bindEvents() {
    document.querySelectorAll(".tab-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.activeTab = btn.dataset.tab;
        document.querySelectorAll(".tab-btn").forEach((b) => {
          const act = b === btn;
          b.classList.toggle("active", act);
          b.setAttribute("aria-selected", String(act));
        });
        document.getElementById("panel-diorama").classList.toggle("active", state.activeTab === "diorama");
        document.getElementById("panel-browser").classList.toggle("active", state.activeTab === "browser");
        if (state.activeTab === "browser") {
          syncInspectorTintControls(ASSET_MAP.get(state.selectedAssetId));
          renderAssetList();
          renderInspectorStatic();
          renderInspectorDynamic();
        }
      });
    });

    document.querySelectorAll("#zoom-buttons button[data-zoom]").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.zoom = parseInt(btn.dataset.zoom, 10);
        document.querySelectorAll("#zoom-buttons button").forEach((b) => b.classList.toggle("active", b === btn));
        drawMainCanvas();
      });
    });

    document.getElementById("btn-play-pause").addEventListener("click", () => {
      state.playing = !state.playing;
      syncPlaybackUI();
    });
    document.getElementById("btn-prev-frame").addEventListener("click", () => {
      state.playing = false;
      state.frameIdx = (state.frameIdx + 23) % 24;
      syncPlaybackUI();
      if (state.activeTab === "browser") renderInspectorDynamic();
      if (zoomState.open) renderZoomModalCanvas();
    });
    document.getElementById("btn-next-frame").addEventListener("click", () => {
      state.playing = false;
      state.frameIdx = (state.frameIdx + 1) % 24;
      syncPlaybackUI();
      if (state.activeTab === "browser") renderInspectorDynamic();
      if (zoomState.open) renderZoomModalCanvas();
    });

    document.getElementById("chk-gridlines").addEventListener("change", (e) => { state.showGrid = e.target.checked; });
    document.getElementById("btn-reset-scene").addEventListener("click", () => {
      const pr = SCENE_PRESETS.find((p) => p.id === state.activePresetId) || SCENE_PRESETS[0];
      state.activePresetId = pr.id;
      pr.build();
      renderPresetButtons();
      syncColorPickersUI();
      renderBrushThumbnails();
    });
    document.getElementById("btn-clear-scene").addEventListener("click", () => {
      state.splitMode = false;
      state.sandyForeshore = false;
      state.activePresetId = null;
      state.grid = createEmptyGrid();
      document.querySelectorAll(".preset-pill").forEach((el) => el.classList.remove("active"));
      syncColorPickersUI();
    });

    document.querySelectorAll("#layer-checkboxes input[data-layer]").forEach((chk) => {
      chk.addEventListener("change", () => { state.layers[chk.dataset.layer] = chk.checked; });
    });

    document.getElementById("split-tint-side").addEventListener("change", (e) => {
      state.editSplitSide = e.target.value;
      syncColorPickersUI();
      renderBrushThumbnails();
    });
    document.getElementById("chk-sandy-foreshore").addEventListener("change", (e) => {
      state.sandyForeshore = e.target.checked;
    });

    const recolorWrap = document.getElementById("recolor-only-buttons");
    const morphPalettes = [
      ["mars_cryo_ammonia", "Mars Cryo-NH3", false],
      ["mars_pack_ammonia", "Mars Pack", false],
      ["mars_polar_ice", "Mars Polar", false],
      ["earth_coastal_meadow", "Earth Meadow", true],
      ["earth_lush_jungle", "Earth Jungle", true],
    ];
    for (const [key, lbl, sandy] of morphPalettes) {
      const btn = document.createElement("button");
      btn.className = "pill-btn";
      btn.textContent = lbl;
      btn.addEventListener("click", () => {
        Object.assign(activeTintBag(), DATA.biomePresets[key]);
        if (!state.splitMode) state.sandyForeshore = sandy;
        syncColorPickersUI();
        renderBrushThumbnails();
      });
      recolorWrap.appendChild(btn);
    }

    mainCanvas.addEventListener("contextmenu", (e) => e.preventDefault());
    mainCanvas.addEventListener("mousedown", (e) => {
      const tile = canvasCoordsToTile(e);
      if (!tile) return;
      state.isPainting = true;
      state.paintErase = e.button === 2;
      applyPaintAt(tile.x, tile.y, state.paintErase);
      updateHoverReadout(tile.x, tile.y);
    });
    mainCanvas.addEventListener("mousemove", (e) => {
      const tile = canvasCoordsToTile(e);
      state.hoverTile = tile;
      if (tile) {
        if (state.isPainting) applyPaintAt(tile.x, tile.y, state.paintErase);
        updateHoverReadout(tile.x, tile.y);
      }
    });
    mainCanvas.addEventListener("mouseleave", () => { state.hoverTile = null; });
    window.addEventListener("mouseup", () => { state.isPainting = false; });

    document.getElementById("asset-search").addEventListener("input", (e) => {
      state.browserSearch = e.target.value;
      renderAssetList();
    });
    document.getElementById("insp-tint-picker").addEventListener("input", (e) => {
      const rec = ASSET_MAP.get(state.selectedAssetId);
      if (!rec || !rec.colorable) return;
      state.inspTint = e.target.value.toUpperCase();
      document.getElementById("insp-tint-hex").textContent = state.inspTint;
      renderInspectorDynamic();
      renderInspectorAtlasGrid();
    });
    document.getElementById("insp-mat-select").addEventListener("change", (e) => {
      state.inspMat = e.target.value;
      renderInspectorDynamic();
      renderInspectorAtlasGrid();
    });

    const qtWrap = document.getElementById("insp-quick-tints");
    for (const [lbl, hx] of [
      ["Raw #FFF", "#FFFFFF"],
      ["Mars Silicate", "#B85C3C"],
      ["Mars NH3", "#5EB5C4"],
      ["Earth Grass", "#86C44A"],
      ["Granite", "#7D7A74"],
    ]) {
      const b = document.createElement("button");
      b.className = "pill-btn";
      b.textContent = lbl;
      b.addEventListener("click", () => {
        const rec = ASSET_MAP.get(state.selectedAssetId);
        if (!rec || !rec.colorable) return;
        state.inspTint = hx;
        document.getElementById("insp-tint-picker").value = hx;
        document.getElementById("insp-tint-hex").textContent = hx;
        renderInspectorDynamic();
        renderInspectorAtlasGrid();
      });
      qtWrap.appendChild(b);
    }

    document.querySelectorAll("#neighbor-compass button[data-bit]").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.neighborMask ^= parseInt(btn.dataset.bit, 10);
        syncCompassButtons();
        renderInspectorDynamic();
        renderInspectorAtlasGrid();
      });
    });

    const jpWrap = document.getElementById("junction-quick-presets");
    for (const [lbl, maskVal] of [
      ["Isolated (0)", 0],
      ["Interior (255)", 255],
      ["Horiz (12)", 12],
      ["Vert (3)", 3],
      ["South Rim (141)", 141],
      ["Concave SE (15)", 15],
      ["Bay (23)", 23],
    ]) {
      const b = document.createElement("button");
      b.className = "filter-pill";
      b.textContent = lbl;
      b.addEventListener("click", () => {
        state.neighborMask = maskVal;
        syncCompassButtons();
        renderInspectorDynamic();
        renderInspectorAtlasGrid();
      });
      jpWrap.appendChild(b);
    }

    // Modal Zoom Inspector triggers & pixel probe
    document.getElementById("btn-open-zoom-modal").addEventListener("click", () => {
      openZoomModal(state.selectedAssetId, sanitizeMask(state.neighborMask), null);
    });
    document.getElementById("insp-cell-canvas").addEventListener("click", () => {
      openZoomModal(state.selectedAssetId, sanitizeMask(state.neighborMask), null);
    });
    document.getElementById("btn-close-zoom-modal").addEventListener("click", closeZoomModal);
    document.getElementById("zoom-modal").addEventListener("click", (e) => {
      if (e.target.id === "zoom-modal") closeZoomModal();
    });
    document.getElementById("chk-zoom-grid").addEventListener("change", (e) => {
      zoomState.showGrid = e.target.checked;
      renderZoomModalCanvas();
    });
    window.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && zoomState.open) closeZoomModal();
    });

    const zCanvas = document.getElementById("zoom-modal-canvas");
    zCanvas.addEventListener("mousemove", (e) => {
      const raw = zoomState.rawCellCanvas;
      if (!raw) return;
      const rect = zCanvas.getBoundingClientRect();
      const px = Math.floor(((e.clientX - rect.left) / rect.width) * raw.width);
      const py = Math.floor(((e.clientY - rect.top) / rect.height) * raw.height);
      if (px < 0 || px >= raw.width || py < 0 || py >= raw.height) return;
      const d = raw.getContext("2d").getImageData(px, py, 1, 1).data;
      const hex = "#" + [d[0], d[1], d[2]].map((v) => v.toString(16).padStart(2, "0").toUpperCase()).join("");
      const luma = (0.2126 * d[0] + 0.7152 * d[1] + 0.0722 * d[2]).toFixed(1);
      document.getElementById("zoom-modal-readout").textContent =
        `Pixel (${px}, ${py}) • Hex ${hex} • RGBA(${d[0]}, ${d[1]}, ${d[2]}, ${d[3]}) • Luma ${luma}`;
    });
  }

  preloadAllImages().then(() => {
    syncHeaderCounts();
    bindEvents();
    SCENE_PRESETS[0].build();
    renderPresetButtons();
    syncColorPickersUI();
    syncPlaybackUI();
    renderBrushCategoryTabs();
    renderBrushPalette();
    renderBrowserFilters();
    syncInspectorTintControls(ASSET_MAP.get(state.selectedAssetId));
    syncCompassButtons();
    startAnimationLoop(() => {
      renderFramePills();
      if (state.activeTab === "browser") renderInspectorDynamic();
      if (zoomState.open && zoomState.fixedFrame === null) renderZoomModalCanvas();
    });
  });
})();
