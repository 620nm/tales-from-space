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
  const views = new WeakMap();
  let role = "crew";
  const fixtures = [
    ["apc", 3, 4, "Area power controller", "Distributes power to this room.", "External supply: available"],
    ["apc", 3, 6, "Area power controller", "Lighting circuit enabled."],
    ["apc", 3, 8, "Area power controller", "Equipment circuit enabled."],
    ["door_eng_open", 10, 12, "Engineering airlock", "Open. Engineering access required."],
    ["canister", 16, 4, "Gas canister", "A portable pressurized vessel."],
    ["canister", 17, 4, "Gas canister", "Outlet valve: closed."],
    ["vent_off", 4, 10, "Air vent", "Connected to the distribution network."],
    ["scrubber_off_s", 16, 10, "Air scrubber", "Filters unwanted gases from the room."],
    ["toolbox", 7, 5, "Toolbox", "A metal case for tools."],
    ["metal", 8, 5, "Metal sheets", "A stack of construction material."],
    ["glass", 8, 6, "Glass sheets", "Handle with care."],
    ["pipe_dispenser", 14, 5, "Pipe dispenser", "Fabricates pipe fittings."],
    ["pipe_meter", 9, 5, "Air sensor", "Measures the local atmosphere.", "Pressure: 101.3 kPa · Temperature: 293.2 K"],
    ["operating_computer", 14, 7, "Monitoring terminal", "A console connected to local instruments."],
    ["laptop_on", 6, 8, "Portable computer", "The atmospheric monitor is open."],
    ["wrench", 7, 6, "Wrench", "A sturdy adjustable wrench."],
    ["crowbar", 6, 6, "Crowbar", "Useful for prying panels open."],
  ];
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
  function tileSprite(x, y) {
    const room = x >= 2 && x <= 18 && y >= 2 && y <= 12;
    if ((room && (x === 2 || x === 18 || y === 2 || (y === 12 && x !== 10)))
      || y === 16 || (y === -2 && x !== 10)) return "wall";
    if ((x === -2 || x === 22) && y !== 6 && y < 12) return "reinforced_wall";
    if ((x === 0 || x === 20) && y >= 5 && y <= 9) return "grille";
    return (x < 0 || x > 20) && y < 12 ? "plating" : "floor";
  }
  function draw(canvas) {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    canvas.width = Math.round(rect.width);
    canvas.height = Math.round(rect.height);
    const ctx = canvas.getContext("2d");
    ctx.imageSmoothingEnabled = false;
    const tile = 64;
    const ox = Math.round(canvas.width / 2 - 10.5 * tile);
    const oy = Math.round(canvas.height / 2 - 7.5 * tile);
    views.set(canvas, { ox, oy, tile });
    const paint = (name, x, y, size = tile) => {
      const source = cell(name);
      if (!source || !images[source.page].complete) return;
      ctx.drawImage(images[source.page], source.x, source.y, atlas.tile, atlas.tile,
        ox + x * tile, oy + y * tile, size, size);
    };
    ctx.fillStyle = "#080c11";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    for (let y = Math.floor(-oy / tile); y < Math.ceil((canvas.height - oy) / tile); y++)
      for (let x = Math.floor(-ox / tile); x < Math.ceil((canvas.width - ox) / tile); x++) {
      paint((x < 0 || x > 20) && y < 12 ? "plating" : "floor", x, y);
      paint(tileSprite(x, y), x, y);
    }
    for (let x = 4; x <= 8; x++) paint("reinforced_floor", x, 4);
    for (let x = 12; x <= 16; x++) paint("reinforced_floor", x, 4);
    for (const [name, x, y] of [
      ...fixtures, ["grille", 16, 7], ["window", 16, 7],
      ["grille", 16, 8], ["window", 16, 8], ["grille", 16, 9], ["window", 16, 9],
    ]) paint(name, x, y);
    ctx.fillStyle = "#4c5761";
    ctx.font = "bold 15px monospace";
    ctx.textAlign = "center";
    ctx.fillText("ENGINEERING", ox + 10.5 * tile, oy + 4.3 * tile);
    if (role === "crew") {
      for (const name of ["human_s", "worn_uniform_eng_s", "worn_backpack_s", "hair_bedhead_s"])
        paint(name, 10, 7);
    } else {
      // No robot/core sprite is baked; a schematic marker identifies the viewpoint.
      const x = ox + 10.5 * tile, y = oy + 7.5 * tile;
      ctx.fillStyle = "#13282fe8";
      ctx.fillRect(x - 25, y - 21, 50, 42);
      ctx.strokeStyle = "#91ccd5";
      ctx.lineWidth = 2;
      ctx.strokeRect(x - 25, y - 21, 50, 42);
      ctx.fillStyle = "#b4dce0";
      ctx.font = "bold 12px monospace";
      ctx.fillText(role === "ai" ? "CAM" : "UNIT", x, y + 4);
    }
    for (const name of ["human_w", "worn_uniform_eng_w", "hair_bedhead_w"])
      paint(name, 13, 10);
    const shade = ctx.createRadialGradient(canvas.width / 2, canvas.height / 2, 100,
      canvas.width / 2, canvas.height / 2, Math.max(canvas.width, canvas.height) * 0.65);
    shade.addColorStop(0, "#02060a00");
    shade.addColorStop(1, "#02060abb");
    ctx.fillStyle = shade;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
  function inspect(canvas, clientX, clientY) {
    const view = views.get(canvas);
    if (!view) return { key: "floor", title: "Floor", sprite: "floor", lines: ["A tiled station floor."] };
    const rect = canvas.getBoundingClientRect();
    const x = Math.floor((clientX - rect.left - view.ox) / view.tile);
    const y = Math.floor((clientY - rect.top - view.oy) / view.tile);
    const item = fixtures.find(item => item[1] === x && item[2] === y);
    const tile = tileSprite(x, y);
    const labels = { floor: "Floor", plating: "Exposed plating", wall: "Wall", reinforced_wall: "Reinforced wall", grille: "Grille" };
    return item ? { key: `${x},${y}`, title: item[3], sprite: item[0], lines: item.slice(4) }
      : { key: `tile:${x},${y}`, title: labels[tile], sprite: tile, lines: [tile === "floor" ? "A tiled station floor." : "Part of the station structure."] };
  }
  window.ConceptScene = { sprite, draw, ready, inspect, setRole: value => { role = value; } };
})();
