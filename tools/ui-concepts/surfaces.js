// Trusted local prototype: production surface geometry and clocks belong to the host.
(() => {
  const windows = new Map(), visible = new Map(), history = [];
  let stage, toastRoot, historyView, historyList, initialized = false;
  const HOLD = 8000, FADE = 450;
  const reduced = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function button(label, action) {
    const node = element('button', '', label);
    node.type = 'button'; node.addEventListener('click', action);
    return node;
  }
  function bounds(record) {
    const width = stage.clientWidth, height = stage.clientHeight, g = record.geometry;
    g.width = clamp(g.width, Math.min(260, width), width);
    g.height = clamp(g.height, Math.min(170, height), height);
    g.left = clamp(g.left, 0, Math.max(0, width - g.width));
    g.top = clamp(g.top, 0, Math.max(0, height - g.height));
    Object.assign(record.node.style, {
      left: `${g.left}px`, top: `${g.top}px`, width: `${g.width}px`, height: `${g.height}px`, right: 'auto', bottom: 'auto',
    });
  }
  function raise(record) {
    windows.delete(record.node.id); windows.set(record.node.id, record);
    let layer = 30;
    windows.forEach(window => { window.node.style.zIndex = String(++layer); });
  }
  function initial(record) {
    const {node, index} = record, data = node.dataset;
    const box = node.getBoundingClientRect(), area = stage.getBoundingClientRect();
    const value = (key, fallback) => data[key] === undefined ? fallback : Number(data[key]);
    const width = value('windowWidth', node.style.width ? box.width : index ? 350 : 330);
    const height = value('windowHeight', node.style.height ? box.height : index ? 280 : 310);
    record.geometry = {
      width, height,
      left: value('windowLeft', node.style.left ? box.left - area.left : index ? (stage.clientWidth - width) / 2 : stage.clientWidth - width - 24),
      top: value('windowTop', node.style.top ? box.top - area.top : index ? 178 : 72),
    };
  }
  function open(id) {
    const record = windows.get(id);
    if (!record) return;
    if (record.node.hidden) record.returnFocus = document.activeElement;
    record.node.hidden = false;
    if (!record.geometry) initial(record);
    bounds(record); raise(record); record.title.focus({preventScroll: true});
    document.querySelector(`[aria-controls="${id}"]`)?.setAttribute('aria-expanded', 'true');
  }
  function close(id) {
    const record = windows.get(id);
    if (!record) return;
    const restore = record.node.contains(document.activeElement);
    record.cancel?.(); record.node.hidden = true;
    document.querySelector(`[aria-controls="${id}"]`)?.setAttribute('aria-expanded', 'false');
    if (restore && record.returnFocus?.isConnected) record.returnFocus.focus({preventScroll: true});
  }
  function gesture(event, record, direction = '') {
    if (event.button !== 0 || record.cancel) return;
    if (!direction && event.target.closest('button,input,select,textarea,a')) return;
    event.preventDefault(); event.stopPropagation(); raise(record);
    record.title.focus({preventScroll: true});
    const target = event.currentTarget, pointer = event.pointerId;
    const origin = {...record.geometry}, x = event.clientX, y = event.clientY;
    target.setPointerCapture(pointer); record.node.classList.add('surface-dragging');
    function move(e) {
      if (e.pointerId !== pointer) return;
      const dx = e.clientX - x, dy = e.clientY - y;
      const g = record.geometry = {...origin};
      if (!direction) { g.left += dx; g.top += dy; }
      else {
        const minWidth = Math.min(260, stage.clientWidth), minHeight = Math.min(170, stage.clientHeight);
        if (direction.includes('e')) g.width = clamp(origin.width + dx, minWidth, stage.clientWidth - origin.left);
        if (direction.includes('s')) g.height = clamp(origin.height + dy, minHeight, stage.clientHeight - origin.top);
        if (direction.includes('w')) {
          g.left = clamp(origin.left + dx, 0, origin.left + origin.width - minWidth);
          g.width = origin.left + origin.width - g.left;
        }
        if (direction.includes('n')) {
          g.top = clamp(origin.top + dy, 0, origin.top + origin.height - minHeight);
          g.height = origin.top + origin.height - g.top;
        }
      }
      bounds(record); e.stopPropagation();
    }
    function finish(e) {
      if (e && e.pointerId !== pointer) return;
      target.removeEventListener('pointermove', move);
      ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(type => target.removeEventListener(type, finish));
      record.cancel = null; record.node.classList.remove('surface-dragging');
      if (target.hasPointerCapture(pointer)) target.releasePointerCapture(pointer);
    }
    record.cancel = finish;
    target.addEventListener('pointermove', move);
    ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(type => target.addEventListener(type, finish));
  }
  function prepareWindow(node, index) {
    const title = node.querySelector('[data-window-title]'), closer = node.querySelector('[data-window-close]');
    if (!title || !closer) return;
    const record = {node, title, index}; windows.set(node.id, record);
    node.setAttribute('role', 'dialog'); node.setAttribute('aria-modal', 'false');
    title.tabIndex = 0;
    title.setAttribute('aria-label', `${node.getAttribute('aria-label') || 'Device window'}: drag to move`);
    title.setAttribute('aria-description', 'Arrow keys move this window. Shift and arrow keys resize it.');
    closer.setAttribute('aria-label', 'Close device window');
    closer.addEventListener('click', () => close(node.id));
    node.addEventListener('pointerdown', event => { raise(record); event.stopPropagation(); });
    node.addEventListener('click', event => event.stopPropagation());
    node.addEventListener('focusin', () => raise(record));
    title.addEventListener('pointerdown', event => gesture(event, record));
    title.addEventListener('keydown', event => {
      if (event.target !== title || !['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;
      event.preventDefault(); event.stopPropagation();
      const horizontal = event.key === 'ArrowLeft' || event.key === 'ArrowRight';
      const delta = event.key === 'ArrowLeft' || event.key === 'ArrowUp' ? -12 : 12;
      record.geometry[event.shiftKey ? horizontal ? 'width' : 'height' : horizontal ? 'left' : 'top'] += delta;
      bounds(record); raise(record);
    });
    ['n','ne','e','se','s','sw','w','nw'].forEach(direction => {
      const handle = element('span', `surface-resize surface-resize-${direction}`);
      handle.dataset.resize = direction; handle.setAttribute('aria-hidden', 'true');
      handle.addEventListener('pointerdown', event => gesture(event, record, direction)); node.append(handle);
    });
    if (!node.hidden) { initial(record); bounds(record); }
  }
  function stopTimer(record) {
    clearTimeout(record.timer); clearTimeout(record.fadeTimer);
    if (record.started) record.remaining = Math.max(0, record.remaining - (performance.now() - record.started));
    record.started = 0; record.node.classList.remove('inspect-fading');
  }
  function removeToast(record) {
    stopTimer(record); record.node.remove(); visible.delete(record.data.key);
  }
  function startTimer(record) {
    if (record.started || record.pinned || record.hover || record.node.contains(document.activeElement)) return;
    record.started = performance.now();
    record.timer = setTimeout(() => {
      record.remaining = 0; record.started = 0; record.node.classList.add('inspect-fading');
      record.fadeTimer = setTimeout(() => removeToast(record), reduced() ? 0 : FADE);
    }, record.remaining);
  }
  function renderHistory() {
    historyView.hidden = !history.length;
    historyView.querySelector('summary').textContent = `Inspect history · ${history.length}`;
    historyList.replaceChildren();
    [...history].reverse().forEach(data => {
      const item = element('li');
      item.dataset.inspectKey = data.key;
      item.append(button(data.title, () => { historyView.open = false; inspect(data); }));
      data.lines.forEach(line => item.append(element('p', '', line)));
      historyList.append(item);
    });
  }
  function inspect(input) {
    if (!initialized || !input) return;
    const data = {key: String(input.key ?? input.title), title: String(input.title || 'Inspect'),
      sprite: input.sprite, lines: (input.lines || []).map(String)};
    const prior = history.findIndex(item => item.key === data.key);
    if (prior >= 0) history.splice(prior, 1);
    history.push(data); if (history.length > 20) history.shift(); renderHistory();
    const existing = visible.get(data.key);
    const pinned = existing?.pinned || false;
    if (existing) removeToast(existing);
    if (visible.size >= 3) removeToast([...visible.values()].find(item => !item.pinned) || visible.values().next().value);
    const node = element('article', 'inspect-toast');
    node.setAttribute('aria-label', data.title); node.tabIndex = 0;
    const record = {node, data, pinned, remaining: HOLD, started: 0, hover: false};
    const heading = element('div', 'inspect-heading');
    if (data.sprite && window.ConceptScene?.sprite) heading.append(window.ConceptScene.sprite(data.sprite, '', 24));
    heading.append(element('strong', '', data.title));
    const pin = button(pinned ? 'Unpin' : 'Pin', () => {
      stopTimer(record); record.pinned = !record.pinned; record.remaining = HOLD;
      pin.textContent = record.pinned ? 'Unpin' : 'Pin'; pin.setAttribute('aria-pressed', String(record.pinned));
      node.classList.toggle('inspect-pinned', record.pinned); startTimer(record);
    });
    pin.title = 'Pause expiry; a full stack moves older inspections to history';
    pin.setAttribute('aria-pressed', String(pinned));
    const dismiss = button('×', () => { removeToast(record); historyView.querySelector('summary').focus(); });
    dismiss.setAttribute('aria-label', `Dismiss inspection of ${data.title}`);
    heading.append(pin, dismiss); node.append(heading);
    node.append(element('p', 'inspect-preview', data.lines.slice(0, 3).join(' ')));
    node.append(button('Read full inspection', () => {
      historyView.open = true; historyView.querySelector('summary').focus();
      [...historyList.children].find(item => item.dataset.inspectKey === data.key)?.scrollIntoView({block: 'nearest'});
    }));
    node.classList.toggle('inspect-pinned', pinned);
    node.addEventListener('pointerenter', () => { record.hover = true; stopTimer(record); });
    node.addEventListener('pointerleave', () => { record.hover = false; startTimer(record); });
    node.addEventListener('focusin', () => stopTimer(record));
    node.addEventListener('focusout', () => queueMicrotask(() => {
      if (visible.get(data.key) === record) startTimer(record);
    }));
    visible.set(data.key, record); toastRoot.insertBefore(node, historyView); startTimer(record);
  }
  function demoInspect() {
    inspect({key: '9,5', title: 'Air sensor', sprite: 'pipe_meter',
      lines: ['Measures the local atmosphere.', 'Pressure: 101.3 kPa · Temperature: 293.2 K']});
  }
  function init() {
    if (initialized) return;
    stage = document.querySelector('#stage'); toastRoot = document.querySelector('#toasts');
    if (!stage || !toastRoot) return;
    initialized = true;
    stage.querySelectorAll('[data-window]').forEach(prepareWindow);
    new ResizeObserver(() => windows.forEach(record => { if (record.geometry) bounds(record); })).observe(stage);
    toastRoot.setAttribute('aria-live', 'polite'); toastRoot.setAttribute('aria-relevant', 'additions');
    historyView = element('details', 'inspect-history'); historyView.hidden = true;
    historyView.setAttribute('aria-live', 'off');
    historyView.append(element('summary', '', 'Inspect history'));
    historyList = element('ol'); historyView.append(historyList); toastRoot.append(historyView);
    toastRoot.addEventListener('pointerdown', event => event.stopPropagation());
    toastRoot.addEventListener('click', event => event.stopPropagation());
    document.querySelector('canvas#world')?.addEventListener('click', event => {
      if (!event.shiftKey) return;
      event.preventDefault(); event.stopImmediatePropagation();
      inspect(window.ConceptScene?.inspect?.(event.currentTarget, event.clientX, event.clientY));
    });
  }
  window.ConceptSurfaces = {init, open, close, inspect, demoInspect};
})();
