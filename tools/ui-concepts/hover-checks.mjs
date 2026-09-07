// Pixel comparisons keep selection feedback object-wide without revealing occluded art.
export async function checkCompositeHover(call, evaluate, screenshot, points) {
  const run = fn => evaluate(`(${fn.toString()})()`);
  const move = point => call("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.clientX, y: point.clientY });
  const player = points.filter(point => point.owner === "actor:player");
  if (player.length < 2) throw new Error("Composite fixture needs independently visible sprite layers");
  await run(() => {
    ConceptHover.hide();
    const canvas = document.querySelector("#world");
    const parts = ConceptScene.candidates(canvas).filter(part => part.owner === "actor:player");
    const x = Math.min(...parts.map(part => part.x)), y = Math.min(...parts.map(part => part.y));
    const width = Math.max(...parts.map(part => part.x + part.width)) - x;
    const height = Math.max(...parts.map(part => part.y + part.height)) - y;
    const pixels = () => canvas.getContext("2d").getImageData(x, y, width, height).data;
    window.conceptHoverCheck = { pixels, baseline: pixels(), first: null, x, y, width, height };
  });
  try {
    for (const point of player) {
      await move(point);
      await run(() => {
        const state = window.conceptHoverCheck, pixels = state.pixels();
        const hint = document.querySelector("#hover-hint");
        if (hint.hidden || hint.dataset.target !== "actor:player") throw new Error("Body part does not resolve to whole player");
        if (!pixels.some((value, index) => value !== state.baseline[index])) throw new Error("Composite hover has no visible highlight");
        if (state.first && !pixels.every((value, index) => value === state.first[index])) throw new Error("Highlight changes when moving between body sprite layers");
        state.first = pixels;
      });
    }
    await run(() => {
      const state = window.conceptHoverCheck, canvas = document.querySelector("#world"), rect = canvas.getBoundingClientRect();
      const changedLayers = new Set();
      for (let y = 0; y < state.height; y++) for (let x = 0; x < state.width; x++) {
        const index = (y * state.width + x) * 4;
        if ([0, 1, 2].every(channel => state.first[index + channel] === state.baseline[index + channel])) continue;
        const hit = ConceptScene.pick(canvas, rect.left + (state.x + x + .5) * rect.width / canvas.width,
          rect.top + (state.y + y + .5) * rect.height / canvas.height);
        if (hit?.owner !== "actor:player") throw new Error("Composite highlight spills outside the visible player");
        changedLayers.add(hit.id);
      }
      if (changedLayers.size < 2) throw new Error("Only one body layer receives highlight");
    });
    await screenshot("hover-player");
  } finally {
    await run(() => { delete window.conceptHoverCheck; ConceptHover.hide(); });
  }
  const pipe = points.find(point => point.id === "overlap:pipe1");
  const cable = points.find(point => point.id === "overlap:cable");
  if (!pipe || !cable) throw new Error("Missing occlusion fixture");
  const readCable = () => evaluate(`(${((point) => {
    const canvas = document.querySelector("#world"), rect = canvas.getBoundingClientRect();
    const x = Math.floor((point.clientX - rect.left) * canvas.width / rect.width);
    const y = Math.floor((point.clientY - rect.top) * canvas.height / rect.height);
    return [...canvas.getContext("2d").getImageData(x, y, 1, 1).data];
  }).toString()})(${JSON.stringify(cable)})`);
  const before = await readCable();
  await move(pipe);
  const after = await readCable();
  if (before.some((value, index) => value !== after[index])) throw new Error("Pipe highlight paints over the cable above it");
}

export function checkGestureBadges() {
  const hint = document.querySelector("#hover-hint"), style = getComputedStyle(hint);
  const alpha = Number(style.backgroundColor.match(/[\d.]+/g)?.[3] ?? 1);
  if (!(alpha > 0 && alpha < 1) || parseFloat(style.borderTopWidth) < 1) throw new Error("Hover hint needs a translucent framed background");
  const gestures = [...hint.querySelectorAll(".hover-keys")];
  const labels = gestures.map(node => node.getAttribute("aria-label"));
  for (const label of ["left mouse button", "right mouse button", "Shift + left mouse button", "Alt + left mouse button"]) {
    if (!labels.includes(label)) throw new Error(`Missing accessible gesture: ${label}`);
  }
  for (const gesture of gestures) {
    if (gesture.getAttribute("role") !== "img") throw new Error("Gesture icon lacks accessible image role");
    const mouse = gesture.querySelector(".hover-mouse");
    if (!mouse || mouse.getAttribute("aria-hidden") !== "true") throw new Error("Gesture lacks decorative mouse glyph");
    const left = getComputedStyle(mouse, "::before").backgroundColor;
    const right = getComputedStyle(mouse, "::after").backgroundColor;
    if (left === right) throw new Error("Left/right mouse buttons are visually indistinguishable");
  }
  const caps = [...hint.querySelectorAll("kbd")].map(node => node.textContent);
  if (!caps.includes("Shift") || !caps.includes("Alt")) throw new Error("Missing compact modifier keycaps");
  if (parseFloat(getComputedStyle(hint.querySelector(".hover-gesture")).gridTemplateColumns) > 65) throw new Error("Gesture icons no longer condense the label column");
}
