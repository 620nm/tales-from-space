// Alternative inventory art, drawn from the same TG sheet as the targeting doll.
(() => {
  const sheet = window.conceptHudSheet, stage = document.querySelector('#stage');
  const select = document.querySelector('#slot-skin');
  const loaded = new Image(); loaded.src = sheet.image;
  function decorate(root) {
    for (const slot of root.querySelectorAll('.slot,.hand')) {
      if (slot.querySelector('.tg-slot-frame')) continue;
      const state = slot.classList.contains('empty') && sheet.states[slot.dataset.worn] ? slot.dataset.worn
        : slot.closest('.carry-slots') || slot.dataset.worn === 'id' ? 'template_small' : 'template';
      const cell = sheet.states[state], frame = document.createElement('span');
      frame.className = 'tg-slot-frame'; frame.dataset.state = state; frame.setAttribute('aria-hidden', 'true');
      Object.assign(frame.style, {backgroundImage: `url("${sheet.image}")`,
        backgroundSize: `${sheet.width / sheet.tile * 100}% ${sheet.height / sheet.tile * 100}%`,
        backgroundPosition: `${cell.x / (sheet.width - sheet.tile) * 100}% ${cell.y / (sheet.height - sheet.tile) * 100}%`});
      slot.prepend(frame);
    }
  }
  function apply() { stage.dataset.slotSkin = select.value; }
  decorate(stage); apply(); select.addEventListener('change', apply);
  new MutationObserver(() => decorate(document.querySelector('#inventory-items')))
    .observe(document.querySelector('#inventory-items'), {childList: true});
  window.ConceptSlotSkin = {ready: loaded.decode()};
})();
