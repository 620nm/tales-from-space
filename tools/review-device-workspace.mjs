// Bounded live review of an air alarm's native workspace. The browser only
// sends CDP input and reads rendered nodes; the server remains authoritative.
import assert from "node:assert/strict";
import { copyFile, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { tmpdir } from "node:os";
import { spawn } from "node:child_process";

const engineArg = process.argv[2];
if (!engineArg || process.argv.slice(3).some((arg, i, all) => arg === "--out" && !all[i + 1]))
  throw Error("Usage: node tools/review-device-workspace.mjs /absolute/engine [--out /absolute/output]");
const outArg = process.argv.indexOf("--out");
const engine = resolve(engineArg);
const pack = resolve(process.env.LUNATIC_PACK ?? "");
assert.ok(process.env.LUNATIC_PACK, "LUNATIC_PACK must name the absolute pack checkout");
const scratch = await mkdtemp(join(tmpdir(), "air-alarm-review-"));
const output = outArg >= 0 ? resolve(process.argv[outArg + 1]) : scratch;
const scene = resolve(pack, "tools/scenes/air-alarm.ron");

const reports = [];
let browser;
let launcher;
let serviceText = "";
let browserSession;
let delay = ms => new Promise(resolveDelay => setTimeout(resolveDelay, ms));
const record = chunk => { serviceText = (serviceText + String(chunk)).slice(-24000); };
const suffix = value => `[data-pack-node$=${JSON.stringify(value)}]`;
const exact = value => `[data-pack-node=${JSON.stringify(value)}]`;
const visible = selector => `(()=>{const e=document.querySelector(${JSON.stringify(selector)});if(!e)return false;const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.display!=="none"&&s.visibility!=="hidden"})()`;
const stopLauncher = async () => {
  if (!launcher || launcher.exitCode !== null) return;
  launcher.kill("SIGTERM");
  await Promise.race([
    new Promise(resolveExit => launcher.once("exit", resolveExit)),
    delay(10000),
  ]);
  if (launcher.exitCode === null) launcher.kill("SIGKILL");
};

try {
  await mkdir(output, { recursive: true });
  ({ browserSession, delay } = await import(pathToFileURL(join(engine, "tools/workspace-ui-browser.mjs")).href));
  launcher = spawn(process.execPath, [
    "tools/dev.mjs", "--no-build", "--bind", "127.0.0.1:0", "--mode", "free_build",
    "--no-playtest", "--map", scene, "--audit-dir", join(scratch, "audit"),
  ], { cwd: engine, env: { ...process.env, LUNATIC_PACK: pack }, stdio: ["ignore", "pipe", "pipe"] });
  launcher.stdout.on("data", record);
  launcher.stderr.on("data", record);
  const deadline = Date.now() + 60000;
  while (!serviceText.includes("Development HTTP is enabled. Open:")) {
    if (launcher.exitCode !== null) throw Error(`owned service exited (${launcher.exitCode})`);
    if (Date.now() > deadline) throw Error("owned service startup timeout");
    await delay(100);
  }
  const url = serviceText.match(/Development HTTP is enabled\. Open:\s+(http:\/\/127\.0\.0\.1:\d+)/)?.[1];
  assert.ok(url, "owned service publishes a loopback gateway");

  browser = await browserSession();
  const { call, evaluate, waitFor, click, fill, tile, key, shot } = browser;
  const resize = async (width, height) => {
    await call("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile: false });
    await delay(400);
  };
  const findVisible = predicate => evaluate(`(()=>{const ok=e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.display!=="none"&&s.visibility!=="hidden"};return [...document.querySelectorAll("[data-pack-node]")].find(e=>ok(e)&&(${predicate}))?.dataset.packNode??null})()`);
  const waitWorkspace = async page => waitFor(visible(suffix(page === "files" ? "/panes" : `/${page}-body`)));
  const sourceNode = '[data-pack-node*="/editor/body/"]';
  const sourceInput = `${sourceNode} textarea,textarea${sourceNode}`;
  const geometry = () => evaluate(`(()=>{const e=document.querySelector('.pc-computer-screen');if(!e)return null;const r=e.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height}})()`);
  const waitDownload = async name => {
    const path = join(output, name);
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      try {
        const value = JSON.parse(await readFile(path, "utf8"));
        if (value?.view) return value;
      } catch { /* Chrome can expose the file before the download is complete. */ }
      await delay(100);
    }
    throw Error(`trusted fixture download timeout: ${path}`);
  };
  const recordFixture = async (name = "fixture.json") => {
    const downloaded = join(output, "fixture.json");
    await rm(downloaded, { force: true });
    await call("Page.setDownloadBehavior", { behavior: "allow", downloadPath: output });
    await click("#shell-settings");
    await waitFor("!document.querySelector('#menu')?.hidden && !document.querySelector('#menu-record-ui')?.hidden");
    await click("#menu-record-ui");
    const fixture = await waitDownload("fixture.json");
    await key("Escape", "Escape", 27);
    await waitFor("document.querySelector('#menu')?.hidden === true");
    if (name !== "fixture.json") await copyFile(downloaded, join(output, name));
    return fixture;
  };
  const stateFromFixture = fixture => Object.values(fixture.view?.documents ?? {})
    .map(document => document?.state).find(Boolean);
  const disclosedSetpoint = (fixture, node) => {
    const address = node.match(/\/controls\/([^/]+)/)?.[1];
    const field = node.match(/\/set\/(.+)\/value$/)?.[1];
    const state = stateFromFixture(fixture);
    const panel = state?.control_panels?.find(candidate => candidate.address === address);
    return panel?.setpoints?.find(point => point.field === field)?.value;
  };
  const exactFile = name => findVisible(`e.dataset.packNode.endsWith('/open') && e.tagName === 'BUTTON' && e.textContent.trim() === ${JSON.stringify(name)}`);
  const openFileState = fixture => stateFromFixture(fixture)?.open;
  const capture = async (label, required) => {
    for (const [width, height] of [[1600, 1000], [1366, 768], [1024, 768]]) {
      await resize(width, height);
      const box = await geometry();
      assert.ok(box, `${label} has the live computer screen`);
      assert.ok(box.x >= -1 && box.y >= -1 && box.x + box.w <= width + 1 && box.y + box.h <= height + 1,
        `${label} stays inside ${width}x${height}`);
      for (const path of required) assert.equal(await evaluate(visible(suffix(path))), true, `${label} shows ${path}`);
      await shot(join(output, `${label}-${width}x${height}.png`));
      reports.push({ label, width, height, box, required });
    }
    console.log(`captured ${label} at 1600, 1366 and 1024px`);
  };

  await resize(1600, 1000);
  await call("Page.enable");
  await call("Runtime.enable");
  await call("Page.navigate", { url });
  await waitFor('document.querySelector("#menu-join")?.getBoundingClientRect().width > 0 && !document.querySelector("#menu-join").disabled');
  await click("#menu-join");
  await waitFor('window.__camera && document.querySelector("[data-pack-node=worn-toggle]")');
  await delay(1000);

  // The free-build body starts on the map's player_spawn beside the card.
  // A real world click picks it up; no item or authority is injected.
  await tile(7, 2);
  await delay(700);
  // North-mounted art is picked on the wall above the fixture's owning tile.
  await tile(6, 0);
  await waitWorkspace("controls");
  assert.equal(await evaluate(visible(suffix("/lock"))), false, "direct alarm opens through Controls, not the contact lock screen");

  // Details is the first tab, but Controls remains the initial page. The
  // native lock action stays in the heading, so unlocking does not navigate.
  const lockSelector = suffix("/toggle/link_lock/switch");
  const lockIconSelector = suffix("/toggle/link_lock/switch/icon");
  const lockState = () => evaluate(`(()=>{const e=document.querySelector(${JSON.stringify(lockSelector)}),i=document.querySelector(${JSON.stringify(lockIconSelector)}),s=i&&getComputedStyle(i);return e?{text:e.textContent.trim(),disabled:e.disabled,icon:s?[s.backgroundImage,s.backgroundPosition].join(" "):null}:null})()`);
  const beforeLock = await lockState();
  assert.ok(beforeLock, "Controls heading exposes the native link lock action");
  assert.equal(beforeLock.text, "Unlock", "the initial native lock action says Unlock");
  assert.equal(beforeLock.disabled, false, "the initial native lock action is usable");
  assert.equal(await evaluate(visible(lockIconSelector)), true, "the initial lock action shows its icon");
  const tabOrder = await evaluate(`(()=>{const e=document.querySelector(${JSON.stringify(suffix("/workspace-tabs"))});return e?[...e.children].map(child=>child.dataset.packNode??""):[]})()`);
  const detailsTab = tabOrder.findIndex(id => id.endsWith("/workspace/details"));
  const controlsTab = tabOrder.findIndex(id => id.endsWith("/workspace/controls"));
  assert.ok(detailsTab === 0 && controlsTab === 1, "Details tab precedes Controls");
  await capture("locked", ["/controls-body", "/toggle/link_lock/switch", "/toggle/link_lock/switch/icon"]);
  const lockedFixture = await recordFixture("fixture-locked.json");
  const lockedState = stateFromFixture(lockedFixture);
  assert.equal(lockedState?.toggles?.find(toggle => toggle.field === "link_lock")?.on, false,
    "the trusted initial fixture reports the link as locked");

  await click(lockSelector);
  await waitFor(`(()=>{const e=document.querySelector(${JSON.stringify(lockSelector)});return !!e && e.textContent.trim() !== ${JSON.stringify(beforeLock.text)}})()`);
  const afterLock = await lockState();
  assert.equal(afterLock.text, "Lock", "the native heading action now says Lock");
  assert.equal(await evaluate(visible(lockIconSelector)), true, "the unlocked action shows its icon");
  assert.ok(afterLock.icon && afterLock.icon !== beforeLock.icon, "the rendered lock icon changes after native unlock");
  assert.equal(await evaluate(visible(suffix("/details-body"))), false, "unlocking does not open Details");
  await waitWorkspace("controls");
  const unlockedFixture = await recordFixture();
  const unlockedState = stateFromFixture(unlockedFixture);
  assert.equal(unlockedState?.toggles?.find(toggle => toggle.field === "link_lock")?.on, true,
    "the trusted fixture reports on=true for the unlocked link");

  // Re-query after every native response. Each accepted candidate disappears
  // and becomes a member row; a cached button would press stale state.
  await click(suffix("/workspace/details"));
  await waitWorkspace("details");
  const joinable = () => evaluate(`(()=>[...document.querySelectorAll('button[data-pack-node]')].filter(e=>{const p=e.dataset.packNode;const r=e.getBoundingClientRect(),s=getComputedStyle(e);return p.includes('/toggle/link_join/')&&!e.disabled&&r.width>0&&r.height>0&&s.visibility!=='hidden'}).map(e=>({id:e.dataset.packNode,text:e.textContent})).sort((a,b)=>Number(a.text.includes('pump'))-Number(b.text.includes('pump'))))()`);
  const memberCount = () => evaluate(`document.querySelectorAll('button[data-pack-node*="/toggle/link_drop/"]').length`);
  for (let joined = 0; joined < 2; joined++) {
    const candidates = await joinable();
    assert.equal(candidates.length, 2 - joined, `air alarm offers ${2 - joined} remaining atmos candidates (got ${candidates.length})`);
    await click(exact(candidates[0].id));
    await waitFor(`document.querySelectorAll('button[data-pack-node*="/toggle/link_drop/"]').length >= ${joined + 1}`);
  }
  assert.equal(await memberCount(), 2, "native member rows retain both accepted devices");
  await click(suffix("/workspace/controls"));
  await waitFor('document.querySelectorAll("[data-pack-node*=" + JSON.stringify("/controls/") + "][data-pack-node$=" + JSON.stringify("/name") + "]").length === 2');
  await capture("controls", ["/controls-body", "/toggle/link_lock/switch", "/toggle/link_lock/switch/icon"]);
  const controlsFixture = await recordFixture("fixture-controls.json");
  assert.equal(stateFromFixture(controlsFixture)?.control_panels?.length, 2, "trusted fixture captures both disclosed control cards");
  const bodyBox = await evaluate(`(()=>{const r=document.querySelector(${JSON.stringify(suffix("/workspace/body"))}).getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()`);
  await call("Input.dispatchMouseEvent", { type: "mouseWheel", ...bodyBox, deltaX: 0, deltaY: 1200 });
  await delay(400);
  await shot(join(output, "controls-gases-1024x768.png"));
  await call("Input.dispatchMouseEvent", { type: "mouseWheel", ...bodyBox, deltaX: 0, deltaY: -1200 });
  await delay(400);

  const setpoint = await evaluate(`(()=>[...document.querySelectorAll('input[data-pack-node]')].find(e=>{const p=e.dataset.packNode;return p.includes('/set/')&&p.includes('setpoint')&&!e.disabled&&e.getBoundingClientRect().width>0})?.dataset.packNode??null)()`);
  assert.ok(setpoint, "a reached air device exposes its native setpoint input");
  const field = setpoint.match(/\/set\/(.+)\/value$/)?.[1];
  const setting = stateFromFixture(controlsFixture).control_panels.flatMap(panel => panel.setpoints).find(point => point.field === field);
  assert.ok(setting, "native provider declares the selected setpoint");
  const wanted = Number(((setting.min + setting.max) / 2).toFixed(setting.decimals ?? 0));
  assert.ok(wanted >= setting.min && wanted <= setting.max, "review setpoint is within native bounds");
  assert.notEqual(setting.value, wanted, "review setpoint has a distinct native endpoint");
  await fill(exact(setpoint), wanted.toFixed(setting.decimals ?? 0));
  await waitFor(`Number(document.querySelector(${JSON.stringify(exact(setpoint))})?.value) === ${wanted}`);
  let setpointFixture;
  let serverSetpoint;
  for (let attempt = 0; attempt < 20; attempt++) {
    setpointFixture = await recordFixture();
    serverSetpoint = Number(disclosedSetpoint(setpointFixture, setpoint));
    if (Math.abs(serverSetpoint - wanted) < 1e-6) break;
    await delay(250);
  }
  assert.ok(setpointFixture && Math.abs(serverSetpoint - wanted) < 1e-6,
    `later trusted provider view reports setpoint ${wanted} (got ${serverSetpoint})`);
  reports.push({ action: "setpoint", node: setpoint, before: setting.value, after: wanted, server: serverSetpoint });

  const power = stateFromFixture(controlsFixture).control_panels.flatMap(panel => panel.toggles)
    .find(toggle => toggle.field.endsWith("/power"));
  assert.ok(power, "native provider declares a reached power switch");
  await click(suffix(`/toggle/${power.field}/switch/press`));
  await delay(250);
  const powerFixture = await recordFixture();
  const switched = stateFromFixture(powerFixture).control_panels.flatMap(panel => panel.toggles)
    .find(toggle => toggle.field === power.field);
  assert.equal(switched?.on, !power.on, "trusted provider confirms the reached power toggle");
  reports.push({ action: "power", field: power.field, before: power.on, after: switched.on });
  await click(suffix(`/toggle/${power.field}/switch/press`));

  await click(suffix("/workspace/details"));
  await waitWorkspace("details");
  await waitFor(visible(suffix("/details-body")));
  await capture("details", ["/workspace/details", "/details-body"]);
  await click(suffix("/workspace/programs"));
  await waitWorkspace("programs");
  await capture("programs", ["/workspace/programs"]);
  await click(suffix("/workspace/files"));
  await waitWorkspace("files");

  // Create and edit one native host file, then use the real workspace tab
  // transition. A dirty draft must pass through the native guard and remain
  // in the editor when Files is selected again.
  const create = await findVisible("e.dataset.packNode.endsWith('/drive/host/create') && e.tagName === 'BUTTON' && !e.disabled");
  assert.ok(create, "Files exposes its native host create action");
  await click(exact(create));
  await waitFor(visible(suffix("/drive/host/create/stem")));
  await fill(suffix("/drive/host/create/stem"), "controls-review");
  const extension = await evaluate(`document.querySelector(${JSON.stringify(suffix("/drive/host/create/ext"))})?.value ?? "md"`);
  const fileName = `controls-review.${extension}`;
  await click(suffix("/drive/host/create/confirm"));
  await waitFor(`!![...document.querySelectorAll('button[data-pack-node*="/drive/host/file/"][data-pack-node$="/open"]')].find(e=>e.textContent.trim() === ${JSON.stringify(fileName)})`);
  const file = await exactFile(fileName);
  assert.ok(file, "created file appears in the native host drive");
  await click(exact(file));
  await delay(500);
  const edit = await findVisible("e.dataset.packNode.endsWith('/editor/edit') && e.tagName === 'BUTTON'");
  if (edit) await click(exact(edit));
  await waitFor(visible(sourceNode));
  const editor = await evaluate(`document.querySelector('[data-pack-node*="/editor/body/"]')?.dataset.packNode??null`);
  assert.ok(editor, "native editor mounts for the created file");
  const draft = "-- Controls-first live draft\nlocal enabled = true\n";
  const editorSelector = `${exact(editor)} textarea,textarea${exact(editor)}`;
  await fill(editorSelector, draft);
  await click(suffix("/workspace/controls"));
  await waitFor(visible(suffix("/editor/guard")));
  await click(suffix("/editor/guard/save"));
  await waitFor(`!document.querySelector(${JSON.stringify(suffix("/editor/guard"))})`);
  await waitWorkspace("controls");
  const savedFixture = await recordFixture("fixture-saved.json");
  const savedOpen = openFileState(savedFixture);
  assert.equal(savedOpen?.name, "controls-review", "native save receipt names the exact review file");
  assert.equal(savedOpen?.ext, extension, "native save receipt retains the exact file type");
  assert.equal(savedOpen?.body, draft, "native save receipt contains the complete draft");

  // Close the actual host window so the next read cannot come from the
  // retained local buffer. Reopen the map device and read the exact file.
  await click(".pc-computer-screen .pc-window-close");
  await waitFor("!document.querySelector('.pc-computer-screen')");
  await tile(6, 0);
  await waitWorkspace("controls");
  await click(suffix("/workspace/files"));
  await waitWorkspace("files");
  const editAgain = await exactFile(fileName);
  assert.ok(editAgain, "exact saved file survives workspace reopen");
  await click(exact(editAgain));
  await delay(500);
  const editMode = await findVisible("e.dataset.packNode.endsWith('/editor/edit') && e.tagName === 'BUTTON'");
  if (editMode) await click(exact(editMode));
  await waitFor(`document.querySelector(${JSON.stringify(sourceInput)})?.value === ${JSON.stringify(draft)}`);
  reports.push({ action: "draft-save-close-reopen", editor, file: fileName, draft });
  await capture("files", ["/workspace/files"]);

  // Closing the menu can cancel its pending media play request in Chrome.
  const mediaAbort = error => error.startsWith("AbortError: The play() request was interrupted by a call to pause().");
  const mediaAborts = browser.errors.filter(mediaAbort);
  reports.push({ mediaAborts });
  assert.deepEqual(browser.errors.filter(error => !mediaAbort(error)), [], "live browser has no unexpected errors");
  await writeFile(join(output, "results.json"), JSON.stringify(reports, null, 2));
  console.log(`Air alarm workspace review complete: ${output}`);
} catch (error) {
  await browser?.shot(join(output, "failure.png")).catch(() => {});
  const failureDom = await browser?.evaluate("document.body.innerText") ?? "";
  await writeFile(join(output, "failure-dom.txt"), String(failureDom).slice(-24000));
  await writeFile(join(output, "failure-log.txt"), serviceText.slice(-24000));
  throw error;
} finally {
  await browser?.close().catch(() => {});
  await stopLauncher();
  await writeFile(join(output, "results.json"), JSON.stringify(reports, null, 2)).catch(() => {});
  if (scratch !== output) await rm(scratch, { recursive: true, force: true }).catch(() => {});
}
