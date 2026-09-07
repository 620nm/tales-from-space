(function () {
  'use strict';
  const model = window.TerminalModel;
  const byId = id => document.getElementById(id);
  let cancelDialog = null;
  let dialogFocus = null;
  function closeDialog() {
    byId('dialog-backdrop').hidden = true; cancelDialog = null;
    byId('terminal').inert = false;
    (byId('gallery') || document.querySelector('.gallery'))?.removeAttribute('inert');
    dialogFocus?.focus(); dialogFocus = null;
  }
  function dialog(title, body, actions) {
    byId('dialog-title').textContent = title;
    byId('dialog-body').replaceChildren(body);
    byId('dialog-actions').replaceChildren();
    actions.forEach(([label, action]) => {
      const button = document.createElement('button'); button.textContent = label;
      button.addEventListener('click', action); byId('dialog-actions').append(button);
    });
    dialogFocus = document.activeElement;
    byId('terminal').inert = true;
    (byId('gallery') || document.querySelector('.gallery'))?.setAttribute('inert', '');
    cancelDialog = closeDialog; byId('dialog-backdrop').hidden = false;
    requestAnimationFrame(() => (body.querySelector('input') || byId('dialog-actions').lastElementChild)?.focus());
  }
  function guard(action) {
    const file = model.get();
    if (!file?.dirty) return action();
    const p = document.createElement('p'); p.textContent = 'Save changes to ' + file.name + ' before continuing?';
    dialog('Unsaved changes', p, [
      ['Save', () => { if (model.save()) { closeDialog(); action(); } else { closeDialog(); render(); } }],
      ['Discard', () => { model.revert(); closeDialog(); action(); }], ['Cancel', closeDialog]
    ]);
  }
  function select(id) { if (id !== model.state.selected) guard(() => { model.state.selected = id; render(); }); }
  function filenameDialog(side, operation, id) {
    const source = id ? model.get(id) : null;
    if ((operation === 'Rename' || operation === 'Copy') && !source) return;
    if (operation === 'Rename') side = source.side;
    const body = document.createElement('div');
    const label = document.createElement('label'); label.textContent = 'Filename';
    const input = document.createElement('input'); input.id = 'filename-input'; input.maxLength = 53;
    input.value = operation === 'Rename' ? source.name : operation === 'Copy' ? source.name.replace(/\./, '_copy.') : 'untitled.md';
    label.append(input); body.append(label);
    const error = document.createElement('p'); error.className = 'dialog-error'; body.append(error);
    const submit = () => {
      const name = input.value.trim(); let result = model.validName(side, name, operation === 'Rename' ? id : null);
      if (!result && operation === 'Rename' && name.split('.').pop() !== source.type) result = 'Keep the current file extension when renaming.';
      if (!result) {
        if (operation === 'Rename') { source.name = name; model.state.notice = 'Renamed to ' + name; }
        else result = model.create(side, name, source);
      }
      if (result) { error.textContent = result; return; }
      closeDialog(); render();
    };
    input.addEventListener('keydown', event => { if (event.key === 'Enter') submit(); });
    dialog(operation + ' file · ' + side.toUpperCase() + ':', body, [[operation, submit], ['Cancel', closeDialog]]);
  }
  function remove(id) {
    const file = model.get(id); if (!file) return;
    const proceed = () => {
      const p = document.createElement('p'); p.textContent = 'Delete ' + file.name + '? This only changes the demonstration.';
      dialog('Delete file', p, [['Delete', () => {
        model.state.files = model.state.files.filter(f => f.id !== id);
        if (model.state.selected === id) model.state.selected = model.list('a')[0]?.id || model.list('b')[0]?.id || null;
        model.state.notice = 'Deleted ' + file.name; closeDialog(); render();
      }], ['Cancel', closeDialog]]);
    };
    if (model.state.selected === id) guard(proceed); else proceed();
  }
  function eject() {
    const action = () => { model.eject(); render(); };
    if (model.get()?.side === 'b') guard(action); else action();
  }
  function render() {
    const state = model.state; const file = model.get();
    byId('terminal').hidden = state.closed;
    if (byId('terminal-restore')) byId('terminal-restore').hidden = !state.closed;
    byId('frames').classList.toggle('has-disk', state.disk);
    byId('drive-b').hidden = !state.disk; byId('split-b').hidden = !state.disk;
    window.TerminalInteractions?.fitFrames();
    if (byId('disk-status')) byId('disk-status').textContent = state.disk ? 'B: ENGINEERING' : 'B: NO MEDIA';
    if (byId('terminal-status')) byId('terminal-status').textContent = state.notice;
    ['a', 'b'].forEach(side => window.TerminalViews.drive(byId('drive-' + side), side, model.list(side), state.selected, {
      diskName: state.diskName, capacity: model.limits[side].bytes, usage: model.usage(side), fileCapacity: model.limits[side].files, copyAllowed: state.disk,
      onSelect: select,
      onNew: () => guard(() => filenameDialog(side, 'New')),
      onCopy: id => { if (state.disk) guard(() => filenameDialog(side === 'a' ? 'b' : 'a', 'Copy', id)); },
      onRename: id => filenameDialog(side, 'Rename', id), onDelete: remove, onEject: eject
    }));
    window.TerminalViews.render(byId('file-view'), file, {
      onChange: body => { model.change(body); refreshDirty(); },
      onSave: () => { model.save(); render(); }, onRevert: () => { model.revert(); render(); },
      onMode: mode => { if (file) file.mode = mode; render(); }
    });
    byId('demo-disk').textContent = state.disk ? 'Eject floppy' : 'Insert floppy';
    refreshDirty();
  }
  function refreshDirty() {
    const file = model.get();
    byId('terminal').classList.toggle('is-dirty', !!file?.dirty);
    document.querySelectorAll('[data-dirty-indicator]').forEach(el => { el.textContent = file?.dirty ? 'UNSAVED' : 'SAVED'; });
    document.querySelectorAll('[data-save], [data-revert]').forEach(el => { el.disabled = !file?.dirty; });
    document.querySelectorAll('[data-file-id]').forEach(el => el.classList.toggle('dirty', !!model.get(el.dataset.fileId)?.dirty));
  }
  function start() {
    byId('demo-source').onclick = () => select('host:filter');
    byId('demo-document').onclick = () => select('host:readme');
    byId('demo-record').onclick = () => select('host:atmos');
    byId('demo-disk').onclick = () => model.state.disk ? eject() : (model.insert(), render());
    byId('demo-reset').onclick = () => guard(() => { model.reset(); window.TerminalInteractions?.reset(); render(); });
    byId('demo-focus').onclick = () => document.body.classList.toggle('focus-mode');
    byId('terminal-restore')?.addEventListener('click', () => { model.state.closed = false; render(); byId('terminal').focus(); });
    byId('terminal-close')?.addEventListener('click', () => guard(() => { model.state.closed = true; render(); }));
    document.addEventListener('keydown', event => {
      if (event.key === 'Tab' && cancelDialog) {
        const controls = [...byId('dialog-backdrop').querySelectorAll('button:not(:disabled),input:not(:disabled),textarea:not(:disabled),select:not(:disabled),[tabindex="0"]')];
        if (controls.length) {
          const index = controls.indexOf(document.activeElement);
          const next = event.shiftKey ? (index <= 0 ? controls.length - 1 : index - 1) : (index + 1) % controls.length;
          event.preventDefault(); controls[next].focus();
        }
      }
      if (event.key === 'Escape' && cancelDialog) { event.preventDefault(); cancelDialog(); }
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's' && !model.state.closed) {
        event.preventDefault(); if (!cancelDialog) { model.save(); render(); }
      }
    });
    window.TerminalConcept = { reset(options) { closeDialog(); model.reset(options); render(); }, select,
      get state() { return model.state; }, render, eject, close: () => guard(() => { model.state.closed = true; render(); }) };
    render(); window.TerminalInteractions?.init();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
