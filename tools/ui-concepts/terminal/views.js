(function () {
  'use strict';
  const node = (tag, cls, text) => {
    const el = document.createElement(tag);
    if (cls) el.className = cls;
    if (text !== undefined) el.textContent = text;
    return el;
  };
  const action = (label, fn, disabled) => {
    const button = node('button', 'tv-button', label);
    button.type = 'button'; button.disabled = !!disabled;
    button.addEventListener('click', fn || (() => {}));
    return button;
  };
  const size = file => new TextEncoder().encode(file.body || '').length;
  const sprite = (name, cls = '') => {
    const img = node('img', `tv-sprite ${cls}`);
    img.src = `sprites/${name}.png`; img.width = 32; img.height = 32; img.alt = '';
    return img;
  };
  const formatSize = n => n < 1024 ? `${n} B` : `${(n / 1024).toFixed(1)} K`;
  function drive(root, side, files, selected, callbacks) {
    side = side.toUpperCase();
    selected = files.some(file => file.id === selected) ? selected : null;
    root.replaceChildren(); root.classList.add('tv-drive');
    const header = node('div', 'tv-drive-heading');
    header.append(node('span', 'tv-drive-letter', `${side}:`), node('div', '', side === 'A' ? 'LOCAL MACHINE' : callbacks.diskName || 'FIELD ARCHIVE'));
    root.append(header, node('div', 'tv-drive-path', `${side}:\\  /  ${files.length}${callbacks.fileCapacity ? ' of ' + callbacks.fileCapacity : ''} files`));
    const list = node('div', 'tv-file-list');
    files.forEach(file => {
      const row = action('', () => callbacks.onSelect(file.id));
      row.className = `tv-file${selected === file.id ? ' selected' : ''}`;
      row.dataset.fileId = file.id;
      row.title = `${file.name} · ${formatSize(size(file))}`;
      row.append(sprite(`file-${file.type}`, 'tv-file-icon'));
      const description = node('span', 'tv-file-description');
      description.append(node('span', 'tv-file-name', `${file.name}${file.dirty ? ' •' : ''}`), node('small', '', `${file.type.toUpperCase()} · ${formatSize(size(file))}`));
      row.append(description); list.append(row);
    });
    if (!files.length) list.append(node('p', 'tv-empty', side === 'B' && callbacks.empty ? 'No disk in drive.' : 'This drive is empty.'));
    root.append(list);
    const footer = node('div', 'tv-drive-footer');
    const total = callbacks.usage ?? files.reduce((n, f) => n + size(f), 0);
    const capacity = callbacks.capacity || (side === 'A' ? 65536 : 16384);
    footer.append(node('div', 'tv-capacity-label', `${formatSize(total)} / ${formatSize(capacity)}`));
    const meter = node('div', 'tv-capacity');
    const fill = node('span'); fill.style.width = `${Math.min(100, total / capacity * 100)}%`; meter.append(fill); footer.append(meter);
    const tools = node('div', 'tv-drive-tools');
    tools.append(action('New', callbacks.onNew, callbacks.empty), action(side === 'A' ? 'Copy →' : '← Copy', () => callbacks.onCopy(selected), !selected || callbacks.copyAllowed === false), action('Rename', () => callbacks.onRename(selected), !selected), action('Delete', () => callbacks.onDelete(selected), !selected));
    footer.append(tools);
    if (side === 'B') footer.append(action('⏏ Eject disk', callbacks.onEject, callbacks.empty));
    root.append(footer);
  }
  function highlight(root, value) {
    root.replaceChildren();
    const token = /(--[^\n]*|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|\b(?:local|function|end|if|then|else|elseif|return|for|in|do|while|true|false|nil|and|or|not|break)\b|\b\d+(?:\.\d+)?\b)/g;
    let start = 0;
    for (const match of value.matchAll(token)) {
      root.append(document.createTextNode(value.slice(start, match.index)));
      const text = match[0];
      root.append(node('span', text.startsWith('--') ? 'tv-comment' : /^["']/.test(text) ? 'tv-string' : /^\d/.test(text) ? 'tv-number' : 'tv-keyword', text));
      start = match.index + text.length;
    }
    root.append(document.createTextNode(value.slice(start) + '\n'));
  }
  function inline(el, text) {
    // Only inline code and emphasis are recognized; all supplied text stays text.
    for (const part of text.split(/(`[^`]+`|\*\*[^*]+\*\*)/g)) {
      if (part.startsWith('`') && part.endsWith('`')) el.append(node('code', '', part.slice(1, -1)));
      else if (part.startsWith('**') && part.endsWith('**')) el.append(node('strong', '', part.slice(2, -2)));
      else el.append(document.createTextNode(part));
    }
  }
  function markdown(body) {
    const page = node('article', 'tv-document');
    let code = null;
    for (const line of body.slice(0, 100000).split('\n').slice(0, 2000)) {
      if (line.startsWith('```')) {
        if (code) code = null;
        else { code = node('pre', 'tv-doc-code'); page.append(code); }
        continue;
      }
      if (code) { code.append(document.createTextNode(line + '\n')); continue; }
      if (!line.trim()) continue;
      const heading = line.match(/^(#{1,3})\s+(.*)$/);
      let el;
      if (heading) { el = node(`h${heading[1].length}`); inline(el, heading[2]); }
      else if (/^[-*] /.test(line)) { el = node('div', 'tv-doc-list'); inline(el, '•  ' + line.slice(2)); }
      else if (/^> /.test(line)) { el = node('blockquote'); inline(el, line.slice(2)); }
      else if (/^---+$/.test(line)) el = node('hr');
      else { el = node('p'); inline(el, line); }
      page.append(el);
    }
    return page;
  }
  function atmosphere(body) {
    const page = node('article', 'tv-atmo');
    let record;
    try { record = JSON.parse(body); } catch (_) { record = {}; }
    if (!record || typeof record !== 'object' || Array.isArray(record)) record = {};
    page.append(node('div', 'tv-record-label', 'ATMOSPHERIC SURVEY / STORED RECORD'), node('h2', '', record.label || record.location || record.area || 'Atmospheric record'), node('p', 'tv-record-meta', record.timestamp || record.captured || 'Snapshot · local instrument capture'));
    const table = node('table', 'tv-record-table');
    const readings = record.readings && typeof record.readings === 'object' ? record.readings : { Pressure: `${record.pressure_kpa ?? '—'} kPa`, Temperature: `${record.temperature_k ?? '—'} K`, Filter: record.filter || '—', 'Instrument state': record.enabled ? 'ENABLED' : 'DISABLED' };
    const entries = Array.isArray(readings) ? readings.filter(r => r && typeof r === 'object').slice(0, 100).map(r => [r.label || r.name || 'Reading', `${r.value ?? '—'} ${r.unit || ''}`]) : Object.entries(readings).slice(0, 100);
    entries.forEach(([label, value]) => {
      const row = node('tr');
      row.append(node('th', '', label), node('td', '', value && typeof value === 'object' ? `${value.value ?? '—'} ${value.unit || ''}` : String(value ?? '—'))); table.append(row);
    });
    page.append(table, node('div', 'tv-record-label', 'PRESSURE HISTORY / STORED SAMPLES'));
    const trend = node('div', 'tv-trend');
    const historySource = record.history ?? record.pressureHistory;
    const history = Array.isArray(historySource) ? historySource.slice(-24).filter(value => value !== null) : [];
    history.forEach(value => { const bar = node('span'); const n = Number(typeof value === 'object' ? value.value : value); bar.style.height = `${Number.isFinite(n) ? Math.max(10, Math.min(100, 45 + (n - 101) * 45)) : 10}%`; bar.title = `${n} kPa`; trend.append(bar); });
    if (!history.length) trend.append(node('p', 'tv-record-meta', 'No history samples in this record.'));
    page.append(trend, node('p', 'tv-atmo-note', record.note || 'Recorded values are a file snapshot. No live sensor connection.'));
    return page;
  }
  function render(root, file, callbacks) {
    root.classList.add('tv-view');
    if (!file) { root.replaceChildren(node('div', 'tv-no-file', 'Select a file to open it.')); root._tv = null; return; }
    const mode = file.mode || (file.type === 'atmo' ? 'custom' : file.type === 'md' ? 'preview' : 'code');
    const key = `${file.id}/${mode}`;
    if (root._tv && root._tv.key === key) {
      root._tv.callbacks = callbacks;
      root._tv.dirty.textContent = file.dirty ? '● UNSAVED' : 'SAVED';
      root._tv.title.textContent = `${file.side.toUpperCase()}:\\${file.name}`;
      root._tv.save.disabled = !file.dirty; root._tv.revert.disabled = !file.dirty;
      root._tv.diagnostic.textContent = file.diagnostic || '';
      root._tv.diagnostic.hidden = !file.diagnostic;
      if (root._tv.input && root._tv.input.value !== file.body) { root._tv.input.value = file.body; root._tv.refresh(); }
      if (root._tv.page && root._tv.body !== file.body) {
        const page = mode === 'preview' ? markdown(file.body) : atmosphere(file.body);
        root._tv.page.replaceWith(page); root._tv.page = page;
      }
      root._tv.body = file.body;
      return;
    }
    root.replaceChildren();
    const state = root._tv = { key, callbacks, body: file.body };
    const header = node('div', 'tv-view-heading');
    state.title = node('span', 'tv-view-path', `${file.side.toUpperCase()}:\\${file.name}`);
    state.dirty = node('span', 'tv-dirty', file.dirty ? '● UNSAVED' : 'SAVED');
    state.dirty.dataset.dirtyIndicator = '';
    header.append(sprite(`file-${file.type}`), state.title, state.dirty, node('span', 'tv-file-kind', file.type === 'disl' ? 'DiSL SOURCE' : file.type === 'md' ? 'MARKDOWN DOCUMENT' : file.type === 'pem' ? 'ACCESS MATERIAL' : 'ATMOS RECORD'));
    const tools = node('div', 'tv-view-tools');
    state.save = action('Save', () => state.callbacks.onSave(), !file.dirty);
    state.revert = action('Revert', () => state.callbacks.onRevert(), !file.dirty);
    state.save.dataset.save = ''; state.revert.dataset.revert = '';
    tools.append(state.save, state.revert);
    if (file.type === 'md' || file.type === 'atmo') {
      tools.append(node('span', 'tv-tool-divider'));
      const options = file.type === 'md' ? [['Edit', 'code'], ['Preview', 'preview']] : [['Readout', 'custom'], ['Source', 'code']];
      options.forEach(([label, value]) => { const button = action(label, () => state.callbacks.onMode(value)); button.classList.toggle('active', mode === value); tools.append(button); });
    }
    tools.append(node('span', 'tv-tool-hint', file.type === 'disl' ? 'SOURCE ONLY · NOT RUNNING' : mode === 'code' ? 'PLAIN TEXT' : 'READ ONLY'));
    state.diagnostic = node('div', 'tv-diagnostic', file.diagnostic || '');
    state.diagnostic.dataset.diagnostic = ''; state.diagnostic.hidden = !file.diagnostic;
    state.diagnostic.setAttribute('role', 'status');
    root.append(header, tools, state.diagnostic);
    if (mode === 'preview' || mode === 'custom') { state.page = mode === 'preview' ? markdown(file.body) : atmosphere(file.body); root.append(state.page); }
    else {
      const editor = node('div', 'tv-editor');
      const lines = node('pre', 'tv-line-numbers');
      const content = node('div', 'tv-editor-content');
      const paint = node('pre', 'tv-code-paint'); paint.setAttribute('aria-hidden', 'true');
      const input = node('textarea', 'tv-code-input');
      input.value = file.body; input.spellcheck = false; input.wrap = 'off'; input.setAttribute('aria-label', `Edit ${file.name}`);
      state.input = input;
      state.refresh = () => { lines.textContent = input.value.split('\n').map((_, i) => String(i + 1).padStart(2, ' ')).join('\n'); if (file.type === 'disl') highlight(paint, input.value); else paint.textContent = input.value + '\n'; };
      state.refresh();
      const position = node('span', '', 'Ln 1, Col 1');
      const updatePosition = () => { const before = input.value.slice(0, input.selectionStart).split('\n'); position.textContent = `Ln ${before.length}, Col ${before.at(-1).length + 1}`; };
      input.addEventListener('input', () => { state.refresh(); updatePosition(); state.callbacks.onChange(input.value); });
      input.addEventListener('keyup', updatePosition); input.addEventListener('click', updatePosition);
      input.addEventListener('scroll', () => { paint.scrollTop = input.scrollTop; paint.scrollLeft = input.scrollLeft; lines.scrollTop = input.scrollTop; });
      input.addEventListener('keydown', event => {
        if (event.key === 'Tab' && !event.shiftKey) { event.preventDefault(); input.setRangeText('  ', input.selectionStart, input.selectionEnd, 'end'); input.dispatchEvent(new Event('input')); }
      });
      content.append(paint, input); editor.append(lines, content); root.append(editor);
      const status = node('div', 'tv-editor-status'); status.append(position, node('span', '', 'UTF-8 · LF · 2 spaces')); root.append(status);
    }
  }
  window.TerminalViews = { render, drive };
})();
