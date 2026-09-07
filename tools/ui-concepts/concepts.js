(() => {
  'use strict';
  const $ = selector => document.querySelector(selector);
  const $$ = selector => [...document.querySelectorAll(selector)];
  const scene = window.ConceptScene;
  const surfaces = window.ConceptSurfaces;
  const actions = window.ConceptActions;
  const stage = $('#stage');
  const canvas = $('#world');
  let role = 'crew', activeHand = 'right', openContainer = null, activeChannel = 'all';
  let camera = 0, target = 0;
  const hands = { left: ['crowbar', 'Crowbar'], right: ['wrench', 'Wrench'] };
  const cameras = ['Engineering / 04', 'Maintenance / 02', 'Central corridor / 01', 'AI core'];
  const targets = [['chest', 'Chest'], ['head', 'Head'], ['l_arm', 'Left arm'], ['r_arm', 'Right arm'], ['l_leg', 'Left leg'], ['r_leg', 'Right leg']];
  const containers = {
    backpack: { title: 'BACKPACK', source: 'backpack', items: [['toolbox', 'Toolbox', 'toolbox'], ['crowbar', 'Crowbar'], ['laptop_closed', 'Computer']] },
    belt: { title: 'TOOL BELT', source: 'belt', items: [['wrench', 'Wrench'], ['screwdriver', 'Screwdriver'], ['welder', 'Welder']] },
    toolbox: { title: 'BACKPACK / TOOLBOX', source: 'backpack', items: [['wrench', 'Wrench'], ['screwdriver', 'Screwdriver']] },
  };
  function makeSlot(name, label, container) {
    const slot = document.createElement('button'); slot.className = `slot${name ? '' : ' empty'}`;
    slot.title = label; slot.setAttribute('aria-label', label);
    if (name) slot.append(scene.sprite(name, label));
    const caption = document.createElement('span'); caption.className = 'slot-label'; caption.textContent = label.toUpperCase(); slot.append(caption);
    if (container) {
      slot.dataset.container = container; slot.setAttribute('aria-expanded', 'false');
      slot.addEventListener('click', () => setContainer(openContainer === container ? null : container));
    }
    return slot;
  }
  const worn = [['uniform_eng', 'Uniform'], ['breath_mask', 'Mask'], ['headset', 'Ears'], ['id', 'ID'], ['light_bulb', 'Lamp'], [null, 'Suit'], [null, 'Gloves'], [null, 'Shoes']];
  worn.forEach((item, index) => {
    const slot = makeSlot(...item); if (index > 3) slot.classList.add('extra');
    slot.addEventListener('click', () => {
      if (index === 4) actions.activate('lamp');
      else surfaces.inspect({ key: `worn-${index}`, title: item[1], sprite: item[0], lines: [item[0] ? 'Equipped · local sample' : 'Empty equipment slot'] });
    }); $('#equipment-slots').append(slot);
  });
  [['backpack', 'Bag', 'backpack'], ['toolbelt', 'Belt', 'belt']].forEach(item => $('#carry-left').append(makeSlot(...item)));
  [['oxygen_tank', 'Tank'], ['laptop_closed', 'Device']].forEach((item, index) => {
    const slot = makeSlot(...item); slot.addEventListener('click', () => index ? surfaces.open('device') : actions.activate('internals')); $('#carry-right').append(slot);
  });
  [['wrench', 'Wrench'], ['welder', 'Welder'], ['crowbar', 'Crowbar']].forEach((item, index) => {
    const slot = makeSlot(...item); slot.classList.toggle('selected', index === 0); slot.setAttribute('aria-pressed', String(index === 0));
    slot.addEventListener('click', () => {
      $$('#cyborg-tools .slot').forEach(button => { button.classList.toggle('selected', button === slot); button.setAttribute('aria-pressed', String(button === slot)); });
      localMessage(`${item[1]} module tool selected.`);
    }); $('#cyborg-tools').append(slot);
  });
  function positionInventory() {
    if (!openContainer) return;
    const origin = document.querySelector(`.carry-slots [data-container="${containers[openContainer].source}"]`);
    const rect = origin.getBoundingClientRect(), bounds = stage.getBoundingClientRect(), tray = $('#inventory');
    const left = Math.max(10, Math.min(stage.clientWidth - tray.offsetWidth - 10, rect.left - bounds.left - 7));
    tray.style.left = `${left}px`; tray.style.top = `${rect.top - bounds.top - tray.offsetHeight - 9}px`;
    tray.style.setProperty('--origin-x', `${rect.left - bounds.left - left + 15}px`);
  }
  function setContainer(id) {
    openContainer = id; $('#inventory').hidden = !id;
    $$('.carry-slots [data-container]').forEach(slot => {
      const open = Boolean(id && slot.dataset.container === containers[id].source);
      slot.classList.toggle('open', open); slot.setAttribute('aria-expanded', String(open));
      slot.setAttribute('aria-label', id === 'toolbox' && open ? 'Back to backpack' : `${open ? 'Close' : 'Open'} ${slot.title}`);
    });
    if (!id) return;
    const container = containers[id]; $('#inventory-title').textContent = container.title;
    $('#inventory-count').textContent = `${container.items.length} / 7`; $('#inventory-items').replaceChildren();
    for (let index = 0; index < 7; index++) {
      const item = container.items[index]; const slot = makeSlot(...(item || [null, 'Empty']));
      if (item && !item[2]) slot.addEventListener('click', () => {
        if (hands[activeHand]) { localMessage('Free the active hand before taking an item.'); return; }
        hands[activeHand] = item.slice(0, 2); container.items.splice(index, 1); setHand(activeHand); setContainer(id);
      });
      if (!item) slot.disabled = true;
      $('#inventory-items').append(slot);
    }
    positionInventory();
  }
  function addMessage([time, channel, speaker, message]) {
    const row = document.createElement('div'); row.className = `chat-message ${channel}`; row.dataset.channel = channel;
    row.hidden = activeChannel !== 'all' && activeChannel !== channel;
    const timestamp = document.createElement('time'); timestamp.textContent = time; row.append(timestamp);
    if (speaker) { const author = document.createElement('span'); author.className = 'speaker'; author.textContent = `${channel === 'radio' ? '[ENG] ' : ''}${speaker}: `; row.append(author); }
    row.append(document.createTextNode(message)); $('#chat-log').append(row);
    if ($('#chat-log').children.length > 80) $('#chat-log').firstElementChild.remove();
    $('#chat-log').scrollTop = $('#chat-log').scrollHeight;
  }
  function localMessage(text) { addMessage(['18:42', 'system', '', text]); }
  [
    ['18:39', 'radio', 'Mara', 'Anyone near engineering?'],
    ['18:40', 'local', 'Elias', 'At the east airlock.'],
    ['18:40', 'system', '', 'The maintenance airlock closes.'],
    ['18:41', 'radio', 'Mara', 'Pressure looks good from here.'],
    ['18:41', 'local', 'Dr. Ames', 'Leaving the spare tools by the locker.'],
    ['18:42', 'radio', 'Mara', 'Copy. I’ll check the junction next.'],
  ].forEach(addMessage);
  $$('.chat-channels [data-channel]').forEach(button => button.addEventListener('click', () => {
    activeChannel = button.dataset.channel;
    $$('.chat-channels [data-channel]').forEach(tab => { tab.classList.toggle('selected', tab === button); tab.setAttribute('aria-pressed', String(tab === button)); });
    $$('.chat-message').forEach(row => { row.hidden = activeChannel !== 'all' && activeChannel !== row.dataset.channel; });
    $('#chat-log').scrollTop = $('#chat-log').scrollHeight;
  }));
  function setHand(hand) {
    activeHand = hand;
    $$('.hand').forEach(button => {
      const item = hands[button.dataset.hand]; button.classList.toggle('active', button.dataset.hand === hand);
      button.setAttribute('aria-pressed', String(button.dataset.hand === hand));
      button.setAttribute('aria-label', `${button.dataset.hand} hand: ${item?.[1] || 'empty'}`);
      button.querySelector('.hand-item').replaceChildren(...(item ? [scene.sprite(item[0], item[1])] : []));
    });
  }
  function renderTarget() {
    const [key, label] = targets[target]; $('#target-doll').replaceChildren(scene.sprite('target_doll', '', 64), scene.sprite(`target_${key}`, label, 64));
    $('#target-label').textContent = label.toUpperCase(); $('#target-doll').setAttribute('aria-label', `Target: ${label}`);
  }
  function selectRole(next) {
    role = ['crew', 'cyborg', 'ai'].includes(next) ? next : 'crew'; stage.dataset.role = role;
    $$('[data-role]').filter(node => node.tagName === 'BUTTON').forEach(button => { button.classList.toggle('selected', button.dataset.role === role); button.setAttribute('aria-pressed', String(button.dataset.role === role)); });
    ['crew', 'cyborg', 'ai'].forEach(actor => { $(`#${actor}-controls`).hidden = actor !== role; });
    $('#equipment').hidden = $('#target').hidden = role !== 'crew';
    $('#actor-status').hidden = role === 'crew'; $('#actor-status').textContent = role === 'cyborg' ? '● SYSTEMS NOMINAL' : '● CORE CONNECTED';
    $('#actor-name').textContent = { crew: 'Elias Voss', cyborg: 'Engineering unit', ai: 'Station intelligence' }[role];
    $('#location-name').textContent = role === 'ai' ? cameras[camera].split(' / ')[0] : 'Engineering';
    setContainer(null); actions.setRole(role); scene.setRole(role); scene.draw(canvas);
    const url = new URL(location.href); url.searchParams.set('role', role);
    try { history.replaceState(null, '', url); } catch { /* File hosts may restrict URL updates. */ }
  }
  $$('[data-role]').filter(node => node.tagName === 'BUTTON').forEach(button => button.addEventListener('click', () => selectRole(button.dataset.role)));
  $$('.hand').forEach(button => button.addEventListener('click', () => setHand(button.dataset.hand)));
  $('#swap-hands').addEventListener('click', () => setHand(activeHand === 'right' ? 'left' : 'right'));
  $('#drop-item').addEventListener('click', () => { if (hands[activeHand]) localMessage(`${hands[activeHand][1]} removed from ${activeHand} hand in this local sample.`); hands[activeHand] = null; setHand(activeHand); });
  $('#throw-item').addEventListener('click', event => { const button = event.currentTarget; button.setAttribute('aria-pressed', String(button.getAttribute('aria-pressed') !== 'true')); });
  $('#inventory-close').addEventListener('click', () => setContainer(null));
  $('#equipment-toggle').addEventListener('click', event => { const expanded = $('#equipment').classList.toggle('expanded'); event.currentTarget.setAttribute('aria-expanded', String(expanded)); event.currentTarget.textContent = expanded ? 'Less ▾' : 'More ▴'; });
  $('#history-toggle').addEventListener('click', event => { const expanded = stage.classList.toggle('history-open'); event.currentTarget.setAttribute('aria-expanded', String(expanded)); event.currentTarget.textContent = expanded ? 'Close history ↙' : 'History ↗'; });
  $('#chat-form').addEventListener('submit', event => {
    event.preventDefault(); const input = $('#chat-input'); if (!input.value.trim()) return;
    const radio = input.value.trim().startsWith(';'); addMessage(['18:42', radio ? 'radio' : 'local', $('#actor-name').textContent, input.value.trim().replace(/^;/, '')]); input.value = '';
  });
  $('#intent-toggle').addEventListener('click', event => { const combat = event.currentTarget.classList.toggle('combat'); event.currentTarget.textContent = combat ? 'HARM' : 'HELP'; event.currentTarget.setAttribute('aria-pressed', String(combat)); });
  const cycleTarget = () => { target = (target + 1) % targets.length; renderTarget(); };
  $('#target-doll').addEventListener('click', cycleTarget);
  $('#target-doll').addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); cycleTarget(); } });
  $('#borg-lamp').addEventListener('click', () => actions.activate('lamp'));
  document.addEventListener('concept-action', event => { if (event.detail.role === 'cyborg' && event.detail.id === 'lamp') $('#borg-lamp').setAttribute('aria-pressed', String(event.detail.on)); });
  const changeCamera = offset => { camera = (camera + offset + cameras.length) % cameras.length; $('#camera-location').textContent = cameras[camera]; $('#location-name').textContent = cameras[camera].split(' / ')[0]; localMessage(`Camera selected: ${cameras[camera]}.`); };
  $('#camera-prev').addEventListener('click', () => changeCamera(-1)); $('#camera-next').addEventListener('click', () => changeCamera(1));
  $('#core-return').addEventListener('click', () => { camera = 3; changeCamera(0); });
  [['device-toggle', 'device'], ['second-device', 'device-secondary']].forEach(([buttonId, windowId]) => {
    const button = $(`#${buttonId}`); button.setAttribute('aria-controls', windowId); button.setAttribute('aria-expanded', 'false');
    button.addEventListener('click', () => surfaces.open(windowId));
  });
  $('#inspect-demo').addEventListener('click', () => surfaces.demoInspect());
  $$('.power-toggle,#monitor-toggle').forEach(button => button.addEventListener('click', () => { const on = button.getAttribute('aria-pressed') !== 'true'; button.setAttribute('aria-pressed', String(on)); button.textContent = on ? (button.id ? 'Enabled' : 'Auto') : 'Off'; }));
  document.addEventListener('keydown', event => {
    if (event.target.matches('input,textarea')) return;
    if (event.key === 'Escape') { setContainer(null); $('#action-palette').hidden = true; }
    if (event.key === 'Tab' && role === 'crew' && event.target === document.body) { event.preventDefault(); setHand(activeHand === 'right' ? 'left' : 'right'); }
  });
  const resize = () => { scene.draw(canvas); positionInventory(); };
  surfaces.init(); actions.init(localMessage); setHand('right'); renderTarget();
  selectRole(new URLSearchParams(location.search).get('role'));
  new ResizeObserver(resize).observe(stage);
  scene.ready.then(() => { resize(); surfaces.open('device'); surfaces.demoInspect(); if (role === 'crew') setContainer('backpack'); });
})();
