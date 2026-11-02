let renderScheduled = false;
function scheduleRender() {
  if (renderScheduled) return;
  renderScheduled = true;
  requestAnimationFrame(() => {
    renderScheduled = false;
    renderAll();
  });
}

const IMG_CACHE = {};
function loadImg(src) {
  if (!src) return null;
  if (IMG_CACHE[src]) return IMG_CACHE[src];
  const im = new Image();
  im.onload = () => scheduleRender();
  im.src = src;
  IMG_CACHE[src] = im;
  return im;
}

const TINT_CACHE = {};
function getTintedCanvas(src, hexColor) {
  const im = loadImg(src);
  if (!im || !im.complete) return null;
  if (!hexColor || hexColor.toLowerCase() === "#ffffff") return im;
  const key = src + "|" + hexColor;
  if (TINT_CACHE[key]) return TINT_CACHE[key];
  const c = document.createElement("canvas");
  c.width = im.width; c.height = im.height;
  const g = c.getContext("2d");
  g.drawImage(im, 0, 0);
  const id = g.getImageData(0, 0, c.width, c.height);
  const d = id.data;
  const tr = parseInt(hexColor.slice(1, 3), 16);
  const tg = parseInt(hexColor.slice(3, 5), 16);
  const tb = parseInt(hexColor.slice(5, 7), 16);
  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] > 0) {
      d[i] = (d[i] * tr) >> 8;
      d[i + 1] = (d[i + 1] * tg) >> 8;
      d[i + 2] = (d[i + 2] * tb) >> 8;
    }
  }
  g.putImageData(id, 0, 0);
  TINT_CACHE[key] = c;
  return c;
}

// Preload core images
Object.values(DATA.refs_bundle.turfs).forEach(t => { loadImg(t.src); if (t.cover_src) loadImg(t.cover_src); });
Object.values(DATA.refs_bundle.walls).forEach(w => loadImg(w.src));
Object.values(DATA.refs_bundle.overlays).forEach(loadImg);
DATA.refs_bundle.refs.forEach(r => { loadImg(r.idle); loadImg(r.fault); r.active.forEach(loadImg); });
DATA.fixtures.forEach(c => c.frames.forEach(loadImg));
Object.values(DATA.pipes.stubs_intact).forEach(loadImg);
Object.values(DATA.pipes.stubs_exposed).forEach(loadImg);
Object.values(DATA.pipes.stubs_half).forEach(loadImg);
Object.values(DATA.pipes.pipe_runs).forEach(loadImg);
Object.values(DATA.pipes.caps).forEach(loadImg);
Object.values(DATA.pipes.risers).forEach(loadImg);
DATA.pipes.tg_4dir_mounts.forEach(m => m.dirs.forEach(loadImg));

const state = {
  tab: "gallery",
  scale: 5,
  turf: "floor",
  wall: "wall",
  water: "puddle",
  mode: "active",
  showPipes: true,
  greyscale: false,
  showGrid: false,
  tick: 0,
  pwDir: "N",
  pwLayer: 3,
  pwJoin: "joined",
  pwColor: "#f04137",
  pwScupperMode: "riser",
  roomScale: 3,
  inspFixture: DATA.fixtures[0]?.name || "",
  inspFrame: 0,
};

function turfExposesSubfloor(turfKey) {
  if (turfKey === "void_dark") return true;
  if (turfKey === "paper_light") return false;
  return Boolean(DATA.refs_bundle.turfs[turfKey]?.exposes_pipe);
}

// The engine's compositing:
// stubs & mouth_caps ONLY appear when subfloor is exposed, and mouth_caps draw OVER fixtureIm!
function drawTileStack(ctx, x, y, size, turfKey, waterMode, pipeKind, fixtureIm) {
  const exposed = turfExposesSubfloor(turfKey);
  if (turfKey === "void_dark") {
    ctx.fillStyle = "#151824";
    ctx.fillRect(x, y, size, size);
  } else if (turfKey === "paper_light") {
    ctx.fillStyle = "#f1ead4";
    ctx.fillRect(x, y, size, size);
  } else {
    const t = DATA.refs_bundle.turfs[turfKey];
    const im = t ? loadImg(t.src) : null;
    if (im && im.complete) ctx.drawImage(im, x, y, size, size);
  }

  if (state.showPipes && exposed && (pipeKind === "waste" || pipeKind === "supply" || pipeKind === "supply_ew")) {
    const stubSrc = pipeKind === "supply_ew"
      ? DATA.refs_bundle.overlays.pipe_stub_supply_e
      : (pipeKind === "supply"
        ? DATA.refs_bundle.overlays.pipe_stub_supply_n
        : DATA.refs_bundle.overlays.pipe_stub_waste_n);
    const sm = loadImg(stubSrc);
    if (sm && sm.complete) ctx.drawImage(sm, x, y, size, size);
  }

  const tInfo = DATA.refs_bundle.turfs[turfKey];
  if (tInfo && tInfo.cover_src) {
    const cov = loadImg(tInfo.cover_src);
    if (cov && cov.complete) ctx.drawImage(cov, x, y, size, size);
  }

  if (waterMode && waterMode !== "none") {
    const wm = loadImg(DATA.refs_bundle.overlays[waterMode]);
    if (wm && wm.complete) ctx.drawImage(wm, x, y, size, size);
  }

  if (fixtureIm && fixtureIm.complete) {
    ctx.drawImage(fixtureIm, x, y, size, size);
  }

  if (state.showPipes && exposed && (pipeKind === "waste" || pipeKind === "supply" || pipeKind === "supply_ew")) {
    const capSrc = pipeKind === "supply_ew"
      ? DATA.refs_bundle.overlays.vent_cap_e
      : (pipeKind === "supply"
        ? DATA.refs_bundle.overlays.vent_cap_n
        : DATA.refs_bundle.overlays.scrub_cap_n);
    const cm = loadImg(capSrc);
    if (cm && cm.complete) ctx.drawImage(cm, x, y, size, size);
  }
}

function drawPixelGrid(ctx, w, h, stepPx, forceOn = false) {
  if ((!state.showGrid && !forceOn) || stepPx < 3) return;
  ctx.strokeStyle = "rgba(255,255,255,0.12)";
  ctx.lineWidth = 1;
  for (let gx = 0; gx <= w; gx += stepPx) {
    ctx.beginPath(); ctx.moveTo(gx + 0.5, 0); ctx.lineTo(gx + 0.5, h); ctx.stroke();
  }
  for (let gy = 0; gy <= h; gy += stepPx) {
    ctx.beginPath(); ctx.moveTo(0, gy + 0.5); ctx.lineTo(w, gy + 0.5); ctx.stroke();
  }
}

function pickFixtureFrame(c, dirIdx = 0) {
  if (c.kind === "floor_drain") {
    return state.mode === "active" ? 1 + (state.tick % 4) : 0;
  }
  if (c.kind === "sump_pump") {
    // Frames 0..5 are the E-W manifold, 6..11 the N-S one; dirIdx is N, S, E, W.
    const axis = dirIdx < 2 ? 6 : 0;
    if (state.mode === "active") return axis + 1 + (state.tick % 4);
    if (state.mode === "fault") return axis + 5;
    return axis;
  }
  if (c.kind === "scupper") {
    if (state.mode === "active" && c.frames.length >= 20) {
      return 4 + dirIdx * 4 + (state.tick % 4);
    }
    return dirIdx;
  }
  return 0;
}

const dynamicCanvases = [];
const pipeWorkbenchUpdaters = [];

function buildGalleryDOM() {
  const refGrid = document.getElementById("ref-grid");
  DATA.refs_bundle.refs.forEach(r => {
    const card = document.createElement("div");
    card.className = "ref-card";
    const cv = document.createElement("canvas");
    cv.className = "preview-cv";
    card.appendChild(cv);
    const meta = document.createElement("div");
    meta.className = "ref-meta";
    meta.innerHTML = `<h4>${r.title}</h4><div class="sub">${r.subtitle}</div><p>${r.note}</p>`;
    card.appendChild(meta);
    refGrid.appendChild(card);

    dynamicCanvases.push(() => {
      const sc = state.scale;
      const sz = 32 * sc;
      if (cv.width !== sz) { cv.width = sz; cv.height = sz; }
      const ctx = cv.getContext("2d");
      ctx.imageSmoothingEnabled = false;
      let src = r.idle;
      if (state.mode === "active") src = r.active[state.tick % r.active.length];
      else if (state.mode === "fault") src = r.fault;
      const fixIm = loadImg(src);
      if (r.mount_shift && r.mount_shift > 0) {
        const off = document.createElement("canvas");
        off.width = 32; off.height = 64;
        const octx = off.getContext("2d");
        octx.imageSmoothingEnabled = false;
        const wallIm = loadImg(DATA.refs_bundle.walls[state.wall].src);
        if (wallIm && wallIm.complete) octx.drawImage(wallIm, 0, 0, 32, 32);
        drawTileStack(octx, 0, 32, 32, state.turf, state.water, "none", null);
        if (fixIm && fixIm.complete) octx.drawImage(fixIm, 0, 32 - r.mount_shift, 32, 32);
        ctx.drawImage(off, 0, 6, 32, 32, 0, 0, sz, sz);
      } else {
        drawTileStack(ctx, 0, 0, sz, state.turf, state.water, r.pipe_kind, fixIm);
      }
      drawPixelGrid(ctx, sz, sz, sc);
    });
  });

  // tgstation dirs=4 wallmount benchmarks right above Wall Scuppers!
  const tg4Grid = document.getElementById("tg4-grid");
  DATA.pipes.tg_4dir_mounts.forEach(m => {
    const card = document.createElement("div");
    card.className = "tg4-card";
    card.innerHTML = `<div class="ref-meta"><h4>${m.title}</h4><div class="sub">${m.subtitle}</div><p>${m.note}</p></div>`;
    const row = document.createElement("div");
    row.className = "tg4-dirs";
    const cvs = ["N Wall", "S Wall", "E Wall", "W Wall"].map(lbl => {
      const cell = document.createElement("div");
      cell.className = "dir-cell";
      const cv = document.createElement("canvas");
      cv.className = "preview-cv";
      const sp = document.createElement("span");
      sp.textContent = lbl;
      cell.appendChild(cv); cell.appendChild(sp);
      row.appendChild(cell);
      return cv;
    });
    card.appendChild(row);
    tg4Grid.appendChild(card);

    dynamicCanvases.push(() => {
      const sc = Math.min(state.scale, 4);
      const sz = 32 * sc;
      const wallIm = loadImg(DATA.refs_bundle.walls[state.wall].src);
      const boxes = [[32, 8], [32, 56], [56, 32], [8, 32]];
      const off = document.createElement("canvas");
      off.width = 96; off.height = 96;
      const octx = off.getContext("2d");
      octx.imageSmoothingEnabled = false;
      cvs.forEach((cv, di) => {
        if (cv.width !== sz) { cv.width = sz; cv.height = sz; }
        octx.clearRect(0, 0, 96, 96);
        for (let gy = 0; gy < 3; gy++) {
          for (let gx = 0; gx < 3; gx++) {
            if (gx === 1 && gy === 1) drawTileStack(octx, 32, 32, 32, state.turf, "none", "none", null);
            else if (wallIm && wallIm.complete) octx.drawImage(wallIm, gx * 32, gy * 32, 32, 32);
          }
        }
        const spIm = loadImg(m.dirs[di]);
        const [sx, sy] = m.shifts[di];
        if (spIm && spIm.complete) octx.drawImage(spIm, 32 + sx, 32 + sy, 32, 32);
        const dctx = cv.getContext("2d");
        dctx.imageSmoothingEnabled = false;
        const [bx, by] = boxes[di];
        dctx.drawImage(off, bx, by, 32, 32, 0, 0, sz, sz);
        drawPixelGrid(dctx, sz, sz, sc);
      });
    });
  });

  const containers = {
    floor_drain: document.getElementById("grid-floor-drains"),
    scupper: document.getElementById("grid-wall-scuppers"),
    sump_pump: document.getElementById("grid-sump-pumps"),
  };

  DATA.fixtures.forEach(c => {
    const card = document.createElement("div");
    card.className = "fixture-card";
    const st = c.frame_stats[0];

    const top = document.createElement("div");
    top.className = "card-top";
    top.innerHTML = `<div><span class="card-title">${c.title}</span></div>`;
    const inspBtn = document.createElement("button");
    inspBtn.textContent = "Inspect 32×32";
    inspBtn.onclick = () => openInInspector(c.name);
    top.appendChild(inspBtn);
    card.appendChild(top);

    const stage = document.createElement("div");
    stage.className = "stage-box";

    if (c.kind === "scupper") {
      const dGrid = document.createElement("div");
      dGrid.className = "scupper-dirs-grid";
      const dirLabels = ["NORTH Wall", "SOUTH Wall", "EAST Wall", "WEST Wall"];
      const dirCvs = dirLabels.map(lbl => {
        const wrap = document.createElement("div");
        wrap.className = "dir-cell";
        const cv = document.createElement("canvas");
        cv.className = "preview-cv";
        const sp = document.createElement("span");
        sp.textContent = lbl;
        wrap.appendChild(cv); wrap.appendChild(sp);
        dGrid.appendChild(wrap);
        return cv;
      });
      stage.appendChild(dGrid);

      const chipWrap = document.createElement("div");
      chipWrap.className = "chips-1x";
      const chipRoom = document.createElement("canvas");
      chipRoom.className = "preview-cv";
      chipRoom.width = 96; chipRoom.height = 96;
      const chipLbl = document.createElement("span");
      chipLbl.textContent = "1× 3×3 Room";
      chipWrap.appendChild(chipRoom); chipWrap.appendChild(chipLbl);
      stage.appendChild(chipWrap);

      dynamicCanvases.push(() => {
        const sc = state.scale;
        const winPx = 32 * sc;
        const wallIm = loadImg(DATA.refs_bundle.walls[state.wall].src);
        const wallCoords = [[32, 0], [32, 64], [64, 32], [0, 32]];
        const boxes = [[32, 8], [32, 56], [56, 32], [8, 32]];
        const off = document.createElement("canvas");
        off.width = 96; off.height = 96;
        const octx = off.getContext("2d");
        octx.imageSmoothingEnabled = false;

        dirCvs.forEach((cv, di) => {
          if (cv.width !== winPx) { cv.width = winPx; cv.height = winPx; }
          octx.clearRect(0, 0, 96, 96);
          for (let gy = 0; gy < 3; gy++) {
            for (let gx = 0; gx < 3; gx++) {
              if (gx === 1 && gy === 1) {
                drawTileStack(octx, 32, 32, 32, state.turf, state.water, "none", null);
                if (state.showPipes && turfExposesSubfloor(state.turf)) {
                  const dKey = ["N", "S", "E", "W"][di];
                  const rIm = loadImg(DATA.pipes.risers[`bulkhead_collar_${dKey}`]);
                  if (rIm && rIm.complete) octx.drawImage(rIm, 32, 32, 32, 32);
                }
              } else if (wallIm && wallIm.complete) {
                octx.drawImage(wallIm, gx * 32, gy * 32, 32, 32);
              }
            }
          }
          const spIm = loadImg(c.frames[pickFixtureFrame(c, di)]);
          const [wx, wy] = wallCoords[di];
          if (spIm && spIm.complete) octx.drawImage(spIm, wx, wy, 32, 32);

          const dctx = cv.getContext("2d");
          dctx.imageSmoothingEnabled = false;
          const [sx, sy] = boxes[di];
          dctx.drawImage(off, sx, sy, 32, 32, 0, 0, winPx, winPx);
          drawPixelGrid(dctx, winPx, winPx, sc);
        });

        const rctx = chipRoom.getContext("2d");
        rctx.imageSmoothingEnabled = false;
        for (let gy = 0; gy < 3; gy++) {
          for (let gx = 0; gx < 3; gx++) {
            if (gx === 1 && gy === 1) drawTileStack(rctx, 32, 32, 32, state.turf, state.water, "none", null);
            else if (wallIm && wallIm.complete) rctx.drawImage(wallIm, gx * 32, gy * 32, 32, 32);
          }
        }
        for (let di = 0; di < 4; di++) {
          const spIm = loadImg(c.frames[pickFixtureFrame(c, di)]);
          const [wx, wy] = wallCoords[di];
          if (spIm && spIm.complete) rctx.drawImage(spIm, wx, wy, 32, 32);
        }
      });
    } else {
      const mainCv = document.createElement("canvas");
      mainCv.className = "preview-cv";
      stage.appendChild(mainCv);

      const chipWrap = document.createElement("div");
      chipWrap.className = "chips-1x";
      const chipLbl = document.createElement("span");
      chipLbl.textContent = "1× Floor / Ref / White";
      const cRow = document.createElement("div");
      cRow.style.display = "flex"; cRow.style.gap = "4px";
      const chipCvs = [0, 1, 2].map(() => {
        const cc = document.createElement("canvas");
        cc.className = "preview-cv";
        cc.width = 32; cc.height = 32;
        cRow.appendChild(cc);
        return cc;
      });
      chipWrap.appendChild(cRow); chipWrap.appendChild(chipLbl);
      stage.appendChild(chipWrap);

      const pKind = c.kind === "sump_pump" ? "supply_ew" : "waste";
      const cardDir = c.kind === "sump_pump" ? 2 : 0;
      const refObj = DATA.refs_bundle.refs.find(r => r.id === (c.kind === "sump_pump" ? "ref_scrubber" : "ref_passive_vent"));
      dynamicCanvases.push(() => {
        const sz = 32 * state.scale;
        if (mainCv.width !== sz) { mainCv.width = sz; mainCv.height = sz; }
        const ctx = mainCv.getContext("2d");
        ctx.imageSmoothingEnabled = false;
        const im = loadImg(c.frames[pickFixtureFrame(c, cardDir)]);
        drawTileStack(ctx, 0, 0, sz, state.turf, state.water, pKind, im);
        drawPixelGrid(ctx, sz, sz, state.scale);

        let refIm = null;
        if (refObj) {
          let rSrc = refObj.idle;
          if (state.mode === "active") rSrc = refObj.active[state.tick % refObj.active.length];
          else if (state.mode === "fault") rSrc = refObj.fault;
          refIm = loadImg(rSrc);
        }
        const chipSpecs = [
          ["floor", pKind, im],
          ["floor", refObj ? refObj.pipe_kind : pKind, refIm],
          ["white_floor", pKind, im],
        ];
        chipCvs.forEach((cc, idx) => {
          const cctx = cc.getContext("2d");
          cctx.imageSmoothingEnabled = false;
          const [cTurf, cPipe, cIm] = chipSpecs[idx];
          drawTileStack(cctx, 0, 0, 32, cTurf, state.water, cPipe, cIm);
        });
      });
    }

    card.appendChild(stage);

    const telem = document.createElement("div");
    telem.className = "telem-row";
    telem.innerHTML = `
      <span class="t-pill ok">100% .gpl</span>
      <span class="t-pill">bbox <strong>${st.bbox[2]}×${st.bbox[3]}</strong></span>
      <span class="t-pill">cols <strong>${st.unique_colors}</strong></span>
      <span class="t-pill">hLuma <strong>${st.housing_mean_luma} (max ${st.housing_max_luma})</strong></span>
      <span class="t-pill">T/B <strong>${st.luma_top}/${st.luma_bottom}</strong></span>
      <span class="t-pill">anim <strong>${c.animated_px}px</strong></span>
    `;
    card.appendChild(telem);

    const blurb = document.createElement("p");
    blurb.className = "blurb";
    blurb.textContent = c.blurb;
    card.appendChild(blurb);

    if (c.design_notes) {
      const notes = document.createElement("p");
      notes.className = "notes";
      notes.textContent = c.design_notes;
      card.appendChild(notes);
    }

    const swStrip = document.createElement("div");
    swStrip.className = "swatch-strip";
    c.swatches.forEach(sw => {
      const d = document.createElement("div");
      d.className = "sw-dot";
      d.style.background = sw.hex;
      d.title = `${sw.name} (${sw.hex})`;
      swStrip.appendChild(d);
    });
    card.appendChild(swStrip);

    const act = document.createElement("div");
    act.className = "card-actions";
    act.innerHTML = `<span class="ase-path" title="${c.aseprite}">${c.name}.aseprite (${c.frame_count}f, ${c.layers.length} layers)</span>`;
    card.appendChild(act);

    containers[c.kind].appendChild(card);
  });
}

