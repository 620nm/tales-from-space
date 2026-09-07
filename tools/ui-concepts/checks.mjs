// Browser checks for the local study; no game server or production UI claims.
import { checkSurfaces } from "./surface-checks.mjs";

export async function checkConcept(call, role, screenshot) {
  const ALT = 1, SHIFT = 8;
  const evaluate = async expression => {
    const result = await call("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
    return result.result.value;
  };
  const run = fn => evaluate(`(${fn.toString()})()`);
  const move = point => call("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.clientX, y: point.clientY });
  const checkHover = point => evaluate(`(${((point) => {
    const hint = document.querySelector("#hover-hint"), canvas = document.querySelector("#world");
    const assert = (value, message) => { if (!value) throw new Error(message); };
    assert(!hint.hidden && hint.dataset.primitive === point.id, "Hint differs from pixel-picked target");
    assert(document.elementFromPoint(point.clientX, point.clientY) === canvas, "Hint intercepts world input");
    assert(getComputedStyle(hint).pointerEvents === "none", "Hint must be click-through");
    const bounds = hint.getBoundingClientRect();
    assert(bounds.left > point.clientX || bounds.right < point.clientX, "Hint overlaps cursor instead of hanging beside it");
    const winner = ConceptScene.pick(canvas, point.clientX, point.clientY);
    if (ConceptScene.candidates(canvas).filter(part => part.owner === winner.owner).length === 1) {
      const source = winner.raster.image.getContext("2d").getImageData(0, 0, 32, 32).data;
      const preview = hint.querySelector("canvas").getContext("2d").getImageData(0, 0, 32, 32).data;
      assert(source.every((value, index) => value === preview[index]), "Miniature differs from current rendered sprite/tint");
    }
  }).toString()})(${JSON.stringify(point)})`);
  const click = async (point, button = "left", modifiers = 0) => {
    await move(point);
    for (const type of ["mousePressed", "mouseReleased"]) {
      await call("Input.dispatchMouseEvent", { type, x: point.clientX, y: point.clientY, button, clickCount: 1, modifiers });
    }
  };
  await run(() => {
    const rect = id => document.querySelector(id).getBoundingClientRect();
    const overlaps = (a, b) => a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top;
    const assert = (value, message) => { if (!value) throw new Error(message); };
    const stage = rect("#stage"), chat = rect(".chat"), actions = rect("#actions");
    const role = document.querySelector("#stage").dataset.role;
    const center = rect(`#${role}-controls`);
    assert(chat.width >= stage.width * .28 && chat.height >= stage.height * .24, "Chat must be materially enlarged");
    assert(chat.bottom > stage.bottom - 40, "Chat belongs at bottom-left");
    assert(actions.bottom <= center.top && actions.top > stage.top + stage.height / 2, "Abilities belong above lower-middle controls");
    assert(!overlaps(chat, center) && !overlaps(chat, actions), "Chat overlaps central controls");
    if (role === "crew") {
      const worn = rect("#equipment"), target = rect("#target");
      assert(worn.right <= center.left, "Worn must sit left of hands");
      assert(target.left >= center.right, "Target must sit right of hands");
      assert(!overlaps(chat, worn), "Enlarged chat covers worn slots");
      assert(!overlaps(rect("#inventory"), actions), "Open bag covers abilities");
      const before = rect(".hand").toJSON();
      document.querySelector("#inventory-close").click();
      document.querySelector('#carry-left [data-container="belt"]').click();
      const after = rect(".hand");
      assert(before.x === after.x && before.y === after.y, "Opening storage moves hands");
      assert(document.querySelector("#inventory-title").textContent.includes("BELT"), "Belt opens its own tray");
    }
  });
  if (role !== "crew") {
    await checkSurfaces(call, evaluate);
    console.log(`Checked ${role}: layout and floating windows`);
    return;
  }

  const points = await run(() => {
    document.querySelector("#inventory-close").click();
    const canvas = document.querySelector("#world");
    const candidates = ConceptScene.candidates(canvas);
    const points = ConceptScene.sampleClientPoints(canvas);
    const assert = (value, message) => { if (!value) throw new Error(message); };
    for (const point of points) {
      const picked = ConceptScene.pick(canvas, point.clientX, point.clientY);
      assert(picked.id === point.id, `Point does not pick ${point.id}`);
      const inspected = ConceptScene.inspect(canvas, point.clientX, point.clientY);
      assert(inspected && inspected.title === point.title, `Inspect differs from visible winner ${point.id}`);
    }
    assert(candidates.some(item => item.raster.alpha.some(alpha => alpha === 0)), "Fixture must exercise transparent pixels");
    return points;
  });
  const laptop = points.find(point => /^laptop$/i.test(point.title));
  if (!laptop) throw new Error("Missing laptop hit sample");
  await move(laptop);
  await checkHover(laptop);
  await screenshot("hover-laptop");
  await run(() => {
    ConceptSurfaces.close("device");
    if (!document.querySelector("#device").hidden) throw new Error("Device must be closed before Alt-click check");
  });
  await click(laptop, "left", ALT);
  await run(() => { if (document.querySelector("#device").hidden) throw new Error("Alt-click did not open device"); });
  await click(laptop, "right");
  const closedLaptop = await run(() => {
    const canvas = document.querySelector("#world");
    const point = ConceptScene.sampleClientPoints(canvas).find(point => point.title === "Laptop");
    if (!point || ConceptScene.pick(canvas, point.clientX, point.clientY).sprite !== "laptop_closed") throw new Error("Right-click did not close laptop lid");
    return point;
  });
  await move(closedLaptop);
  await checkHover(closedLaptop);
  await screenshot("hover-laptop-closed");
  const layers = ["overlap:pipe1", "overlap:pipe3", "overlap:cable"].map(id => {
    const point = points.find(point => point.id === id);
    if (!point) throw new Error(`Missing exact-pixel sample: ${id}`);
    return point;
  });
  for (const point of layers) {
    await move(point);
    await checkHover(point);
    await screenshot(`hover-${point.id.replace(/[^a-z0-9_-]/gi, "-")}`);
    await click(point, "left", SHIFT);
    const titles = await run(() => [...document.querySelectorAll("#toasts .inspect-toast")].map(node => node.getAttribute("aria-label")));
    if (!titles.includes(point.title)) throw new Error(`Shift-click inspected a different target than ${point.title}`);
  }
  await click(closedLaptop);
  await run(() => {
    if (!ConceptScene.candidates(document.querySelector("#world")).some(part => part.title === "Laptop")) throw new Error("Full hand silently removed laptop");
    document.querySelector("#drop-item").click();
    if (!ConceptHands.canTake()) throw new Error("Drop did not free the active hand");
  });
  await click(closedLaptop);
  await run(() => {
    if (ConceptScene.candidates(document.querySelector("#world")).some(part => part.title === "Laptop")) throw new Error("Pickup did not remove world laptop");
    if (!document.querySelector(".hand.active").getAttribute("aria-label").includes("Laptop")) throw new Error("Pickup did not enter active hand");
  });
  const edge = await run(() => ({ clientX: innerWidth - 4, clientY: innerHeight * .65 }));
  await move(edge);
  await run(() => {
    const hint = document.querySelector("#hover-hint"), rect = hint.getBoundingClientRect();
    if (hint.hidden || rect.right > innerWidth - 4 || rect.left < 0) throw new Error("Cursor hint does not flip inside right edge");
  });
  const composer = await run(() => {
    const rect = document.querySelector("#chat-input").getBoundingClientRect();
    return { clientX: rect.left + 20, clientY: rect.top + rect.height / 2 };
  });
  await move(composer);
  await run(() => { if (!document.querySelector("#hover-hint").hidden) throw new Error("World hint remains over HUD controls"); });
  const dimensions = await run(() => ({ width: innerWidth, height: innerHeight }));
  await call("Emulation.setDeviceMetricsOverride", { ...dimensions, deviceScaleFactor: 2, mobile: false });
  await move(layers[0]);
  await checkHover(layers[0]);
  await call("Emulation.setDeviceMetricsOverride", { ...dimensions, deviceScaleFactor: 1, mobile: false });
  await checkSurfaces(call, evaluate);
  console.log(`Checked crew: layout, ${points.length} exact-pixel targets, gestures and floating windows`);
}
