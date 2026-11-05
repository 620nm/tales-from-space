// =========================================================================
// TAB 2: INTERACTIVE PIPE-CONNECTION WORKBENCH
// =========================================================================
function computeMouths(dirCode, isWallScupper = false) {
  const bitMap = { N: 1, S: 2, E: 4, W: 8 };
  const oppMap = { N: 2, S: 1, E: 8, W: 4 };
  // A wall is on dirCode's side of the room tile, so its pipe comes from the room.
  return isWallScupper ? oppMap[dirCode] : bitMap[dirCode];
}

function drawNeighborRun(octx, gx, gy, dbit, chIdx, hexColor) {
  const mask = (dbit === 1 || dbit === 2) ? 3 : 12;
  const src = DATA.pipes.pipe_runs[`l${chIdx}_${mask}`];
  const im = getTintedCanvas(src, hexColor);
  if (im) octx.drawImage(im, gx * 32, gy * 32, 32, 32);
}

function buildPipeWorkbenchDOM() {
  const grid = document.getElementById("pw-grid");
  const items = [
    {
      id: "floor_drain",
      title: "Floor Drain",
      capFam: "scrub",
      desc: "4-fold symmetric 19×19 octagon + `mouth_cap = 'scrub'`: one picture on every facing.",
    },
    {
      id: "scupper",
      title: "Scupper",
      capFam: "riser",
      desc: "Centered on pixel 15 (6..24). Reached through a room-floor riser sleeve or an in-wall bulkhead drop.",
    },
    {
      id: "sump_pump",
      title: "Sump Pump",
      capFam: "vent",
      desc: "The manifold spine turns with the facing + `mouth_cap = 'vent'`, so every stub meets solid steel.",
    },
    {
      id: "intake_floor",
      title: "Intake (32×32 Floor Hatch)",
      capFam: "intake",
      desc: "Stationary 32×32 hatch curb + 5×3 `mouth_cap = 'intake'` collars on l1..l5 (zero overlap across all 20 ports).",
    },
  ];

  items.forEach(item => {
    const card = document.createElement("div");
    card.className = "pw-card";
    const hdr = document.createElement("div");
    hdr.innerHTML = `<span class="card-title">${item.title}</span>`;
    card.appendChild(hdr);

    const pair = document.createElement("div");
    pair.className = "pw-pair";

    const wrapOpen = document.createElement("div");
    wrapOpen.className = "dir-cell";
    const cvOpen = document.createElement("canvas");
    cvOpen.className = "preview-cv";
    cvOpen.width = 192; cvOpen.height = 192; // 64x64 crop * 3x
    const lblOpen = document.createElement("span");
    lblOpen.textContent = "Open Subfloor (Plating / Grid)";
    wrapOpen.appendChild(cvOpen); wrapOpen.appendChild(lblOpen);

    const wrapCov = document.createElement("div");
    wrapCov.className = "dir-cell";
    const cvCov = document.createElement("canvas");
    cvCov.className = "preview-cv";
    cvCov.width = 192; cvCov.height = 192;
    const lblCov = document.createElement("span");
    lblCov.textContent = "Covered Floor (`floor` — Hides Pipe)";
    wrapCov.appendChild(cvCov); wrapCov.appendChild(lblCov);

    pair.appendChild(wrapOpen);
    pair.appendChild(wrapCov);
    card.appendChild(pair);

    const rdo = document.createElement("div");
    rdo.className = "telem-row";
    card.appendChild(rdo);

    const p = document.createElement("p");
    p.className = "notes";
    p.textContent = item.desc;
    card.appendChild(p);
    grid.appendChild(card);

    pipeWorkbenchUpdaters.push(() => {
      const ch = state.pwLayer;
      const shift = (ch - 3) * 5;
      const isScupper = (item.id === "scupper");
      const isIntake = (item.id === "intake_floor");
      const mouths = computeMouths(state.pwDir, isScupper);

      let dx = isIntake ? 0 : ((mouths & 3) ? shift : 0);
      let dy = isIntake ? 0 : ((mouths & 12) ? -shift : 0);
      if (isScupper) {
        dx = (state.pwDir === "N" || state.pwDir === "S") ? shift : 0;
        dy = (state.pwDir === "E" || state.pwDir === "W") ? -shift : 0;
      }

      const renderCase = (targetCv, isCovered) => {
        const off = document.createElement("canvas");
        off.width = 96; off.height = 96;
        const octx = off.getContext("2d");
        octx.imageSmoothingEnabled = false;

        const turfKey = isCovered ? "floor" : (state.turf === "open_grid" ? "open_grid" : "plating");
        const baseTurf = loadImg(DATA.refs_bundle.turfs[turfKey].src);
        const covGrid = DATA.refs_bundle.turfs[turfKey].cover_src ? loadImg(DATA.refs_bundle.turfs[turfKey].cover_src) : null;
        const wallIm = loadImg(DATA.refs_bundle.walls[state.wall].src);

        for (let gy = 0; gy < 3; gy++) {
          for (let gx = 0; gx < 3; gx++) {
            let drawWall = false;
            if (isScupper) {
              if (state.pwDir === "N" && gy === 0) drawWall = true;
              if (state.pwDir === "S" && gy === 2) drawWall = true;
              if (state.pwDir === "E" && gx === 2) drawWall = true;
              if (state.pwDir === "W" && gx === 0) drawWall = true;
            }
            if (drawWall && wallIm && wallIm.complete) {
              octx.drawImage(wallIm, gx * 32, gy * 32, 32, 32);
            } else if (baseTurf && baseTurf.complete) {
              octx.drawImage(baseTurf, gx * 32, gy * 32, 32, 32);
            }
          }
        }

        // Subfloor infrastructure pass
        if (!isCovered) {
          if (isScupper && state.pwScupperMode === "bulkhead") {
            const dbit = { N: 1, S: 2, E: 4, W: 8 }[state.pwDir];
            const halfIm = getTintedCanvas(DATA.pipes.stubs_half[`l${ch}_${dbit}`], state.pwColor);
            if (halfIm) octx.drawImage(halfIm, 32, 32, 32, 32);
            const colIm = loadImg(DATA.pipes.risers[`bulkhead_collar_${state.pwDir}_l${ch}`]);
            if (colIm && colIm.complete) octx.drawImage(colIm, 32, 32, 32, 32);
          } else {
            const nbCoords = { 1: [1, 0], 2: [1, 2], 4: [2, 1], 8: [0, 1] };
            [1, 2, 4, 8].forEach((db, idx) => {
              if (!(mouths & db)) return;
              const isBranchCapped = (state.pwJoin === "exposed");
              if (!isBranchCapped) {
                const [ngx, ngy] = nbCoords[db];
                drawNeighborRun(octx, ngx, ngy, db, ch, state.pwColor);
                const stIm = getTintedCanvas(DATA.pipes.stubs_intact[`l${ch}_${db}`], state.pwColor);
                if (stIm) octx.drawImage(stIm, 32, 32, 32, 32);
              } else {
                const exIm = loadImg(DATA.pipes.stubs_exposed[`l${ch}_${db}`]);
                if (exIm && exIm.complete) octx.drawImage(exIm, 32, 32, 32, 32);
              }
            });
            if (isScupper) {
              const rIm = loadImg(DATA.pipes.risers[`riser_${state.pwDir}_l${ch}`]);
              if (rIm && rIm.complete) octx.drawImage(rIm, 32, 32, 32, 32);
            }
          }
        }

        if (!isCovered && covGrid && covGrid.complete) {
          for (let gy = 0; gy < 3; gy++) {
            for (let gx = 0; gx < 3; gx++) {
              const isWall = isScupper && ((state.pwDir === "N" && gy === 0) || (state.pwDir === "S" && gy === 2) || (state.pwDir === "E" && gx === 2) || (state.pwDir === "W" && gx === 0));
              if (!isWall) octx.drawImage(covGrid, gx * 32, gy * 32, 32, 32);
            }
          }
        }

        if (state.water !== "none") {
          const wm = loadImg(DATA.refs_bundle.overlays[state.water]);
          if (wm && wm.complete) octx.drawImage(wm, 32, 32, 32, 32);
        }

        const bx = 32 + (isCovered ? 0 : dx);
        const by = 32 + (isCovered ? 0 : dy);

        if (item.id === "floor_drain") {
          const drain = DATA.fixtures.find(x => x.kind === "floor_drain");
          const im = loadImg(drain.frames[pickFixtureFrame(drain, 0)]);
          if (im && im.complete) octx.drawImage(im, bx, by, 32, 32);
          if (!isCovered) {
            [1, 2, 4, 8].forEach(db => {
              if (mouths & db) {
                const cap = loadImg(DATA.pipes.caps[`scrub_l${ch}_${db}`]);
                if (cap && cap.complete) octx.drawImage(cap, bx, by, 32, 32);
              }
            });
          }
        } else if (item.id === "scupper") {
          const scupper = DATA.fixtures.find(x => x.kind === "scupper");
          const di = { N: 0, S: 1, E: 2, W: 3 }[state.pwDir];
          const im = loadImg(scupper.frames[pickFixtureFrame(scupper, di)]);
          const wallPos = {
            N: [32 + (isCovered ? 0 : dx), 0],
            S: [32 + (isCovered ? 0 : dx), 64],
            E: [64, 32 + (isCovered ? 0 : dy)],
            W: [0, 32 + (isCovered ? 0 : dy)],
          }[state.pwDir];
          if (im && im.complete) octx.drawImage(im, wallPos[0], wallPos[1], 32, 32);
        } else if (item.id === "intake_floor") {
          const intake = DATA.fixtures.find(x => x.kind === "intake_floor");
          if (intake) {
            const bodyIm = loadImg(intake.frames[pickFixtureFrame(intake, 0)]);
            if (bodyIm && bodyIm.complete) octx.drawImage(bodyIm, 32, 32, 32, 32);
          }
          if (!isCovered) {
            [1, 2, 4, 8].forEach(db => {
              if (mouths & db) {
                const cap = loadImg(DATA.pipes.caps[`intake_l${ch}_${db}`]);
                if (cap && cap.complete) octx.drawImage(cap, 32, 32, 32, 32);
              }
            });
          }
        } else {
          const pump = DATA.fixtures.find(x => x.kind === "sump_pump");
          const pumpDir = { N: 0, S: 1, E: 2, W: 3 }[state.pwDir];
          const bodyIm = loadImg(pump.frames[pickFixtureFrame(pump, pumpDir)]);
          if (bodyIm && bodyIm.complete) octx.drawImage(bodyIm, bx, by, 32, 32);
          if (!isCovered) {
            [1, 2, 4, 8].forEach(db => {
              if (mouths & db) {
                const cap = loadImg(DATA.pipes.caps[`vent_l${ch}_${db}`]);
                if (cap && cap.complete) octx.drawImage(cap, bx, by, 32, 32);
              }
            });
          }
        }

        let cropX = 16, cropY = 16;
        if (isScupper) {
          if (state.pwDir === "N") cropY = 8;
          if (state.pwDir === "S") cropY = 24;
          if (state.pwDir === "E") cropX = 24;
          if (state.pwDir === "W") cropX = 8;
        }
        const tctx = targetCv.getContext("2d");
        tctx.imageSmoothingEnabled = false;
        tctx.drawImage(off, cropX, cropY, 64, 64, 0, 0, 192, 192);
        drawPixelGrid(tctx, 192, 192, 3);
      };

      renderCase(cvOpen, false);
      renderCase(cvCov, true);

      rdo.innerHTML = `
        <span class="t-pill ok">mouths mask <strong>0x${mouths.toString(16)} (${mouths})</strong></span>
        <span class="t-pill">channel <strong>l${ch}</strong></span>
        <span class="t-pill">body_offset <strong>(${dx >= 0 ? "+" + dx : dx}, ${dy >= 0 ? "+" + dy : dy}) px</strong></span>
        <span class="t-pill">cap <strong>${item.capFam}</strong></span>
      `;
    });
  });
}

