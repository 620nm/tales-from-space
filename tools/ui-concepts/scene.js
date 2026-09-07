// Illustrative scene only; this tool neither connects to a server nor models FOV.
(() => {
  const atlas = window.conceptAtlas;
  const stride = atlas.tile + atlas.pad * 2;
  const pageCells = atlas.columns * atlas.rows_per_page;
  const images = atlas.pages.map(url => {
    const image = new Image();
    image.src = url;
    return image;
  });
  const ready = Promise.all(images.map(image => image.decode()));
  function cell(name) {
    const index = atlas.sprites[name];
    if (index === undefined) return undefined;
    const page = Math.floor(index / pageCells);
    const local = index % pageCells;
    return { page, x: (local % atlas.columns) * stride + atlas.pad,
      y: Math.floor(local / atlas.columns) * stride + atlas.pad };
  }
  function sprite(name, label, size = 32) {
    const element = document.createElement("span");
    element.className = "sprite";
    element.setAttribute("role", "img");
    element.setAttribute("aria-label", label ?? name);
    Object.assign(element.style, { display: "inline-block", flexShrink: "0",
      width: `${size}px`, height: `${size}px`, imageRendering: "pixelated" });
    const source = cell(name);
    if (!source) {
      element.textContent = "·";
      return element;
    }
    const scale = size / atlas.tile;
    const rows = Math.ceil(Math.min(pageCells, atlas.cells - source.page * pageCells) / atlas.columns);
    Object.assign(element.style, {
      backgroundImage: `url("${atlas.pages[source.page]}")`,
      backgroundSize: `${atlas.columns * stride * scale}px ${rows * stride * scale}px`,
      backgroundPosition: `${-source.x * scale}px ${-source.y * scale}px`,
      backgroundRepeat: "no-repeat",
    });
    return element;
  }
  function draw(canvas) {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    canvas.width = Math.round(rect.width);
    canvas.height = Math.round(rect.height);
    const ctx = canvas.getContext("2d");
    ctx.imageSmoothingEnabled = false;
    const tile = 48;
    const ox = Math.round(canvas.width / 2 - 10.5 * tile);
    const oy = Math.round(canvas.height / 2 - 7.5 * tile);
    const paint = (name, x, y, size = tile) => {
      const source = cell(name);
      if (!source || !images[source.page].complete) return;
      ctx.drawImage(images[source.page], source.x, source.y, atlas.tile, atlas.tile,
        ox + x * tile, oy + y * tile, size, size);
    };
    ctx.fillStyle = "#080c11";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    for (let y = -12; y < 32; y++) for (let x = -20; x < 44; x++) {
      const room = x >= 2 && x <= 18 && y >= 2 && y <= 12;
      const corridor = y >= 13 && y <= 16;
      if (room || corridor) paint("floor", x, y);
      else if ((x + y * 13) % 19 === 0) {
        ctx.fillStyle = "#233444";
        ctx.fillRect(ox + x * tile + 12, oy + y * tile + 20, 1, 1);
      }
      if (room && (x === 2 || x === 18 || y === 2 || (y === 12 && x !== 10))) paint("wall", x, y);
      if (corridor && y === 16) paint("wall", x, y);
    }
    for (let x = 4; x <= 8; x++) paint("reinforced_floor", x, 4);
    for (let x = 12; x <= 16; x++) paint("reinforced_floor", x, 4);
    for (const [name, x, y] of [
      ["apc", 3, 4], ["apc", 3, 6], ["apc", 3, 8], ["door_eng_open", 10, 12],
      ["canister", 16, 4], ["canister", 17, 4], ["vent_off", 4, 10],
      ["scrubber_off_s", 16, 10], ["toolbox", 7, 5], ["metal", 8, 5],
      ["glass", 8, 6], ["pipe_dispenser", 14, 5], ["pipe_meter", 13, 5],
      ["wrench", 7, 6], ["crowbar", 6, 6], ["grille", 16, 7], ["window", 16, 7],
      ["grille", 16, 8], ["window", 16, 8], ["grille", 16, 9], ["window", 16, 9],
    ]) paint(name, x, y);
    ctx.fillStyle = "#4c5761";
    ctx.font = "bold 15px monospace";
    ctx.textAlign = "center";
    ctx.fillText("ENGINEERING", ox + 10.5 * tile, oy + 5 * tile);
    for (const name of ["human_s", "worn_uniform_eng_s", "worn_backpack_s", "hair_bedhead_s"])
      paint(name, 10, 7);
    for (const name of ["human_w", "worn_uniform_eng_w", "hair_bedhead_w"])
      paint(name, 13, 10);
    const shade = ctx.createRadialGradient(canvas.width / 2, canvas.height / 2, 100,
      canvas.width / 2, canvas.height / 2, Math.max(canvas.width, canvas.height) * 0.65);
    shade.addColorStop(0, "#02060a00");
    shade.addColorStop(1, "#02060a99");
    ctx.fillStyle = shade;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
  window.ConceptScene = { sprite, draw, ready };
})();
