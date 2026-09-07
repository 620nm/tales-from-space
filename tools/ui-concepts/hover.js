// Transparent pointer feedback in the trusted mock; no guest DOM or geometry API.
(() => {
  let canvas, stage, hint, pointer, initialized = false;
  const scene = window.ConceptScene;
  function text(tag, value, className = '') {
    const node = document.createElement(tag); node.textContent = value; node.className = className; return node;
  }
  function hide() {
    pointer = null;
    if (!hint) return;
    hint.hidden = true; delete hint.dataset.target; delete hint.dataset.primitive; scene.highlight(canvas, null);
  }
  function update() {
    if (!pointer) return;
    if (document.elementFromPoint(pointer.x, pointer.y) !== canvas) { hide(); return; }
    const hit = scene.pick(canvas, pointer.x, pointer.y);
    if (!hit) { hide(); return; }
    hint.replaceChildren(); hint.dataset.target = hit.owner; hint.dataset.primitive = hit.id;
    const heading = text('div', '', 'hover-heading');
    heading.append(scene.icon(canvas, hit, 32), text('strong', hit.title)); hint.append(heading);
    const row = (gesture, action, unavailable = false) => {
      const line = text('div', '', `hover-gesture${unavailable ? ' unavailable' : ''}`);
      line.append(text('span', gesture), text('span', action)); hint.append(line);
    };
    const crew = scene.getRole() === 'crew';
    if (crew && ['portable', 'laptop'].includes(hit.kind)) {
      const available = window.ConceptHands?.canTake?.() === true;
      row('Click', available ? 'Take' : 'Take · free a hand', !available);
    }
    if (hit.kind === 'laptop') row('Right-click', hit.item.closed ? 'Open lid' : 'Close lid');
    row('Shift + click', 'Inspect');
    if (hit.kind === 'laptop') row('Alt + click', 'View interface');
    hint.hidden = false;
    const rect = stage.getBoundingClientRect();
    hint.style.maxWidth = `${Math.max(0, Math.min(290, rect.width - 24))}px`;
    const width = hint.offsetWidth, height = hint.offsetHeight;
    let left = pointer.x + 20;
    if (left + width > rect.right - 10) left = pointer.x - width - 20;
    left = Math.max(rect.left + 8, Math.min(left, rect.right - width - 8));
    const top = Math.max(rect.top + 8, Math.min(pointer.y - 8, rect.bottom - height - 8));
    hint.style.left = `${left}px`; hint.style.top = `${top}px`;
    scene.highlight(canvas, hit.id);
  }
  function init() {
    if (initialized) return;
    canvas = document.querySelector('#world'); stage = document.querySelector('#stage');
    if (!canvas || !stage) return;
    initialized = true;
    hint = text('div', ''); hint.id = 'hover-hint'; hint.hidden = true; hint.setAttribute('role', 'tooltip');
    stage.append(hint);
    canvas.addEventListener('pointermove', event => { pointer = {x: event.clientX, y: event.clientY}; update(); });
    canvas.addEventListener('pointerleave', hide);
    canvas.addEventListener('click', event => {
      const hit = scene.pick(canvas, event.clientX, event.clientY);
      if (!hit) return;
      event.preventDefault(); event.stopImmediatePropagation();
      if (event.shiftKey) window.ConceptSurfaces.inspect(scene.inspect(canvas, event.clientX, event.clientY));
      else if (event.altKey) scene.act(canvas, hit, 'interface');
      else scene.act(canvas, hit, 'take');
      update();
    });
    canvas.addEventListener('contextmenu', event => {
      const hit = scene.pick(canvas, event.clientX, event.clientY);
      if (hit?.kind !== 'laptop') return;
      event.preventDefault(); event.stopImmediatePropagation(); scene.act(canvas, hit, 'lid'); update();
    });
    ['concept-hands-change', 'concept-scene-change'].forEach(type => document.addEventListener(type, update));
    window.addEventListener('blur', hide);
    document.addEventListener('visibilitychange', () => { if (document.hidden) hide(); });
  }
  window.ConceptHover = {init, hide, update};
})();
