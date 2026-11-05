// =========================================================================
// TAB 4: 32x32 PIXEL & LAYER INSPECTOR
// =========================================================================
function drawHexGridToCanvas(cv, grid, outSize) {
  const off = document.createElement("canvas");
  off.width = 32; off.height = 32;
  const octx = off.getContext("2d");
  for (let y = 0; y < 32; y++) {
    for (let x = 0; x < 32; x++) {
      const hx = grid[y][x];
      if (hx) { octx.fillStyle = hx; octx.fillRect(x, y, 1, 1); }
    }
  }
  const ctx = cv.getContext("2d");
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = "#151824";
  ctx.fillRect(0, 0, outSize, outSize);
  ctx.drawImage(off, 0, 0, outSize, outSize);
}

function scupperDirForFrame(c, fi) {
  const f1 = fi + 1;
  const hit = c.tags.find(t => f1 >= t.from && f1 <= t.to);
  return { n: "north", s: "south", e: "east", w: "west" }[hit?.name.split("-")[1]] || "north";
}

function openInInspector(name) {
  state.inspFixture = name;
  state.inspFrame = 0;
  setTab("inspector");
  syncInspectorUI();
}

function syncInspectorUI() {
  const c = DATA.fixtures.find(x => x.name === state.inspFixture) || DATA.fixtures[0];
  if (!c) return;
  document.querySelectorAll("#insp-list button").forEach(b => b.classList.toggle("active", b.dataset.name === c.name));
  document.getElementById("insp-title").textContent = c.title;
  document.getElementById("insp-sub").textContent = `${c.aseprite} · ${c.frame_count} frames · ${c.layers.length} semantic layers`;
  document.getElementById("insp-blurb").textContent = c.blurb;
  document.getElementById("insp-notes").textContent = c.design_notes || "";

  const fSel = document.getElementById("insp-frame");
  fSel.innerHTML = "";
  for (let i = 0; i < c.frame_count; i++) {
    const opt = document.createElement("option");
    opt.value = String(i);
    const tagHit = c.tags.find(t => (i + 1) >= t.from && (i + 1) <= t.to);
    opt.textContent = `Frame ${i + 1} (${tagHit ? tagHit.name : "frame"}, ${c.durations[i]}ms)`;
    if (i === state.inspFrame) opt.selected = true;
    fSel.appendChild(opt);
  }

  const swBox = document.getElementById("insp-swatches");
  swBox.innerHTML = "";
  c.swatches.forEach(sw => {
    const chip = document.createElement("span");
    chip.className = "t-pill";
    chip.innerHTML = `<span style="display:inline-block;width:10px;height:10px;background:${sw.hex};border:1px solid #fff4;margin-right:5px;vertical-align:middle;"></span><strong>${sw.name}</strong> ${sw.hex}`;
    swBox.appendChild(chip);
  });

  syncTopbarForTab();
  renderInspectorAndLayers();
}

function renderInspectorAndLayers() {
  const c = DATA.fixtures.find(x => x.name === state.inspFixture) || DATA.fixtures[0];
  if (!c) return;
  const fi = Math.min(state.inspFrame, c.frame_count - 1);
  const cv = document.getElementById("insp-canvas");
  const sc = 12;
  const ctx = cv.getContext("2d");
  ctx.imageSmoothingEnabled = false;

  const pKind = c.kind === "sump_pump"
    ? (fi < 6 ? "supply_ew" : "supply")
    : ((c.name === "intake_upper_deck" || c.name === "intake_vault" || c.kind === "intake_upper_deck" || c.kind === "intake_vault")
      ? "vault"
      : ((c.name === "intake_ceiling_below" || c.name === "intake_head" || c.name === "vault_mouth_caps" || c.kind === "intake_ceiling_below" || c.kind === "intake_head" || c.kind === "vault_mouth_caps")
        ? "none"
        : "waste"));
  const im = loadImg(c.frames[fi] || c.frames[0]);
  if (c.kind === "scupper") {
    const wallIm = loadImg(DATA.refs_bundle.walls[state.wall].src);
    ctx.fillStyle = "#151824";
    ctx.fillRect(0, 0, 384, 384);
    if (wallIm && wallIm.complete) ctx.drawImage(wallIm, 0, 0, 384, 384);
    if (im && im.complete) ctx.drawImage(im, 0, 0, 384, 384);
    const wdir = scupperDirForFrame(c, fi);
    ctx.strokeStyle = "rgba(245, 224, 74, 0.75)";
    ctx.lineWidth = 3;
    if (wdir === "north") { ctx.beginPath(); ctx.moveTo(0, 382.5); ctx.lineTo(384, 382.5); ctx.stroke(); }
    else if (wdir === "south") { ctx.beginPath(); ctx.moveTo(0, 1.5); ctx.lineTo(384, 1.5); ctx.stroke(); }
    else if (wdir === "east") { ctx.beginPath(); ctx.moveTo(1.5, 0); ctx.lineTo(1.5, 384); ctx.stroke(); }
    else if (wdir === "west") { ctx.beginPath(); ctx.moveTo(382.5, 0); ctx.lineTo(382.5, 384); ctx.stroke(); }
  } else {
    drawTileStack(ctx, 0, 0, 384, state.turf, state.water, pKind, im);
  }

  drawPixelGrid(ctx, 384, 384, sc, state.showGrid);

  const lyrBox = document.getElementById("insp-layers");
  lyrBox.innerHTML = "";
  c.layers.forEach(l => {
    const d = document.createElement("div");
    d.className = "layer-box";
    const lc = document.createElement("canvas");
    lc.className = "preview-cv";
    lc.width = 96; lc.height = 96;
    drawHexGridToCanvas(lc, l.frame_grids[fi], 96);
    d.appendChild(lc);
    const nm = document.createElement("span");
    nm.textContent = `${l.name}${l.animated ? " (anim)" : ""}`;
    d.appendChild(nm);
    lyrBox.appendChild(d);
  });
}

