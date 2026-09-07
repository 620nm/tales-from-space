// Exercise browser pointer capture; synthetic DOM clicks cannot test dragging.
export async function checkSurfaces(call, evaluate) {
  const assert = (value, message) => { if (!value) throw new Error(message); };
  const rect = selector => evaluate(`document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect().toJSON()`);
  const click = selector => evaluate(`document.querySelector(${JSON.stringify(selector)}).click()`);
  const drag = async (selector, dx, dy) => {
    const box = await rect(selector);
    const x = box.left + Math.min(35, box.width / 2), y = box.top + box.height / 2;
    await call("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
    await call("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", buttons: 1, clickCount: 1 });
    await call("Input.dispatchMouseEvent", { type: "mouseMoved", x: x + dx, y: y + dy, button: "left", buttons: 1 });
    await call("Input.dispatchMouseEvent", { type: "mouseReleased", x: x + dx, y: y + dy, button: "left", buttons: 0, clickCount: 1 });
  };
  await evaluate("ConceptSurfaces.open('device')");
  const world = await rect("#world"), initial = await rect("#device");
  await drag("#device [data-window-title]", -220, 70);
  const moved = await rect("#device");
  assert(Math.abs(moved.left - initial.left + 220) < 2 && Math.abs(moved.top - initial.top - 70) < 2, "Device title drag failed");
  await drag('#device [data-resize="se"]', 80, 35);
  const resized = await rect("#device");
  assert(resized.width >= moved.width + 79 && resized.height >= moved.height + 34, "Device resize failed");
  await click("#device [data-window-close]");
  await click("#device-toggle");
  assert(JSON.stringify(await rect("#device")) === JSON.stringify(resized), "Device loses geometry on reopen");
  await click("#second-device");
  const second = await rect("#device-secondary");
  await drag("#device-secondary [data-window-title]", -90, 60);
  assert((await rect("#device-secondary")).left < second.left - 89, "Second device cannot move independently");
  assert(JSON.stringify(await rect("#device")) === JSON.stringify(resized), "Second device changes first device geometry");
  assert(JSON.stringify(await rect("#world")) === JSON.stringify(world), "Device manipulation changes world viewport");
  await click("#device-secondary [data-window-close]");
  await click("#device [data-window-close]");
}
