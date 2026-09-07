(() => {
  'use strict';
  const $ = selector => document.querySelector(selector);
  const groups = ['Body', 'Equipment', 'Role'];
  const entries = {
    crew: [
      ['resist', 'Body', 'Resist', '⌁', null, 'pulse', 'Try to break free'],
      ['rest', 'Body', 'Rest', '↧', null, 'toggle', 'Body posture'],
      ['lamp', 'Equipment', 'Helmet lamp', null, 'light_bulb', 'toggle', 'Worn lamp · local toggle'],
      ['internals', 'Equipment', 'Internals', null, 'oxygen_tank', 'toggle', 'Tank + breath mask'],
      ['radio', 'Equipment', 'Radio microphone', null, 'headset', 'toggle', 'Headset microphone'],
      ['scan', 'Role', 'Survey area', '⌖', null, 'cooldown', 'Engineering ability · sample cooldown'],
      ['recover', 'Role', 'Recover', '✚', null, 'unavailable', 'Unavailable while standing'],
    ],
    cyborg: [
      ['lamp', 'Body', 'Chassis lamp', null, 'light_bulb', 'toggle', 'Chassis light · local toggle'],
      ['lock', 'Body', 'Lock movement', '⊠', null, 'toggle', 'Chassis movement lock'],
      ['welder', 'Equipment', 'Welding tool', null, 'welder', 'toggle', 'Selected engineering tool'],
      ['scan', 'Role', 'Diagnostic scan', '⌖', null, 'cooldown', 'Module ability · sample cooldown'],
      ['magnet', 'Role', 'Magnetic grip', '⊓', null, 'toggle', 'Hold position'],
      ['service', 'Role', 'Service cycle', '↺', null, 'unavailable', 'Requires a service station'],
    ],
    ai: [
      ['track', 'Role', 'Track subject', '◎', null, 'toggle', 'Camera follows selected subject'],
      ['scan', 'Role', 'Network scan', '⌖', null, 'cooldown', 'Camera network · sample cooldown'],
      ['announce', 'Role', 'Announcement', '≋', null, 'pulse', 'Compose a local announcement sample'],
      ['door', 'Role', 'Door override', '⊞', null, 'unavailable', 'Select a visible door first'],
      ['light', 'Role', 'Camera light', '☼', null, 'toggle', 'Current camera light'],
      ['alerts', 'Role', 'Watch alerts', '△', null, 'toggle', 'Network alert notifications'],
    ],
  };
  const defaults = { crew: ['resist', 'lamp', 'internals', 'scan'], cyborg: ['lamp', 'welder', 'scan'], ai: ['track', 'scan', 'announce', 'door'] };
  const states = {};
  let role = 'crew';
  let notify = () => {};
  const model = () => states[role];
  const label = action => action[2];
  function status(action) {
    const value = model().values[action[0]];
    if (action[5] === 'unavailable') return action[6];
    if (value.until > Date.now()) return `Ready in ${Math.ceil((value.until - Date.now()) / 1000)}s`;
    if (action[5] === 'toggle') return value.on ? 'On' : 'Off';
    return 'Ready';
  }
  function activate(id) {
    const action = entries[role].find(item => item[0] === id);
    if (!action || action[5] === 'unavailable') return;
    const value = model().values[id];
    if (value.until > Date.now()) return;
    if (action[5] === 'toggle') value.on = !value.on;
    if (action[5] === 'cooldown') value.until = Date.now() + 8000;
    notify(`${label(action)} · ${action[5] === 'toggle' ? status(action).toLowerCase() : 'local sample activated'}`);
    renderStrip(); renderPalette();
    document.dispatchEvent(new CustomEvent('concept-action', { detail: { role, id, on: value.on } }));
  }
  function renderStrip() {
    const strip = $('#actions');
    const focusId = document.activeElement?.dataset.ability;
    strip.replaceChildren();
    for (const group of groups) {
      const actions = entries[role].filter(action => action[1] === group && model().pins.includes(action[0]));
      if (!actions.length) continue;
      const wrapper = document.createElement('div'); wrapper.className = 'action-group';
      const heading = document.createElement('span'); heading.className = 'action-group-label'; heading.textContent = (group === 'Equipment' ? 'Gear' : group).toUpperCase(); wrapper.append(heading);
      for (const action of actions) {
        const value = model().values[action[0]];
        const button = document.createElement('button'); button.className = 'ability'; button.dataset.ability = action[0];
        button.classList.toggle('on', value.on); button.classList.toggle('cooldown', value.until > Date.now());
        button.classList.toggle('unavailable', action[5] === 'unavailable');
        button.setAttribute('aria-label', `${label(action)}: ${status(action)}`);
        button.setAttribute('aria-disabled', String(action[5] === 'unavailable' || value.until > Date.now()));
        if (action[5] === 'toggle') button.setAttribute('aria-pressed', String(value.on));
        if (action[4]) button.append(window.ConceptScene.sprite(action[4], '', 26)); else button.append(action[3]);
        const dot = document.createElement('span'); dot.className = 'ability-dot'; button.append(dot);
        if (value.until > Date.now()) {
          const timer = document.createElement('span'); timer.className = 'ability-cooldown'; timer.textContent = Math.ceil((value.until - Date.now()) / 1000); button.append(timer);
        }
        const tooltip = document.createElement('span'); tooltip.className = 'ability-tooltip'; tooltip.append(label(action));
        const hint = document.createElement('small'); hint.textContent = `${status(action)} · ${action[6]}`; tooltip.append(hint); button.append(tooltip);
        button.addEventListener('click', () => activate(action[0])); wrapper.append(button);
      }
      strip.append(wrapper);
    }
    const more = document.createElement('button'); more.className = 'ability-more'; more.dataset.ability = 'more'; more.textContent = '+'; more.title = 'Find and pin abilities'; more.setAttribute('aria-label', 'Find and pin abilities');
    more.addEventListener('click', () => { $('#action-palette').hidden = !$('#action-palette').hidden; renderPalette(); if (!$('#action-palette').hidden) $('#action-search').focus(); }); strip.append(more);
    if (focusId) strip.querySelector(`[data-ability="${focusId}"]`)?.focus({ preventScroll: true });
  }
  function renderPalette() {
    const focusControl = document.activeElement?.dataset.actionControl;
    const query = $('#action-search').value.trim().toLowerCase();
    const options = $('#action-options'); options.replaceChildren();
    for (const group of groups) {
      const actions = entries[role].filter(action => action[1] === group && `${action[2]} ${action[6]}`.toLowerCase().includes(query));
      if (!actions.length) continue;
      const section = document.createElement('section'); section.className = 'palette-group';
      const heading = document.createElement('h3'); heading.textContent = group.toUpperCase(); section.append(heading);
      actions.forEach(action => {
        const row = document.createElement('div'); row.className = 'palette-action';
        const use = document.createElement('button'); use.className = 'palette-use'; use.dataset.actionControl = `use-${action[0]}`; use.textContent = label(action);
        const detail = document.createElement('small'); detail.textContent = status(action); use.append(detail);
        use.disabled = action[5] === 'unavailable' || model().values[action[0]].until > Date.now();
        use.addEventListener('click', () => activate(action[0]));
        const pinned = model().pins.includes(action[0]);
        const pin = document.createElement('button'); pin.className = `pin-action${pinned ? ' pinned' : ''}`; pin.dataset.actionControl = `pin-${action[0]}`; pin.textContent = pinned ? 'Unpin' : 'Pin'; pin.setAttribute('aria-label', `${pinned ? 'Unpin' : 'Pin'} ${label(action)}`);
        pin.disabled = !pinned && model().pins.length >= 6;
        pin.addEventListener('click', () => { model().pins = pinned ? model().pins.filter(id => id !== action[0]) : [...model().pins, action[0]]; renderStrip(); renderPalette(); });
        row.append(use, pin); section.append(row);
      }); options.append(section);
    }
    if (!options.children.length) { const empty = document.createElement('p'); empty.className = 'palette-empty'; empty.textContent = 'No matching abilities.'; options.append(empty); }
    $('#pin-count').textContent = `${model().pins.length} / 6 pinned · order stays fixed while acting`;
    if (focusControl) options.querySelector(`[data-action-control="${focusControl}"]`)?.focus({ preventScroll: true });
  }
  function setRole(next) {
    role = next;
    if (!states[role]) states[role] = { pins: [...defaults[role]], values: Object.fromEntries(entries[role].map(action => [action[0], { on: false, until: action[0] === 'scan' ? Date.now() + 12000 : 0 }])) };
    $('#action-palette').hidden = true; $('#action-search').value = ''; renderStrip(); renderPalette();
  }
  function init(callback) {
    notify = callback;
    $('#palette-close').addEventListener('click', () => { $('#action-palette').hidden = true; });
    $('#action-search').addEventListener('input', renderPalette);
    setInterval(() => { if (model() && entries[role].some(action => model().values[action[0]].until > Date.now() - 1100)) { renderStrip(); if (!$('#action-palette').hidden) renderPalette(); } }, 1000);
  }
  window.ConceptActions = { init, setRole, activate };
})();
