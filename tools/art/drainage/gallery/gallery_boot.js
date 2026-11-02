function syncTopbarForTab() {
  const isInsp = (state.tab === "inspector");
  const isRoom = (state.tab === "room");
  const isPipes = (state.tab === "pipes");
  const inspC = DATA.fixtures.find(x => x.name === state.inspFixture) || DATA.fixtures[0];
  const inspKind = inspC ? inspC.kind : "floor_drain";
  document.getElementById("cg-scale").classList.toggle("hidden-ctrl", isInsp || isRoom || isPipes);
  document.getElementById("cg-state").classList.toggle("hidden-ctrl", isInsp);
  document.getElementById("cg-turf").classList.toggle("hidden-ctrl", isPipes || (isInsp && inspKind === "scupper"));
  document.getElementById("cg-water").classList.toggle("hidden-ctrl", isInsp && inspKind === "scupper");
  document.getElementById("cg-wall").classList.toggle("hidden-ctrl", isInsp && inspKind !== "scupper");
  document.getElementById("btn-pipes").classList.toggle("hidden-ctrl", isPipes || (isInsp && inspKind === "scupper"));
}

function setTab(tab) {
  state.tab = tab;
  document.querySelectorAll("#nav-tabs button").forEach(b => b.classList.toggle("active", b.dataset.tab === tab));
  document.querySelectorAll(".tab-pane").forEach(p => p.classList.toggle("active", p.id === `pane-${tab}`));
  syncTopbarForTab();
  renderAll();
}

function renderAll() {
  if (state.tab === "gallery") dynamicCanvases.forEach(fn => fn());
  else if (state.tab === "pipes") pipeWorkbenchUpdaters.forEach(fn => fn());
  else if (state.tab === "room") renderRoomDiorama();
  else if (state.tab === "inspector") renderInspectorAndLayers();
}

document.querySelectorAll("#nav-tabs button").forEach(b => { b.onclick = () => setTab(b.dataset.tab); });
document.getElementById("sel-scale").onchange = e => { state.scale = Number(e.target.value); renderAll(); };
document.getElementById("sel-turf").onchange = e => { state.turf = e.target.value; renderAll(); };
document.getElementById("sel-wall").onchange = e => { state.wall = e.target.value; renderAll(); };
document.getElementById("sel-water").onchange = e => { state.water = e.target.value; renderAll(); };

document.getElementById("pw-dir").onchange = e => { state.pwDir = e.target.value; renderAll(); };
document.getElementById("pw-layer").onchange = e => { state.pwLayer = Number(e.target.value); renderAll(); };
document.getElementById("pw-join").onchange = e => { state.pwJoin = e.target.value; renderAll(); };
document.getElementById("pw-color").onchange = e => { state.pwColor = e.target.value; renderAll(); };
document.getElementById("pw-scupper-mode").onchange = e => { state.pwScupperMode = e.target.value; renderAll(); };

document.querySelectorAll("#seg-state button").forEach(b => {
  b.onclick = () => {
    state.mode = b.dataset.state;
    document.querySelectorAll("#seg-state button").forEach(x => x.classList.toggle("active", x === b));
    renderAll();
  };
});

const btnPipes = document.getElementById("btn-pipes");
btnPipes.onclick = () => {
  state.showPipes = !state.showPipes;
  btnPipes.classList.toggle("active", state.showPipes);
  btnPipes.textContent = `Pipes: ${state.showPipes ? "ON" : "OFF"}`;
  renderAll();
};
const btnGrey = document.getElementById("btn-grey");
btnGrey.onclick = () => {
  state.greyscale = !state.greyscale;
  document.body.classList.toggle("greyscale-mode", state.greyscale);
  btnGrey.classList.toggle("active", state.greyscale);
  btnGrey.textContent = `Rec.709 Grey: ${state.greyscale ? "ON" : "OFF"}`;
};
const btnGrid = document.getElementById("btn-grid");
btnGrid.onclick = () => {
  state.showGrid = !state.showGrid;
  btnGrid.classList.toggle("active", state.showGrid);
  btnGrid.textContent = `Grid: ${state.showGrid ? "ON" : "OFF"}`;
  renderAll();
};

function initSelectors() {
  document.getElementById("rm-scale").onchange = e => { state.roomScale = Number(e.target.value); renderRoomDiorama(); };

  const iList = document.getElementById("insp-list");
  DATA.fixtures.forEach(c => {
    const b = document.createElement("button");
    b.dataset.name = c.name;
    b.textContent = c.title;
    b.onclick = () => { state.inspFixture = c.name; state.inspFrame = 0; syncInspectorUI(); };
    iList.appendChild(b);
  });
  document.getElementById("insp-frame").onchange = e => {
    state.inspFrame = Number(e.target.value);
    renderInspectorAndLayers();
  };
  const icv = document.getElementById("insp-canvas");
  icv.onmousemove = e => {
    const rect = icv.getBoundingClientRect();
    const x = Math.floor(((e.clientX - rect.left) / rect.width) * 32);
    const y = Math.floor(((e.clientY - rect.top) / rect.height) * 32);
    if (x < 0 || x >= 32 || y < 0 || y >= 32) return;
    const c = DATA.fixtures.find(it => it.name === state.inspFixture);
    const grid = c?.grids?.[state.inspFrame];
    const hx = grid?.[y]?.[x];
    const rdo = document.getElementById("insp-readout");
    if (!hx) {
      rdo.textContent = c?.kind === "scupper"
        ? `(${x}, ${y}) — Transparent sprite pixel (alpha 0) · Bulkhead wall backdrop underneath`
        : `(${x}, ${y}) — Transparent (alpha 0)`;
    } else {
      const sw = DATA.swatch_names[hx] || "unknown";
      rdo.innerHTML = `<strong>(${x}, ${y})</strong> · <span style="display:inline-block;width:11px;height:11px;background:${hx};border:1px solid #fff6;vertical-align:middle;"></span> <strong>${hx}</strong> · <code>${sw}</code>`;
    }
  };
}

buildGalleryDOM();
buildPipeWorkbenchDOM();
initSelectors();
syncTopbarForTab();
syncInspectorUI();
window.addEventListener("load", () => renderAll());
setInterval(() => {
  if (state.mode === "active" && state.tab !== "inspector") {
    state.tick = (state.tick + 1) % 24;
    renderAll();
  }
}, 200);
