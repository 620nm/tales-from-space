// The worn toggle is a stationary control, not an entry in the inventory it hides.
export async function checkInventoryLayout(call, evaluate, screenshot) {
  const run = fn => evaluate(`(${fn.toString()})()`);
  await run(() => {
    const toggle = document.querySelector('#equipment-toggle');
    const grid = document.querySelector('#equipment-slots');
    const baseline = toggle.getBoundingClientRect().toJSON();
    const hand = document.querySelector('.hand').getBoundingClientRect().toJSON();
    const slot = grid.querySelector('[data-worn=uniform]').getBoundingClientRect();
    const assert = (value, message) => { if (!value) throw new Error(message); };
    assert(toggle.getAttribute('aria-controls') === 'equipment-slots', 'Toggle must name the entire worn grid');
    for (let index = 0; index < 8; index++) {
      toggle.click();
      assert(JSON.stringify(toggle.getBoundingClientRect().toJSON()) === JSON.stringify(baseline), 'Worn toggle moved even a fraction of a pixel');
      assert(JSON.stringify(document.querySelector('.hand').getBoundingClientRect().toJSON()) === JSON.stringify(hand), 'Worn toggle moved hands');
      assert(grid.hidden === (index % 2 === 0), 'Toggle does not hide the entire grid');
      assert(toggle.getAttribute('aria-expanded') === String(!grid.hidden), 'Worn toggle state is stale');
      if (grid.hidden) assert(document.elementFromPoint(slot.left + slot.width / 2, slot.top + slot.height / 2)?.id === 'world', 'Hidden worn grid blocks world interaction');
      assert(!document.querySelector('#inventory').hidden, 'Worn toggle closes unrelated bag/belt contents');
      assert(document.querySelector('#carry-left').offsetWidth > 0, 'Worn toggle hides persistent carry slots');
    }
    toggle.focus();
    assert(document.activeElement === toggle, 'Worn toggle cannot receive keyboard focus');
    window.conceptWornBaseline = JSON.stringify(baseline);
  });
  for (const type of ['keyDown', 'keyUp']) await call('Input.dispatchKeyEvent', {type, key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, ...(type === 'keyDown' ? {text: '\r'} : {})});
  await run(() => {
    if (!document.querySelector('#equipment-slots').hidden) throw new Error('Keyboard cannot close worn inventory');
    if (JSON.stringify(document.querySelector('#equipment-toggle').getBoundingClientRect().toJSON()) !== window.conceptWornBaseline) throw new Error('Keyboard toggle moved');
    document.querySelector('#equipment-toggle').blur();
    document.querySelector('#inventory-close').click();
  });
  await screenshot('worn-collapsed');
  await run(() => {
    document.querySelector('#equipment-toggle').click();
    document.querySelector('#carry-left [data-container="backpack"]').click();
    delete window.conceptWornBaseline;
  });
  await run(() => new Promise(resolve => requestAnimationFrame(resolve)));
  await run(() => {
    const stage = document.querySelector('#stage');
    if (stage.dataset.slotSkin !== 'classic') throw new Error('TG slot frames must be the default comparison');
    for (const slot of stage.querySelectorAll('.slot,.hand')) {
      const frame = slot.querySelector('.tg-slot-frame');
      if (!frame || !conceptHudSheet.states[frame.dataset.state]) throw new Error('Inventory slot lacks verified HUD frame');
      if (getComputedStyle(frame).display === 'none') throw new Error('Classic HUD frame is hidden');
    }
    window.conceptSkinGeometry = JSON.stringify([...stage.querySelectorAll('.slot,.hand,#equipment-toggle')].map(node => node.getBoundingClientRect().toJSON()));
    const select = document.querySelector('#slot-skin'); select.value = 'modern'; select.dispatchEvent(new Event('change'));
    if (stage.dataset.slotSkin !== 'modern') throw new Error('Frame comparison selector does not switch');
    for (const frame of stage.querySelectorAll('.tg-slot-frame')) if (getComputedStyle(frame).display !== 'none') throw new Error('TG frame leaks into modern comparison');
    const current = JSON.stringify([...stage.querySelectorAll('.slot,.hand,#equipment-toggle')].map(node => node.getBoundingClientRect().toJSON()));
    if (current !== window.conceptSkinGeometry) throw new Error('Changing slot art moves controls');
  });
  await screenshot('crew-modern');
  await run(() => {
    const select = document.querySelector('#slot-skin'); select.value = 'classic'; select.dispatchEvent(new Event('change'));
    delete window.conceptSkinGeometry;
  });
}
