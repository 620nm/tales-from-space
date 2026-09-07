// Trusted illustrative scene; draw order, cached source pixels and picking share one list.
(() => {
  const atlas = window.conceptAtlas, picking = window.ConceptPicking;
  const {fixtures, service, tileSprite} = window.ConceptSceneData;
  const stride = atlas.tile + atlas.pad * 2, pageCells = atlas.columns * atlas.rows_per_page;
  const images = atlas.pages.map(url => { const image = new Image(); image.src = url; return image; });
  const ready = Promise.all(images.map(image => image.decode()));
  const views = new WeakMap(), cache = new Map();
  let role = 'crew';
  function cell(name) {
    const index = atlas.sprites[name];
    if (index === undefined) return null;
    const local = index % pageCells;
    return {page: Math.floor(index / pageCells), x: (local % atlas.columns) * stride + atlas.pad,
      y: Math.floor(local / atlas.columns) * stride + atlas.pad};
  }
  function raster(name, tint = '') {
    const key = `${name}:${tint}`;
    if (cache.has(key)) return cache.get(key);
    const source = cell(name);
    if (!source || !images[source.page].complete || !images[source.page].naturalWidth) return null;
    const image = document.createElement('canvas'); image.width = image.height = atlas.tile;
    const ctx = image.getContext('2d', {willReadFrequently: true});
    ctx.drawImage(images[source.page], source.x, source.y, atlas.tile, atlas.tile, 0, 0, atlas.tile, atlas.tile);
    const pixels = ctx.getImageData(0, 0, atlas.tile, atlas.tile), alpha = new Uint8Array(atlas.tile ** 2);
    const rgb = tint ? tint.match(/[a-f\d]{2}/gi).map(part => parseInt(part, 16)) : null;
    for (let index = 0; index < alpha.length; index++) {
      alpha[index] = pixels.data[index * 4 + 3];
      if (rgb) for (let channel = 0; channel < 3; channel++) pixels.data[index * 4 + channel] *= rgb[channel] / 255;
    }
    ctx.putImageData(pixels, 0, 0);
    const result = {image, alpha, width: atlas.tile, height: atlas.tile}; cache.set(key, result); return result;
  }
  function sprite(name, label, size = 32) {
    const node = document.createElement('span'); node.className = 'sprite';
    node.setAttribute('role', 'img'); node.setAttribute('aria-label', label ?? name);
    Object.assign(node.style, {display: 'inline-block', flexShrink: '0', width: `${size}px`, height: `${size}px`, imageRendering: 'pixelated'});
    const source = cell(name);
    if (!source) { node.textContent = '·'; return node; }
    const scale = size / atlas.tile;
    const rows = Math.ceil(Math.min(pageCells, atlas.cells - source.page * pageCells) / atlas.columns);
    Object.assign(node.style, {backgroundImage: `url("${atlas.pages[source.page]}")`,
      backgroundSize: `${atlas.columns * stride * scale}px ${rows * stride * scale}px`,
      backgroundPosition: `${-source.x * scale}px ${-source.y * scale}px`, backgroundRepeat: 'no-repeat'});
    return node;
  }
  function highlighted(source) {
    if (source.highlighted) return source.highlighted;
    const canvas = document.createElement('canvas'); canvas.width = source.width; canvas.height = source.height;
    const ctx = canvas.getContext('2d'); ctx.drawImage(source.image, 0, 0);
    const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height);
    for (let index = 0; index < source.alpha.length; index++) {
      if (!source.alpha[index]) continue;
      for (let channel = 0; channel < 3; channel++) {
        const offset = index * 4 + channel;
        pixels.data[offset] += (255 - pixels.data[offset]) * .25;
      }
    }
    ctx.putImageData(pixels, 0, 0); source.highlighted = canvas; return canvas;
  }
  function render(canvas, view) {
    const ctx = canvas.getContext('2d'); ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#080c11'; ctx.fillRect(0, 0, canvas.width, canvas.height);
    for (const primitive of view.primitives) {
      const {x, y, width, height, raster: source} = primitive;
      const image = primitive.owner === view.hover ? highlighted(source) : source.image;
      ctx.drawImage(image, x, y, width, height);
    }
    ctx.fillStyle = '#65747c'; ctx.font = 'bold 15px monospace'; ctx.textAlign = 'center';
    ctx.fillText('ENGINEERING', view.ox + 10.5 * view.tile, view.oy + 4.3 * view.tile);
    ctx.font = '10px monospace'; ctx.fillStyle = '#8d9b96';
    ctx.fillText('EXPOSED SERVICE RUN', view.ox + 12.5 * view.tile, view.oy + 5.85 * view.tile);
    const shade = ctx.createRadialGradient(canvas.width / 2, canvas.height / 2, 100,
      canvas.width / 2, canvas.height / 2, Math.max(canvas.width, canvas.height) * .65);
    shade.addColorStop(0, '#02060a00'); shade.addColorStop(1, '#02060abb');
    ctx.fillStyle = shade; ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
  function draw(canvas) {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    canvas.width = Math.round(rect.width); canvas.height = Math.round(rect.height);
    const tile = 64, ox = Math.round(canvas.width / 2 - 10.5 * tile), oy = Math.round(canvas.height / 2 - 7.5 * tile);
    const view = {ox, oy, tile, primitives: [], hover: null}; views.set(canvas, view);
    function add(item, name = item.sprite, suffix = '') {
      const source = raster(name, item.tint); if (!source) return;
      view.primitives.push({id: `${item.key}${suffix}`, owner: item.key, sprite: name, frame: 0, tint: item.tint || '',
        x: ox + item.x * tile + (item.offsetX || 0), y: oy + item.y * tile + (item.offsetY || 0),
        width: tile, height: tile, raster: source, title: item.title, kind: item.kind, item});
    }
    for (let y = Math.floor(-oy / tile); y < Math.ceil((canvas.height - oy) / tile); y++)
      for (let x = Math.floor(-ox / tile); x < Math.ceil((canvas.width - ox) / tile); x++) {
        const name = tileSprite(x, y), labels = {floor: 'Floor', plating: 'Exposed plating', wall: 'Wall', reinforced_wall: 'Reinforced wall', grille: 'Grille'};
        const tileItem = {key: `tile:${x},${y}`, x, y, title: labels[name], kind: 'terrain', lines: ['Part of the station structure.']};
        add(tileItem, 'floor', ':base'); add(tileItem, name);
      }
    for (const x of [4, 5, 6, 7, 8, 12, 13, 14, 15, 16]) add({key: `reinforced:${x},4`, x, y: 4,
      title: 'Reinforced floor', kind: 'terrain', lines: ['A reinforced station floor.']}, 'reinforced_floor');
    service.forEach(item => add(item)); fixtures.filter(item => !item.taken).forEach(item => add(item));
    const actor = {key: 'actor:player', x: 10, y: 7, title: role === 'crew' ? 'Elias Voss' : role === 'ai' ? 'Camera viewpoint' : 'Engineering unit',
      kind: 'actor', lines: ['The controlled viewpoint in this local study.']};
    if (role === 'crew') ['human_s', 'worn_uniform_eng_s', 'worn_backpack_s', 'hair_bedhead_s'].forEach((name, index) => add(actor, name, `:${index}`));
    else {
      const image = document.createElement('canvas'); image.width = image.height = atlas.tile;
      const ctx = image.getContext('2d'); ctx.fillStyle = '#13282f'; ctx.fillRect(4, 6, 25, 21);
      ctx.strokeStyle = '#91ccd5'; ctx.strokeRect(4.5, 6.5, 24, 20);
      ctx.fillStyle = '#b4dce0'; ctx.font = 'bold 6px monospace'; ctx.textAlign = 'center'; ctx.fillText(role === 'ai' ? 'CAM' : 'UNIT', 16, 18);
      const pixels = ctx.getImageData(0, 0, atlas.tile, atlas.tile).data;
      view.primitives.push({id: actor.key, owner: actor.key, x: ox + 10 * tile, y: oy + 7 * tile, width: tile, height: tile,
        raster: {image, width: atlas.tile, height: atlas.tile, alpha: Uint8Array.from({length: atlas.tile ** 2}, (_, i) => pixels[i * 4 + 3])},
        sprite: '', frame: 0, tint: '', title: actor.title, kind: actor.kind, item: actor});
    }
    const npc = {key: 'actor:engineer', x: 13, y: 10, title: 'Station engineer', kind: 'actor', lines: ['An engineer at work.']};
    ['human_w', 'worn_uniform_eng_w', 'hair_bedhead_w'].forEach((name, index) => add(npc, name, `:${index}`));
    render(canvas, view); document.dispatchEvent(new CustomEvent('concept-scene-change'));
  }
  function pick(canvas, clientX, clientY) {
    const rect = canvas.getBoundingClientRect(), view = views.get(canvas);
    if (!view || clientX < rect.left || clientX >= rect.right || clientY < rect.top || clientY >= rect.bottom) return null;
    return picking.pick(view.primitives, (clientX - rect.left) * canvas.width / rect.width, (clientY - rect.top) * canvas.height / rect.height);
  }
  function inspect(canvas, clientX, clientY) {
    const hit = pick(canvas, clientX, clientY);
    return hit ? {key: hit.owner, title: hit.title, sprite: hit.sprite, lines: hit.item.lines} : null;
  }
  function icon(canvas, hit, size = 24) {
    const node = document.createElement('canvas'); node.width = node.height = atlas.tile;
    node.className = 'hover-sprite'; node.style.width = node.style.height = `${size}px`;
    node.setAttribute('role', 'img'); node.setAttribute('aria-label', hit.title);
    const ctx = node.getContext('2d'); ctx.imageSmoothingEnabled = false;
    for (const part of views.get(canvas).primitives.filter(part => part.owner === hit.owner))
      ctx.drawImage(part.raster.image, (part.x - hit.x) / hit.width * atlas.tile, (part.y - hit.y) / hit.height * atlas.tile,
        part.width / hit.width * atlas.tile, part.height / hit.height * atlas.tile);
    return node;
  }
  function highlight(canvas, owner) {
    const view = views.get(canvas); if (!view || view.hover === owner) return;
    view.hover = owner; render(canvas, view);
  }
  function act(canvas, hit, action) {
    const item = hit?.item; if (!item || item.taken) return false;
    if (action === 'take' && role === 'crew' && ['portable', 'laptop'].includes(item.kind)) {
      const accepted = !document.dispatchEvent(new CustomEvent('concept-take', {cancelable: true,
        detail: {key: item.key, sprite: item.sprite, title: item.title}}));
      if (!accepted) return false; item.taken = true;
    } else if (item.kind === 'laptop' && action === 'lid') {
      item.closed = !item.closed; item.sprite = item.closed ? 'laptop_closed' : 'laptop_on';
      item.lines = [item.closed ? 'The laptop lid is closed.' : 'The atmospheric monitor is open.'];
    } else if (item.kind === 'laptop' && action === 'interface') window.ConceptSurfaces.open('device');
    else return false;
    draw(canvas); return true;
  }
  function sampleClientPoints(canvas) {
    const view = views.get(canvas), rect = canvas.getBoundingClientRect(), result = [];
    if (!view) return result;
    for (const candidate of view.primitives.filter(part => part.kind !== 'terrain')) {
      const nearby = view.primitives.filter(part => part.x < candidate.x + candidate.width && part.x + part.width > candidate.x
        && part.y < candidate.y + candidate.height && part.y + part.height > candidate.y);
      let sample;
      for (let sy = 0; sy < candidate.raster.height; sy++) for (let sx = 0; sx < candidate.raster.width; sx++) {
        const x = candidate.x + (sx + .5) * candidate.width / candidate.raster.width;
        const y = candidate.y + (sy + .5) * candidate.height / candidate.raster.height;
        if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height || picking.pick(nearby, x, y)?.id !== candidate.id) continue;
        const overlapping = nearby.filter(part => picking.opaqueAt(part, x, y)).map(part => part.id);
        if (!sample || overlapping.length > sample.overlapping.length) sample = {id: candidate.id, owner: candidate.owner, title: candidate.title,
          clientX: rect.left + x * rect.width / canvas.width, clientY: rect.top + y * rect.height / canvas.height, overlapping};
      }
      if (sample) result.push(sample);
    }
    return result;
  }
  window.ConceptScene = {sprite, draw, ready, inspect, pick, icon, highlight, act, sampleClientPoints,
    candidates: canvas => views.get(canvas)?.primitives || [], getRole: () => role, setRole: value => { role = value; }};
})();
