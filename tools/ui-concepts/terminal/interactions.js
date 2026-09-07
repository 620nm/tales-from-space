(function () {
  'use strict';
  let terminal, stage, drag = null, previous = null;
  const clamp = (value, low, high) => Math.max(low, Math.min(value, high));
  function bounds() { return { w: stage.clientWidth, h: stage.clientHeight }; }
  function geometry() {
    return { x: terminal.offsetLeft, y: terminal.offsetTop, w: terminal.offsetWidth, h: terminal.offsetHeight };
  }
  function fitFrames() {
    const frames = document.getElementById('frames'), both = frames.classList.contains('has-disk');
    const read = side => parseFloat(frames.style.getPropertyValue('--drive-' + side + '-width')) || 184;
    let a = clamp(read('a'), 144, 320), b = clamp(read('b'), 144, 320);
    const available = frames.clientWidth - 280 - (both ? 10 : 5);
    if (both && a + b > available) {
      const room = Math.max(0, available - 288), extras = Math.max(1, a + b - 288);
      const nextA = 144 + room * (a - 144) / extras;
      b = 144 + room * (b - 144) / extras; a = nextA;
    } else if (!both) a = Math.min(a, Math.max(144, available));
    frames.style.setProperty('--drive-a-width', Math.floor(a) + 'px');
    frames.style.setProperty('--drive-b-width', Math.floor(b) + 'px');
  }
  function place(rect) {
    const b = bounds(); rect.w = clamp(rect.w, Math.min(740, b.w), b.w);
    rect.h = clamp(rect.h, Math.min(410, b.h), b.h);
    rect.x = clamp(rect.x, 0, b.w - rect.w); rect.y = clamp(rect.y, 0, b.h - rect.h);
    Object.assign(terminal.style, { left: rect.x + 'px', top: rect.y + 'px', width: rect.w + 'px', height: rect.h + 'px' });
    fitFrames();
  }
  function stop() {
    if (!drag) return;
    const finished = drag; drag = null;
    finished.element.classList.remove('dragging');
    if (finished.element.hasPointerCapture(finished.pointerId)) finished.element.releasePointerCapture(finished.pointerId);
    document.body.classList.remove('is-dragging');
  }
  function begin(event, kind, edge) {
    if (event.button !== 0 || event.target.closest('button,input,textarea')) return;
    event.preventDefault(); previous = null;
    drag = { element: event.currentTarget, pointerId: event.pointerId, kind, edge, x: event.clientX, y: event.clientY, rect: geometry(),
      a: document.getElementById('drive-a').offsetWidth, b: document.getElementById('drive-b').offsetWidth };
    event.currentTarget.setPointerCapture(event.pointerId);
    event.currentTarget.classList.add('dragging'); document.body.classList.add('is-dragging');
  }
  function move(event) {
    if (!drag) return;
    const dx = event.clientX - drag.x, dy = event.clientY - drag.y;
    if (drag.kind === 'split') {
      const frames = document.getElementById('frames');
      const other = drag.edge === 'a' ? document.getElementById('drive-b').offsetWidth : document.getElementById('drive-a').offsetWidth;
      const max = Math.min(320, Math.max(144, frames.clientWidth - 280 - (frames.classList.contains('has-disk') ? other + 10 : 5)));
      const width = clamp((drag.edge === 'a' ? drag.a + dx : drag.b - dx), 144, max);
      frames.style.setProperty(drag.edge === 'a' ? '--drive-a-width' : '--drive-b-width', width + 'px');
      fitFrames();
      return;
    }
    const rect = { ...drag.rect };
    if (drag.kind === 'move') { rect.x += dx; rect.y += dy; }
    else {
      if (drag.edge.includes('e')) rect.w += dx;
      if (drag.edge.includes('s')) rect.h += dy;
      if (drag.edge.includes('w')) { const width = Math.max(Math.min(740, bounds().w), rect.w - dx); rect.x += rect.w - width; rect.w = width; }
      if (drag.edge.includes('n')) { const height = Math.max(Math.min(410, bounds().h), rect.h - dy); rect.y += rect.h - height; rect.h = height; }
    }
    place(rect);
  }
  function reset() {
    if (!terminal) return;
    previous = null;
    const b = bounds(); place({ x: (b.w - 1120) / 2, y: Math.min(110, Math.max(0, (b.h - 650) / 2)), w: 1120, h: 650 });
    document.getElementById('frames').style.removeProperty('--drive-a-width');
    document.getElementById('frames').style.removeProperty('--drive-b-width');
  }
  function init() {
    terminal = document.getElementById('terminal'); stage = document.getElementById('stage') || terminal.parentElement;
    document.getElementById('terminal-title').addEventListener('pointerdown', event => begin(event, 'move'));
    terminal.querySelectorAll('[data-resize]').forEach(el => el.addEventListener('pointerdown', event => begin(event, 'resize', el.dataset.resize)));
    ['a', 'b'].forEach(side => {
      const splitter = document.getElementById('split-' + side);
      splitter.addEventListener('pointerdown', event => begin(event, 'split', side));
      splitter.addEventListener('keydown', event => {
        if (!['ArrowLeft', 'ArrowRight'].includes(event.key)) return;
        event.preventDefault();
        const frames = document.getElementById('frames'), width = document.getElementById('drive-' + side).offsetWidth;
        const delta = (event.key === 'ArrowRight' ? 10 : -10) * (side === 'b' ? -1 : 1);
        frames.style.setProperty('--drive-' + side + '-width', width + delta + 'px'); fitFrames();
      });
    });
    document.addEventListener('pointermove', move); document.addEventListener('pointerup', stop);
    document.addEventListener('pointercancel', stop); window.addEventListener('blur', stop);
    document.addEventListener('keydown', event => { if (event.key === 'Escape' && drag) {
      const frames = document.getElementById('frames');
      frames.style.setProperty('--drive-a-width', drag.a + 'px');
      frames.style.setProperty('--drive-b-width', (drag.b || 184) + 'px');
      place(drag.rect); stop();
    } });
    document.getElementById('terminal-title').addEventListener('keydown', event => {
      if (event.target !== event.currentTarget || !event.key.startsWith('Arrow')) return;
      event.preventDefault(); const rect = geometry();
      const dx = event.key === 'ArrowLeft' ? -10 : event.key === 'ArrowRight' ? 10 : 0;
      const dy = event.key === 'ArrowUp' ? -10 : event.key === 'ArrowDown' ? 10 : 0;
      if (event.shiftKey) { rect.w += dx; rect.h += dy; } else { rect.x += dx; rect.y += dy; }
      place(rect);
    });
    document.getElementById('terminal-maximize')?.addEventListener('click', () => {
      if (previous) { const rect = previous; previous = null; place(rect); }
      else { previous = geometry(); const b = bounds(); place({ x: 0, y: 0, w: b.w, h: b.h }); }
    });
    window.addEventListener('resize', () => place(geometry())); place(geometry());
  }
  window.TerminalInteractions = { init, reset, fitFrames };
})();
