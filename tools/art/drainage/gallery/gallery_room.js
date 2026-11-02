// =========================================================================
// TAB 3: PLUMBABLE 8x6 ROOM DIORAMA
// =========================================================================
function renderRoomDiorama() {
  const cv = document.getElementById("room-canvas");
  const sc = state.roomScale;
  const tile = 32 * sc;
  const cols = 8, rows = 6;
  if (cv.width !== cols * tile) { cv.width = cols * tile; cv.height = rows * tile; }
  const ctx = cv.getContext("2d");
  ctx.imageSmoothingEnabled = false;

  const off = document.createElement("canvas");
  off.width = cols * 32; off.height = rows * 32;
  const octx = off.getContext("2d");
  octx.imageSmoothingEnabled = false;

  const wallIm = loadImg(DATA.refs_bundle.walls[state.wall].src);
  const drainC = DATA.fixtures.find(c => c.kind === "floor_drain");
  const scupC = DATA.fixtures.find(c => c.kind === "scupper");
  const sumpC = DATA.fixtures.find(c => c.kind === "sump_pump");
  const refVent = DATA.refs_bundle.refs.find(r => r.id === "ref_vent");
  const refScrub = DATA.refs_bundle.refs.find(r => r.id === "ref_scrubber");
  const refApc = DATA.refs_bundle.refs.find(r => r.id === "ref_apc");
  const refAlarm = DATA.refs_bundle.refs.find(r => r.id === "ref_air_alarm");
  const exposed = turfExposesSubfloor(state.turf);

  // 1. Base turfs & perimeter walls
  for (let gy = 0; gy < rows; gy++) {
    for (let gx = 0; gx < cols; gx++) {
      const isWall = (gx === 0 || gx === cols - 1 || gy === 0 || gy === rows - 1);
      if (isWall) {
        if (wallIm && wallIm.complete) octx.drawImage(wallIm, gx * 32, gy * 32, 32, 32);
      } else {
        drawTileStack(octx, gx * 32, gy * 32, 32, state.turf === "open_grid" ? "plating" : state.turf, "none", "none", null);
      }
    }
  }

  // 2. Subfloor pipe network (revealed when plating / open_grid / void_dark!)
  if (state.showPipes && exposed) {
    const wasteHex = "#f04137";
    const supplyHex = "#5491e8";
    const drawRun = (gx, gy, mask, hex) => {
      const im = getTintedCanvas(DATA.pipes.pipe_runs[`l3_${mask}`], hex);
      if (im) octx.drawImage(im, gx * 32, gy * 32, 32, 32);
    };
    const drawStub = (gx, gy, db, hex) => {
      const im = getTintedCanvas(DATA.pipes.stubs_intact[`l3_${db}`], hex);
      if (im) octx.drawImage(im, gx * 32, gy * 32, 32, 32);
    };
    // Supply stub at (1,1) Vent -> North
    drawStub(1, 1, 1, supplyHex);
    // Scrubber stub at (1,4) -> North, (1,3) N-S pipe, (1,2) W scupper riser + S+E elbow (2|4=6)!
    drawStub(1, 4, 1, wasteHex);
    drawRun(1, 3, 3, wasteHex);
    drawStub(1, 2, 2, wasteHex);
    drawStub(1, 2, 4, wasteHex);
    const rW = loadImg(DATA.pipes.risers.riser_W);
    if (rW && rW.complete) octx.drawImage(rW, 1 * 32, 2 * 32, 32, 32);

    // (2,1) north scupper riser into the (2,2) tee, ending at the (3,2) floor drain;
    // the (5,2) sump pump discharges east into the (6,2) scupper.
    drawStub(2, 1, 2, wasteHex);
    const rN = loadImg(DATA.pipes.risers.riser_N);
    if (rN && rN.complete) octx.drawImage(rN, 2 * 32, 1 * 32, 32, 32);
    drawRun(2, 2, 13, wasteHex);
    drawStub(3, 2, 8, wasteHex);
    drawStub(5, 2, 4, wasteHex);
    drawStub(6, 2, 8, wasteHex);
    const rE = loadImg(DATA.pipes.risers.riser_E);
    if (rE && rE.complete) octx.drawImage(rE, 6 * 32, 2 * 32, 32, 32);
  }

  // 3. Open grid cover (above pipes, below water & fixtures)
  const covSrc = DATA.refs_bundle.turfs[state.turf]?.cover_src;
  if (covSrc) {
    const cov = loadImg(covSrc);
    if (cov && cov.complete) {
      for (let gy = 1; gy < rows - 1; gy++) {
        for (let gx = 1; gx < cols - 1; gx++) octx.drawImage(cov, gx * 32, gy * 32, 32, 32);
      }
    }
  }

  // 4. Standing water puddles/flood
  for (let gy = 1; gy < rows - 1; gy++) {
    for (let gx = 1; gx < cols - 1; gx++) {
      let wMode = "none";
      if (state.water === "flood") wMode = "flood";
      else if (state.water === "puddle" && gx >= 2 && gx <= 6 && gy >= 1 && gy <= 4) {
        wMode = (gx >= 3 && gx <= 5 && gy >= 2 && gy <= 3) ? "flood" : "puddle";
      }
      if (wMode !== "none") {
        const wm = loadImg(DATA.refs_bundle.overlays[wMode]);
        if (wm && wm.complete) octx.drawImage(wm, gx * 32, gy * 32, 32, 32);
      }
    }
  }

  // 5. Floor fixtures + mouth caps (when exposed!)
  if (refVent) {
    const src = state.mode === "active" ? refVent.active[state.tick % refVent.active.length] : (state.mode === "fault" ? refVent.fault : refVent.idle);
    const im = loadImg(src);
    if (im && im.complete) octx.drawImage(im, 32, 32, 32, 32);
    if (state.showPipes && exposed) {
      const cap = loadImg(DATA.pipes.caps.vent_l3_1);
      if (cap && cap.complete) octx.drawImage(cap, 32, 32, 32, 32);
    }
  }
  if (refScrub) {
    const src = state.mode === "active" ? refScrub.active[state.tick % refScrub.active.length] : (state.mode === "fault" ? refScrub.fault : refScrub.idle);
    const im = loadImg(src);
    if (im && im.complete) octx.drawImage(im, 32, 4 * 32, 32, 32);
    if (state.showPipes && exposed) {
      const cap = loadImg(DATA.pipes.caps.scrub_l3_1);
      if (cap && cap.complete) octx.drawImage(cap, 32, 4 * 32, 32, 32);
    }
  }
  if (drainC) {
    const im = loadImg(drainC.frames[pickFixtureFrame(drainC, 0)]);
    if (im && im.complete) octx.drawImage(im, 3 * 32, 2 * 32, 32, 32);
    if (state.showPipes && exposed) {
      [8].forEach(db => {
        const cap = loadImg(DATA.pipes.caps[`scrub_l3_${db}`]);
        if (cap && cap.complete) octx.drawImage(cap, 3 * 32, 2 * 32, 32, 32);
      });
    }
  }
  if (sumpC) {
    const im = loadImg(sumpC.frames[pickFixtureFrame(sumpC, 2)]);
    if (im && im.complete) octx.drawImage(im, 5 * 32, 2 * 32, 32, 32);
    if (state.showPipes && exposed) {
      [4].forEach(db => {
        const cap = loadImg(DATA.pipes.caps[`vent_l3_${db}`]);
        if (cap && cap.complete) octx.drawImage(cap, 5 * 32, 2 * 32, 32, 32);
      });
    }
  }

  // 6. Wallmounts (APC, Air Alarm, 4-dir Wall Scuppers)
  if (refApc) {
    const src = state.mode === "active" ? refApc.active[0] : (state.mode === "fault" ? refApc.fault : refApc.idle);
    const im = loadImg(src);
    if (im && im.complete) octx.drawImage(im, 4 * 32, 32 - 25, 32, 32);
  }
  if (refAlarm) {
    const src = state.mode === "active" ? refAlarm.active[0] : (state.mode === "fault" ? refAlarm.fault : refAlarm.idle);
    const im = loadImg(src);
    if (im && im.complete) octx.drawImage(im, 6 * 32 + 27, 3 * 32, 32, 32);
  }
  if (scupC) {
    const sN = loadImg(scupC.frames[pickFixtureFrame(scupC, 0)]);
    const sS = loadImg(scupC.frames[pickFixtureFrame(scupC, 1)]);
    const sE = loadImg(scupC.frames[pickFixtureFrame(scupC, 2)]);
    const sW = loadImg(scupC.frames[pickFixtureFrame(scupC, 3)]);
    if (sN && sN.complete) octx.drawImage(sN, 2 * 32, 0, 32, 32);
    if (sS && sS.complete) octx.drawImage(sS, 4 * 32, (rows - 1) * 32, 32, 32);
    if (sE && sE.complete) octx.drawImage(sE, (cols - 1) * 32, 2 * 32, 32, 32);
    if (sW && sW.complete) octx.drawImage(sW, 0, 2 * 32, 32, 32);
  }

  ctx.drawImage(off, 0, 0, cols * tile, rows * tile);
  drawPixelGrid(ctx, cols * tile, rows * tile, sc);
}

