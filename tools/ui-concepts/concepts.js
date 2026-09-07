(() => {
  'use strict';
  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => [...document.querySelectorAll(selector)];
  const scene = window.ConceptScene;
  const stage = $('#stage');
  const canvas = $('#world');
  const layouts = {
    classic: ['01 / CLASSIC SIDE RAIL', 'A fixed playfield, full chat history, and equipment where your hands expect it.', 'BEST FOR / sustained play, conversation, familiar muscle memory'],
    console: ['02 / BOTTOM CONSOLE', 'One continuous control deck. More horizontal world, less vertical chat history.', 'BEST FOR / wide displays · TRADEOFF / a shallower world and chat history'],
    overlay: ['03 / COMPACT OVERLAY', 'The station takes the screen. Expand a bounded chat rail without moving the camera.', 'BEST FOR / world visibility · TRADEOFF / controls overlap the map'],
  };
  let layout = 'classic';
  let activeHand = 'right';
  let openContainer = 'backpack';
  let historyOpen = false;
  let activeChannel = 'all';
  const containers = {
    backpack: { title: 'BACKPACK', origin: 'Equipped · back slot', items: [['toolbox','Toolbox'], ['crowbar','Crowbar'], ['laptop_closed','Computer']], capacity: 7 },
    belt: { title: 'TOOL BELT', origin: 'Equipped · belt slot', items: [['wrench','Wrench'], ['crowbar','Crowbar']], capacity: 5 },
    toolbox: { title: 'TOOLBOX', origin: 'Inside backpack · toolbox', items: [['wrench','Wrench'], ['crowbar','Crowbar']], capacity: 5 },
  };
  function sprite(name, label, size = 32) {
    const element = scene.sprite(name, label, size);
    element.classList.add('sprite');
    return element;
  }
  function makeSlot(name, label, container) {
    const element = document.createElement(container ? 'button' : 'div');
    element.className = `slot${name ? '' : ' empty'}`;
    element.title = container ? `Open ${label}` : label;
    element.setAttribute('aria-label', container ? `Open ${label}` : label);
    if (name) element.append(sprite(name, label));
    const caption = document.createElement('span');
    caption.className = 'slot-label';
    caption.textContent = label.toUpperCase();
    element.append(caption);
    if (container) {
      element.dataset.container = container;
      element.setAttribute('aria-expanded', 'false');
      element.addEventListener('click', () => setContainer(openContainer === container ? null : container));
    }
    return element;
  }
  const equipment = [
    ['uniform_eng', 'Uniform'], [null, 'Mask'], ['backpack', 'Back', 'backpack'],
    [null, 'Pockets'], ['toolbelt', 'Belt', 'belt'], [null, 'ID card'],
  ];
  equipment.forEach((item) => $('#equipment-slots').append(makeSlot(...item)));
  ['human_s', 'worn_uniform_eng_s', 'worn_backpack_s'].forEach((name) => $('#paperdoll').append(sprite(name, '', 64)));
  ['target_doll','target_chest'].forEach((name) => $('#target-doll').append(sprite(name, '', 64)));
  $$('[data-sprite]').forEach((element) => element.append(sprite(element.dataset.sprite, '', 32)));
  function positionInventory() {
    if (!openContainer) return;
    const originId = openContainer === 'toolbox' ? 'backpack' : openContainer;
    const origin = $(`#equipment-slots [data-container="${originId}"]`);
    const originRect = origin.getBoundingClientRect();
    const stageRect = stage.getBoundingClientRect();
    const tray = $('#inventory');
    const left = Math.max(8, Math.min(originRect.left - stageRect.left - 10, stageRect.width - tray.offsetWidth - 8));
    tray.style.left = `${left}px`;
    tray.style.top = `${originRect.top - stageRect.top - tray.offsetHeight - 10}px`;
    tray.style.setProperty('--origin-x', `${originRect.left - stageRect.left - left + originRect.width / 2 - 6}px`);
  }
  function setContainer(id) {
    openContainer = id;
    $('#inventory').hidden = !id;
    $$('#equipment-slots [data-container]').forEach((element) => {
      const selected = element.dataset.container === id || (id === 'toolbox' && element.dataset.container === 'backpack');
      element.classList.toggle('open', selected);
      element.setAttribute('aria-expanded', String(selected));
      element.title = id === 'toolbox' && selected ? 'Back to backpack' : `${selected ? 'Close' : 'Open'} ${element.dataset.container}`;
      element.setAttribute('aria-label', element.title);
    });
    if (!id) return;
    const container = containers[id];
    $('#inventory-title').textContent = container.title;
    $('#inventory-count').textContent = `${container.items.length} / ${container.capacity}`;
    $('#inventory-origin').textContent = container.origin;
    $('#inventory-items').replaceChildren();
    container.items.forEach(([name, label]) => $('#inventory-items').append(makeSlot(name, label, name === 'toolbox' ? 'toolbox' : null)));
    for (let i = container.items.length; i < container.capacity; i++) $('#inventory-items').append(makeSlot(null, 'Empty'));
    positionInventory();
  }
  const initialMessages = [
    ['18:11', 'system', '', '', 'You arrive at Engineering.'],
    ['18:14', 'radio', 'COMMON', 'Mira Chen', 'Anyone seen the quartermaster? Cargo is a little quiet.'],
    ['18:16', 'engineering', 'ENG', 'R. Calder', 'Engine is stable. Checking the starboard solar array next.'],
    ['18:19', 'local', 'LOCAL', 'Elias Voss', 'I’ll take a look at the maintenance airlock.'],
    ['18:22', 'action', '', '', 'You put the crowbar in your left hand.'],
    ['18:25', 'radio', 'COMMON', 'Jules Ward', 'Coffee is ready in the break room. Bring your own mug.'],
    ['18:29', 'engineering', 'ENG', 'Nadia Bell', 'Pressure looks good on this side. No alarms.'],
    ['18:31', 'local', 'LOCAL', 'R. Calder', 'There should be spare tools in your backpack.'],
    ['18:34', 'system', '', '', 'The maintenance airlock closes behind you.'],
    ['18:36', 'engineering', 'ENG', 'Elias Voss', 'Copy. Toolbox is with me.'],
    ['18:39', 'radio', 'COMMON', 'Mira Chen', 'Found them. Cargo is accepting requests again.'],
    ['18:42', 'local', 'LOCAL', 'Nadia Bell', 'Need a hand with that panel?'],
  ];
  function addMessage([time, type, channel, speaker, message]) {
    const row = document.createElement('div');
    row.className = `chat-message ${type}`;
    row.dataset.channel = type === 'engineering' ? 'radio' : type === 'action' ? 'system' : type;
    row.hidden = activeChannel !== 'all' && activeChannel !== row.dataset.channel;
    const stamp = document.createElement('time');
    stamp.textContent = time;
    row.append(stamp);
    if (channel) {
      const label = document.createElement('span');
      label.className = 'channel';
      label.textContent = `[${channel}]`;
      row.append(label);
    }
    if (speaker) {
      const name = document.createElement('span');
      name.className = 'speaker';
      name.textContent = `${speaker}: `;
      row.append(name);
    }
    const text = document.createElement('span');
    text.className = 'message-text';
    text.textContent = message;
    row.append(text);
    $('#chat-log').append(row);
    $('#chat-log').scrollTop = $('#chat-log').scrollHeight;
  }
  initialMessages.forEach(addMessage);
  $$('[data-channel]').filter((element) => element.tagName === 'BUTTON').forEach((button) => button.addEventListener('click', () => {
    activeChannel = button.dataset.channel;
    $$('.chat-channels button').forEach((tab) => {
      tab.classList.toggle('selected', tab === button);
      tab.setAttribute('aria-pressed', String(tab === button));
    });
    $$('.chat-message').forEach((row) => { row.hidden = activeChannel !== 'all' && row.dataset.channel !== activeChannel; });
    $('#chat-log').scrollTop = $('#chat-log').scrollHeight;
  }));
  function setHand(hand) {
    activeHand = hand;
    $$('.hand').forEach((element) => {
      element.classList.toggle('active', element.dataset.hand === hand);
      element.setAttribute('aria-pressed', String(element.dataset.hand === hand));
    });
    $('#hand-readout').textContent = `${hand.toUpperCase()} ACTIVE`;
  }
  function setDevice(show) {
    $('#device').hidden = !show;
    $('#device-toggle').setAttribute('aria-pressed', String(show));
  }
  function resize() {
    const world = $('.world');
    if (layout === 'classic') {
      const width = Math.min(world.clientWidth, world.clientHeight * 4 / 3);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${width * 3 / 4}px`;
    } else {
      canvas.style.width = '100%';
      canvas.style.height = '100%';
    }
    scene.draw(canvas);
    positionInventory();
  }
  function selectLayout(name) {
    layout = Object.hasOwn(layouts, name) ? name : 'classic';
    stage.className = layout;
    historyOpen = false;
    $('#history-toggle').textContent = 'Expand history ↗';
    $('#history-toggle').setAttribute('aria-expanded', 'false');
    $('#study-number').textContent = layouts[layout][0];
    $('#study-description').textContent = layouts[layout][1];
    $('#layout-benefit').textContent = layouts[layout][2];
    $$('[data-layout]').forEach((button) => {
      button.classList.toggle('selected', button.dataset.layout === layout);
      button.setAttribute('aria-pressed', String(button.dataset.layout === layout));
    });
    const url = new URL(location.href);
    url.searchParams.set('layout', layout);
    try { history.replaceState(null, '', url); } catch { /* Local file hosts may disallow URL updates. */ }
    resize();
    requestAnimationFrame(() => { $('#chat-log').scrollTop = $('#chat-log').scrollHeight; });
  }
  $$('[data-layout]').forEach((button) => button.addEventListener('click', () => selectLayout(button.dataset.layout)));
  $$('.hand').forEach((button) => button.addEventListener('click', () => setHand(button.dataset.hand)));
  $('#swap-hands').addEventListener('click', () => setHand(activeHand === 'right' ? 'left' : 'right'));
  $('#inventory-close').addEventListener('click', () => setContainer(null));
  $('#device-toggle').addEventListener('click', () => setDevice($('#device').hidden));
  $('#device-close').addEventListener('click', () => setDevice(false));
  $('#history-toggle').addEventListener('click', () => {
    historyOpen = !historyOpen;
    stage.classList.toggle('history-open', historyOpen);
    $('#history-toggle').textContent = historyOpen ? 'Collapse history ↙' : 'Expand history ↗';
    $('#history-toggle').setAttribute('aria-expanded', String(historyOpen));
    $('#chat-log').scrollTop = $('#chat-log').scrollHeight;
  });
  $('#chat-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const input = $('#chat-input');
    if (!input.value.trim()) return;
    addMessage(['18:42', 'local', 'LOCAL', 'Elias Voss', input.value.trim()]);
    input.value = '';
  });
  $$('.action-button').forEach((button) => button.addEventListener('click', () => {
    $('#action-status').textContent = `${button.dataset.action} selected · ${activeHand} hand`;
  }));
  $('#intent-toggle').addEventListener('click', () => {
    const combat = $('#intent-toggle').classList.toggle('combat');
    $('#intent-toggle').innerHTML = `${combat ? 'HARM' : 'HELP'} <span>H</span>`;
    $('#intent-toggle').setAttribute('aria-pressed', String(combat));
  });
  const infoViews = {
    status: '<div class="crew-name">Elias Voss <span>● ALIVE</span></div><div class="crew-role">STATION ENGINEER</div><div class="info-line"><span>Location</span><strong>Engineering</strong></div><div class="info-line"><span>Condition</span><strong>Stable / conscious</strong></div><div class="health-bar"></div><div class="info-line"><span>Suit sensors</span><strong>Enabled</strong></div>',
    objectives: '<p class="info-copy"><strong>ENGINEERING</strong><br>Maintain station power.<br>Keep the atmosphere breathable.<br>Respond to maintenance requests.</p>',
    inspect: '<p class="info-copy"><strong>MAINTENANCE AIRLOCK</strong><br>A heavy steel door.<br>Access: Engineering<br>State: Closed / powered</p>',
  };
  $$('[data-info]').forEach((button) => button.addEventListener('click', () => {
    $$('[data-info]').forEach((tab) => { tab.classList.toggle('selected', tab === button); tab.setAttribute('aria-selected', String(tab === button)); });
    $('#info-content').innerHTML = infoViews[button.dataset.info];
  }));
  $('#info-content').innerHTML = infoViews.status;
  setHand('right');
  setContainer('backpack');
  selectLayout(new URLSearchParams(location.search).get('layout'));
  new ResizeObserver(resize).observe($('.world'));
  window.addEventListener('resize', positionInventory);
  scene.ready.then(resize);
})();
