import assert from "node:assert/strict";
import { access } from "node:fs/promises";
import { constants } from "node:fs";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const pack = resolve(fileURLToPath(new URL("..", import.meta.url)));
const engine = resolve(process.argv[2] ?? process.env.LUNATIC_ENGINE ?? join(pack, "..", "lunatic"));
const { Cdp, findChrome, launchChrome } = await import(pathToFileURL(resolve(engine, "tools/ui-lab/cdp.mjs")));
const { startLab } = await import(pathToFileURL(resolve(engine, "tools/ui-lab/serve.mjs")));
const chrome = await findChrome();
const available = await Promise.all([
  access(resolve(pack, "ui/bundle.json"), constants.R_OK),
  access(resolve(engine, "web/dist/style.css"), constants.R_OK),
  access(resolve(engine, "web/dist/pack-ui/worker.js"), constants.R_OK),
]).then(() => true, () => false);
const skip = !chrome ? "Chromium unavailable" : !available ? "generated UI lab bundle is unavailable" : false;
if (skip) console.log(`SKIP preparation UI browser: ${skip}`);

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
const node = (id) => `(() => document.querySelector('[data-pack-node='+CSS.escape(${JSON.stringify(id)})+']'))()`;
async function point(cdp, id) {
  return cdp.evaluate(`(() => {
    const el = ${node(id)};
    if (!el || el.disabled) throw Error("unavailable input target: ${id}");
    const r = el.getBoundingClientRect(), x = r.x + r.width / 2, y = r.y + r.height / 2;
    if (!r.width || !r.height || !el.contains(document.elementFromPoint(x, y))) throw Error("obscured input target: ${id}");
    return { x, y };
  })()`);
}
async function click(cdp, id) {
  const position = await point(cdp, id);
  await cdp.call("Input.dispatchMouseEvent", { type: "mousePressed", ...position, button: "left", clickCount: 1 });
  await cdp.call("Input.dispatchMouseEvent", { type: "mouseReleased", ...position, button: "left", clickCount: 1 });
}
async function selectAll(cdp) {
  await cdp.call("Input.dispatchKeyEvent", { type: "keyDown", key: "a", code: "KeyA", windowsVirtualKeyCode: 65, modifiers: 2 });
  await cdp.call("Input.dispatchKeyEvent", { type: "keyUp", key: "a", code: "KeyA", windowsVirtualKeyCode: 65, modifiers: 2 });
}
function tickView(base, tick, pending) {
  const view = structuredClone(base);
  view.revision = base.revision + tick + 1;
  view.state.round = { ...base.state.round, remaining_seconds: base.state.round.remaining_seconds === null
    ? null : Math.max(0, base.state.round.remaining_seconds - tick - 1) };
  view.state.preparationPending = pending;
  return view;
}

test("name edits preserve typing and follow-up clicks through pending updates", { skip }, async (t) => {
  const scratch = await mkdtemp(join(tmpdir(), "tfs-preparation-name-"));
  let lab;
  let browser;
  let cdp;
  t.after(async () => {
    cdp?.close();
    await browser?.stop();
    await lab?.close();
    await rm(scratch, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  });
  // Use the baked atlas manifest so `/obj/<sha>.woff2` serves every font
  // declared by the real package. Synthetic assets intentionally publish no
  // font objects, which would turn valid Patrick/Kalam faces into faults.
  lab = await startLab({ root: engine, pack });
  browser = await launchChrome({ profileDir: join(scratch, "profile") });
  cdp = await Cdp.tab(browser.endpoint, { timeout: 30000 });

  for (const [fixtureName, value, completion] of [
    ["preparation", "Mira Pike", "chat"],
    ["preparation-playing", "Rook", "chat"],
  ]) {
    const fixture = lab.fixtures().find((candidate) => candidate.name === fixtureName);
    assert(fixture, `missing ${fixtureName} fixture`);
    await cdp.call("Emulation.setDeviceMetricsOverride", {
      width: fixture.viewport.width, height: fixture.viewport.height, deviceScaleFactor: fixture.viewport.dpr, mobile: false,
    });
    await cdp.navigate(`${lab.origin}/f/${fixtureName}`);
    await cdp.evaluate("lab.ready.then(() => true)");
    await click(cdp, "preparation/name");
    await selectAll(cdp);

    for (const [tick, character] of [...value].entries()) {
      await cdp.call("Input.insertText", { text: character });
      // The old name debounce was 120 ms. A quiet pause longer than that
      // must still leave an active, editable field with no partial action.
      await sleep(150);
      const emitted = await cdp.evaluate("lab.events.length");
      assert.equal(emitted, 0, `${fixtureName}: typing emitted a partial draft`);
      const next = tickView(fixture.view, tick, emitted > 0);
      await cdp.evaluate(`lab.host.update(${JSON.stringify(next)}); lab.settled().then(() => true)`);
      assert.equal(await cdp.evaluate(`${node("preparation/name")} === document.activeElement`), true,
        `${fixtureName}: authoritative update dropped name focus`);
      assert.equal(await cdp.evaluate(`${node("preparation/name")}.value`), value.slice(0, tick + 1),
        `${fixtureName}: authoritative update replaced the local name`);
    }

    assert.equal(await cdp.evaluate("lab.events.length"), 0, `${fixtureName}: draft emitted before completion`);
    await click(cdp, completion);
    await cdp.evaluate("lab.settled().then(() => true)");
    const actions = await cdp.evaluate("lab.events.map((event) => event.action)");
    const drafts = actions.filter((action) => action?.kind === "character_draft");
    assert.equal(drafts.length, 1, `${fixtureName}: completion emitted more than one draft`);
    assert.equal(drafts[0].draft.name, value, `${fixtureName}: completion lost the full name`);
    assert.equal(drafts[0].round, fixture.view.state.preparation.round);
    assert.equal(drafts[0].revision, fixture.view.state.preparation.revision);

    const accepted = structuredClone(fixture.view);
    accepted.state.preparation.draft.name = value;
    accepted.state.preparation.revision++;
    await cdp.evaluate(`lab.host.update(${JSON.stringify(accepted)}); lab.settled().then(() => true)`);
    await click(cdp, "preparation/name");
    await selectAll(cdp);
    await cdp.call("Input.insertText", { text: `${value} II` });
    for (const type of ["keyDown", "keyUp"])
      await cdp.call("Input.dispatchKeyEvent", { type, key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
    await cdp.evaluate("lab.settled().then(() => true)");
    assert.equal(await cdp.evaluate("lab.events.length"), 2, `${fixtureName}: Enter submits once`);
    accepted.state.preparation.draft.name = `${value} II`;
    accepted.state.preparation.revision++;
    await cdp.evaluate(`lab.host.update(${JSON.stringify(accepted)}); lab.settled().then(() => true)`);
    await click(cdp, completion);
    await cdp.evaluate("lab.settled().then(() => true)");
    assert.equal(await cdp.evaluate("lab.events.length"), 2, `${fixtureName}: blur does not resubmit the accepted name`);
  }

  for (const [fixtureName, target, kind] of [
    ["preparation", "preparation/ready", "ready"],
    ["preparation", "preparation/ranked/assistant/remove", "character_draft"],
    ["preparation-playing", "job/assistant", "join"],
  ]) {
    const fixture = lab.fixtures().find((candidate) => candidate.name === fixtureName);
    await cdp.call("Emulation.setDeviceMetricsOverride", {
      width: fixture.viewport.width, height: fixture.viewport.height, deviceScaleFactor: fixture.viewport.dpr, mobile: false,
    });
    await cdp.navigate(`${lab.origin}/f/${fixtureName}`);
    await cdp.evaluate("lab.ready.then(() => true)");
    await click(cdp, "preparation/name");
    await selectAll(cdp);
    await cdp.call("Input.insertText", { text: "Held Click" });
    const position = await point(cdp, target);
    await cdp.call("Input.dispatchMouseEvent", { type: "mousePressed", ...position, button: "left", clickCount: 1 });
    await cdp.evaluate("lab.settled().then(() => true)");
    assert.equal(await cdp.evaluate("lab.events[0]?.action?.draft.name"), "Held Click");
    const pending = tickView(fixture.view, 1, true);
    pending.state.preparationCanQueue = true;
    await cdp.evaluate(`lab.host.update(${JSON.stringify(pending)}); lab.settled().then(() => true)`);
    assert.equal(await cdp.evaluate(`${node(target)}.disabled`), false, `${target}: pending save swallowed held click`);
    assert.equal(await cdp.evaluate(`${node("preparation/name")}.disabled`), true);
    await cdp.call("Input.dispatchMouseEvent", { type: "mouseReleased", ...position, button: "left", clickCount: 1 });
    await cdp.evaluate("lab.settled().then(() => true)");
    assert.equal(await cdp.evaluate("lab.events.length"), 2, `${target}: mouseup must emit exactly one follow-up`);
    assert.equal(await cdp.evaluate("lab.events[1]?.action?.kind"), kind);
    pending.revision++;
    pending.state.preparationCanQueue = false;
    await cdp.evaluate(`lab.host.update(${JSON.stringify(pending)}); lab.settled().then(() => true)`);
    assert.equal(await cdp.evaluate(`${node(target)}.disabled`), true, `${target}: consumed queue must lock controls`);
  }
});
