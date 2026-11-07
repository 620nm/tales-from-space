// Real-browser acceptance for generated Strange Disk media. The browser only
// sends trusted input and samples rendered pixels/audio; the server owns state.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { createConnection, isIP } from "node:net";
import { networkInterfaces } from "node:os";
import { isAbsolute, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const pack = resolve(fileURLToPath(new URL("..", import.meta.url)));
const scene = join(pack, "tools/scenes/strange-disk-browser.ron");
const usage = "Usage: node tools/strange-disk-browser.mjs /absolute/engine [--out DIR] [--listener-host IPv4]";

function parseArgs(argv) {
  if (argv[0] === "--help") {
    console.log(usage);
    process.exit(0);
  }
  const engineArg = argv[0];
  if (!engineArg || !isAbsolute(engineArg)) throw Error(usage);
  const options = { engine: resolve(engineArg), out: undefined, listenerHost: process.env.STRANGE_DISK_LISTENER_HOST };
  for (let index = 1; index < argv.length; index++) {
    const flag = argv[index];
    if (flag === "--out" && argv[index + 1]) options.out = resolve(argv[++index]);
    else if (flag === "--listener-host" && argv[index + 1]) options.listenerHost = argv[++index];
    else throw Error(usage);
  }
  return options;
}

function candidateListenerHost() {
  for (const addresses of Object.values(networkInterfaces())) {
    for (const info of addresses ?? []) {
      if ((info.family === "IPv4" || info.family === 4) && !info.internal && !info.address.startsWith("169.254."))
        return info.address;
    }
  }
  return undefined;
}

function visible(selector) {
  return `(()=>{const e=document.querySelector(${JSON.stringify(selector)});if(!e)return false;const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.display!=="none"&&s.visibility!=="hidden"})()`;
}

const exact = node => `[data-pack-node=${JSON.stringify(node)}]`;
const suffix = value => `[data-pack-node$=${JSON.stringify(value)}]`;
const delay = ms => new Promise(resolveDelay => setTimeout(resolveDelay, ms));

const AUDIO_PROBE = `(() => {
  if (window.__strangeDiskAudio) return;
  const state = { supported: !!window.AudioNode, taps: [], media: new Set(), streams: [], visibilityEvents: [] };
  if (window.WebSocket) {
    const nativeSend = WebSocket.prototype.send;
    WebSocket.prototype.send = function(data) {
      const frame = { at: performance.now(), bytes: data?.byteLength ?? data?.length ?? null };
      const event = state.visibilityEvents.at(-1);
      if (event && event.frame === null && frame.at - event.at < 1000) event.frame = frame;
      return Reflect.apply(nativeSend, this, [data]);
    };
  }
  document.addEventListener("visibilitychange", () => {
    state.visibilityEvents.push({ sequence: state.visibilityEvents.length, hidden: document.hidden, at: performance.now(), frame: null });
  }, true);
  if (window.AudioNode) {
    const nativeConnect = AudioNode.prototype.connect;
    state.nativeConnect = nativeConnect;
    const seen = new WeakSet();
    AudioNode.prototype.connect = function(destination, ...args) {
      const result = Reflect.apply(nativeConnect, this, [destination, ...args]);
      let context;
      try { context = this.context; } catch { return result; }
      if (destination !== context.destination) return result;
      if (!seen.has(this)) {
        try {
          const analyser = context.createAnalyser();
          analyser.fftSize = 2048;
          Reflect.apply(nativeConnect, this, [analyser]);
          state.taps.push({ node: this, context, analyser, samples: new Float32Array(analyser.fftSize) });
          seen.add(this);
        } catch { /* A failed observer never changes the page's audio route. */ }
      }
      for (const stream of state.streams) {
        if (stream.context === context) {
          try { Reflect.apply(nativeConnect, this, [stream.destination]); } catch { /* retired output */ }
        }
      }
      return result;
    };
  }
  if (window.HTMLMediaElement) {
    const nativePlay = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function(...args) {
      state.media.add(this);
      return Reflect.apply(nativePlay, this, args);
    };
  }
  const stats = () => {
    const taps = state.taps.map((tap, index) => {
      tap.analyser.getFloatTimeDomainData(tap.samples);
      let square = 0, peak = 0;
      for (const sample of tap.samples) {
        square += sample * sample;
        peak = Math.max(peak, Math.abs(sample));
      }
      const rms = Math.sqrt(square / tap.samples.length);
      return { index, running: tap.context.state === "running", context: tap.context.state,
        sampleRate: tap.context.sampleRate, rms, peak, node: tap.node.constructor.name };
    });
    const media = [...state.media].map(element => ({ playing: !element.paused && !element.ended,
      currentTime: element.currentTime, readyState: element.readyState, source: element.currentSrc || element.src }));
    return { supported: state.supported, taps, media,
      visibilityEvents: state.visibilityEvents.slice(-8),
      audible: taps.some(tap => tap.running && tap.rms > 0.00001) || media.some(element => element.playing && element.currentTime > 0) };
  };
  const encode = bytes => {
    let binary = "";
    for (let index = 0; index < bytes.length; index += 0x8000)
      binary += String.fromCharCode(...bytes.subarray(index, index + 0x8000));
    return btoa(binary);
  };
  const record = async durationMs => {
    const initial = stats();
    if (!window.MediaRecorder) return { error: "MediaRecorder audio capture is unavailable", bytes: 0 };
    const activeTaps = state.taps.filter((tap, index) => tap.context.state === "running" &&
      initial.taps[index]?.running && initial.taps[index]?.rms > 0.00001);
    let stream, context, destination;
    if (activeTaps.length) {
      context = activeTaps[0].context;
      destination = context.createMediaStreamDestination();
      for (const tap of activeTaps) Reflect.apply(state.nativeConnect, tap.node, [destination]);
      state.streams.push({ context, destination });
      stream = destination.stream;
    } else {
      const element = [...state.media].find(candidate => !candidate.paused && !candidate.ended && candidate.captureStream);
      if (!element) return { error: "No active browser audio output to record", bytes: 0 };
      stream = element.captureStream();
    }
    if (!stream.getAudioTracks().length) return { error: "Audio recording stream has no audio track", bytes: 0 };
    const recorder = new MediaRecorder(stream);
    const chunks = [];
    recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
    const finished = new Promise((resolveStop, rejectStop) => {
      recorder.onerror = event => rejectStop(event.error || Error("MediaRecorder failed"));
      recorder.onstop = resolveStop;
      recorder.start();
      setTimeout(() => { if (recorder.state !== "inactive") recorder.stop(); }, durationMs);
    });
    try { await finished; }
    finally {
      state.streams = state.streams.filter(entry => entry.destination !== destination);
      for (const track of stream.getTracks()) track.stop();
    }
    const blob = new Blob(chunks, { type: recorder.mimeType || "audio/webm" });
    const bytes = new Uint8Array(await blob.arrayBuffer());
    return { mime: blob.type, bytes: bytes.length, base64: encode(bytes) };
  };
  Object.defineProperty(window, "__strangeDiskAudio", { value: { snapshot: stats, record } });
})();`;

const options = parseArgs(process.argv.slice(2));
const listenerHost = options.listenerHost ?? candidateListenerHost();
const tempRoot = resolve(process.env.TMPDIR || join(pack, "target", "strange-disk-browser"));
assert.ok(tempRoot !== "/tmp" && !tempRoot.startsWith("/tmp/"), `scratch root must be disk-backed, got ${tempRoot}`);
await mkdir(tempRoot, { recursive: true });
if (options.out) await mkdir(options.out, { recursive: true });
const output = options.out ?? await mkdtemp(join(tempRoot, "artifacts-"));
assert.ok(output !== "/tmp" && !output.startsWith("/tmp/"), `artifact directory must be disk-backed, got ${output}`);
await mkdir(output, { recursive: true });
const scratch = await mkdtemp(join(tempRoot, "scratch-"));

const report = {
  harness: "strange-disk-browser",
  status: "running",
  engine: options.engine,
  pack,
  scene,
  artifacts: {},
  evidence: {},
  checks: [],
  failure: null,
};
let browserSession;
let sourceBrowser;
let listenerBrowser;
let launcher;
let serviceText = "";
let activePhase = "startup";
const recordService = chunk => { serviceText = (serviceText + String(chunk)).slice(-24000); };

async function stopLauncher() {
  if (!launcher || launcher.exitCode !== null) return;
  launcher.kill("SIGTERM");
  await Promise.race([
    new Promise(resolveExit => launcher.once("exit", resolveExit)),
    delay(10000),
  ]);
  if (launcher.exitCode === null) launcher.kill("SIGKILL");
}

async function localSourceAddress(host, port) {
  const socket = createConnection({ host, port: Number(port) });
  return new Promise((resolveAddress, rejectAddress) => {
    socket.once("connect", () => {
      const address = socket.localAddress;
      socket.destroy();
      resolveAddress(address);
    });
    socket.once("error", rejectAddress);
  });
}

function hostUrl(host, port) {
  return `http://${host.includes(":") ? `[${host}]` : host}:${port}`;
}

async function visibleNode(browser, predicate) {
  return browser.evaluate(`(()=>{const shown=e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.display!=="none"&&s.visibility!=="hidden"};return [...document.querySelectorAll("[data-pack-node]")].find(e=>shown(e)&&(${predicate}))?.dataset.packNode??null})()`);
}

async function waitNode(browser, predicate, label, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const node = await visibleNode(browser, predicate);
    if (node) return node;
    await delay(150);
  }
  throw Error(`Timed out waiting for visible ${label}`);
}

async function joinBrowser(url) {
  const browser = await browserSession();
  await browser.call("Page.addScriptToEvaluateOnNewDocument", { source: AUDIO_PROBE });
  await browser.call("Emulation.setDeviceMetricsOverride", { width: 1366, height: 768, deviceScaleFactor: 1, mobile: false });
  await browser.call("Page.navigate", { url });
  await browser.waitFor('document.querySelector("#menu-join")?.getBoundingClientRect().width > 0 && !document.querySelector("#menu-join").disabled');
  await browser.click("#menu-join");
  await browser.waitFor('window.__camera && document.getElementById("view")');
  await delay(750);
  return browser;
}

async function audioSnapshot(browser) {
  return browser.evaluate("window.__strangeDiskAudio?.snapshot() ?? null");
}

async function waitForAudio(browser, label, consecutive = 2, timeoutMs = 10000) {
  const deadline = Date.now() + timeoutMs;
  let streak = 0, last = null;
  while (Date.now() < deadline) {
    last = await audioSnapshot(browser);
    if (last?.audible) {
      if (++streak >= consecutive) return last;
    } else streak = 0;
    await delay(180);
  }
  throw Error(`${label}: no sustained browser audio signal (${JSON.stringify(last)})`);
}

async function waitForSilence(browser, label, consecutive = 3, timeoutMs = 6000) {
  const deadline = Date.now() + timeoutMs;
  let streak = 0, last = null;
  while (Date.now() < deadline) {
    last = await audioSnapshot(browser);
    if (last && !last.audible) {
      if (++streak >= consecutive) return last;
    } else streak = 0;
    await delay(160);
  }
  throw Error(`${label}: audio remained active (${JSON.stringify(last)})`);
}

async function observeAudio(browser, label) {
  try {
    return { status: "passed", evidence: await waitForAudio(browser, label) };
  } catch (error) {
    return { status: "failed", error: String(error), evidence: await audioSnapshot(browser).catch(() => null) };
  }
}

async function observeVisibilityFrame(browser, hidden, afterSequence, timeoutMs = 3000) {
  const deadline = Date.now() + timeoutMs;
  let last = null;
  while (Date.now() < deadline) {
    last = await audioSnapshot(browser);
    const event = [...(last?.visibilityEvents ?? [])].reverse().find(row =>
      row.sequence > afterSequence && row.hidden === hidden && row.frame?.bytes > 0);
    if (event) return { status: "passed", event };
    await delay(100);
  }
  return { status: "failed", evidence: last };
}

function recordCheck(name, status, evidence) {
  report.checks.push({ name, status, evidence });
}

async function saveAudioArtifact(browser, filename) {
  const capture = await browser.evaluate("window.__strangeDiskAudio.record(1200)");
  assert.ok(capture && capture.bytes > 0 && capture.base64, `${filename} records a nonempty browser audio stream`);
  const bytes = Buffer.from(capture.base64, "base64");
  await writeFile(join(output, filename), bytes);
  report.artifacts[filename] = { mime: capture.mime, bytes: bytes.length };
  return report.artifacts[filename];
}

function bitmapFromSource(body) {
  const lines = body.split("\n");
  assert.equal(lines[0], "STRANGE1", "the open read-only source is the generated disk file");
  assert.equal(lines[1], "64x48", "the generated bitmap dimensions are present in source");
  assert.equal(lines[2], "000000,AA0000,AAAAAA,555555,FFFFFF", "the generated bitmap palette is present in source");
  assert.match(lines[3] ?? "", /^[0-4]{3072}$/, "the generated source contains 3072 indexed pixels");
  assert.equal(lines[4], "150,90", "the generated score settings are present in source");
  assert.ok(lines[5]?.length, "the generated source contains its score notes");
  return {
    width: 64,
    height: 48,
    palette: lines[2].split(",").map(color => `#${color}`),
    pixels: lines[3],
  };
}

async function readBitmapSource(browser) {
  await browser.waitFor(`(()=>[...document.querySelectorAll("[data-pack-node]")].some(e=>typeof e.value==="string"&&e.value.startsWith("STRANGE1\\n64x48\\n")))()`);
  return browser.evaluate(`(()=>{const e=[...document.querySelectorAll("[data-pack-node]")].find(e=>typeof e.value==="string"&&e.value.startsWith("STRANGE1\\n64x48\\n"));return e?{node:e.dataset.packNode,body:e.value}:null})()`);
}

async function captureBitmap(browser, node, sourceBitmap) {
  const selector = exact(node);
  const box = await browser.evaluate(`(()=>{const e=document.querySelector(${JSON.stringify(selector)});if(!e)return null;const r=e.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height}})()`);
  assert.ok(box && box.w >= 16 && box.h >= 16, "the rendered bitmap has a visible screen-sized box");
  const clip = { x: Math.max(0, Math.floor(box.x)), y: Math.max(0, Math.floor(box.y)),
    width: Math.ceil(box.w), height: Math.ceil(box.h), scale: 1 };
  const screenshot = await browser.call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false, clip });
  const png = Buffer.from(screenshot.data, "base64");
  const filename = "adam-hc-bitmap.png";
  await writeFile(join(output, filename), png);
  report.artifacts[filename] = { mime: "image/png", bytes: png.length };
  const expected = JSON.stringify(sourceBitmap);
  const pixels = await browser.evaluate(`(()=>{const e=document.querySelector(${JSON.stringify(selector)});if(!e)return null;const canvas=e instanceof HTMLCanvasElement?e:e.querySelector("canvas");if(!canvas)return{tagName:e.tagName,canvas:false,html:e.outerHTML.slice(0,1200)};const context=canvas.getContext("2d",{willReadFrequently:true});if(!context)return{tagName:e.tagName,canvas:true,context:false,html:e.outerHTML.slice(0,1200)};const expected=${expected};const data=context.getImageData(0,0,canvas.width,canvas.height).data;const colors=new Map();const sourceColors=new Map();const palette=expected.palette.map(color=>{const hex=color.slice(1);return[0,2,4].map(offset=>Number.parseInt(hex.slice(offset,offset+2),16))});let mismatches=0;for(let i=0;i<expected.pixels.length;i++){const p=i*4,actual=[data[p],data[p+1],data[p+2],data[p+3]],key=actual.join(","),index=Number.parseInt(expected.pixels[i],16),rgb=palette[index],expectedKey=[...rgb,255].join(",");colors.set(key,(colors.get(key)||0)+1);sourceColors.set(index,(sourceColors.get(index)||0)+1);if(key!==expectedKey)mismatches++}const r=e.getBoundingClientRect(),style=getComputedStyle(e);return{tagName:e.tagName,nodeId:e.dataset.packNode,canvas:true,context:true,width:canvas.width,height:canvas.height,expectedWidth:expected.width,expectedHeight:expected.height,box:{x:r.x,y:r.y,width:r.width,height:r.height},style:{display:style.display,visibility:style.visibility,backgroundColor:style.backgroundColor},html:e.outerHTML.slice(0,1200),distinctColors:colors.size,histogram:[...colors].map(([color,count])=>({color,count})),sourceHistogram:[...sourceColors].map(([index,count])=>({index,count})),pixelMismatches:mismatches,total:expected.pixels.length}})()`);
  report.evidence.bitmapCanvas = { node, box, pixels };
  assert.ok(pixels?.canvas && pixels.context, "the rendered bitmap exposes its real canvas pixels");
  assert.ok(pixels.width > 0 && pixels.height > 0, "the rendered bitmap canvas has intrinsic pixels");
  assert.equal(pixels.width, sourceBitmap.width, "the rendered bitmap canvas width matches this file's source");
  assert.equal(pixels.height, sourceBitmap.height, "the rendered bitmap canvas height matches this file's source");
  assert.equal(pixels.pixelMismatches, 0, "the rendered bitmap pixels match this file's exact Source payload");
  return { node, box, pixels, filename };
}

try {
  if (!listenerHost || isIP(listenerHost) !== 4 || listenerHost === "0.0.0.0" || listenerHost.startsWith("127."))
    throw Error("A non-loopback IPv4 --listener-host is required so development-http gives the nearby listener a distinct peer identity");
  report.listenerHost = listenerHost;
  report.primaryHost = "127.0.0.1";
  report.output = output;
  ({ browserSession } = await import(pathToFileURL(join(options.engine, "tools/workspace-ui-browser.mjs")).href));

  activePhase = "debug-pair";
  launcher = spawn(process.execPath, [
    "tools/dev.mjs", "--no-build", "--development-http", "--bind", "0.0.0.0:0",
    "--mode", "free_build", "--map", scene, "--web", join(pack, "target/web"),
    "--audit-dir", join(scratch, "audit"),
  ], { cwd: options.engine, env: { ...process.env, LUNATIC_PACK: pack }, stdio: ["ignore", "pipe", "pipe"] });
  launcher.stdout.on("data", recordService);
  launcher.stderr.on("data", recordService);
  const startupDeadline = Date.now() + 60000;
  while (!serviceText.includes("Development HTTP is enabled. Open:")) {
    if (launcher.exitCode !== null) throw Error(`owned debug pair exited (${launcher.exitCode})`);
    if (Date.now() > startupDeadline) throw Error("owned debug pair startup timed out");
    await delay(100);
  }
  const openUrl = serviceText.match(/Development HTTP is enabled\. Open:\s+(http:\/\/[^\s/]+)/)?.[1];
  assert.ok(openUrl, "the owned debug pair publishes an HTTP gateway");
  const port = new URL(openUrl).port;
  assert.ok(port, "the owned debug pair publishes its ephemeral port");
  const primaryUrl = hostUrl("127.0.0.1", port);
  const listenerUrl = hostUrl(listenerHost, port);
  const listenerSourceAddress = await localSourceAddress(listenerHost, port);
  assert.notEqual(listenerSourceAddress, "127.0.0.1", "the listener route has a peer address distinct from the source browser");
  report.gateway = { primaryUrl, listenerUrl, bind: "0.0.0.0", sourcePeer: "127.0.0.1", listenerPeer: listenerSourceAddress };

  activePhase = "browser-join";
  sourceBrowser = await joinBrowser(primaryUrl);
  listenerBrowser = await joinBrowser(listenerUrl);
  report.evidence.players = {
    sourceCamera: await sourceBrowser.evaluate("({x:window.__camera.cx,y:window.__camera.cy})"),
    listenerCamera: await listenerBrowser.evaluate("({x:window.__camera.cx,y:window.__camera.cy})"),
  };

  activePhase = "open-generated-file";
  const handDomSnapshot = () => sourceBrowser.evaluate(`(() => {
    return ["HAND 1", "HAND 2"].map(label => {
      const labelNode = [...document.querySelectorAll("body *")].find(node =>
        node.textContent.trim().toUpperCase().replace(/\\s+/g, " ") === label);
      return labelNode ? (labelNode.parentElement ?? labelNode).outerHTML : null;
    });
  })()`);
  const handDomBefore = await handDomSnapshot();
  await sourceBrowser.tile(3, 2);
  await delay(300);
  const handDomAfter = await handDomSnapshot();
  report.evidence.pickupHandDom = { before: handDomBefore, after: handDomAfter };
  report.evidence.pickupHandDom.changed = handDomAfter.some((html, index) => html && html !== handDomBefore[index]);
  await writeFile(join(output, "strange-disk-hands.json"), JSON.stringify(report.evidence.pickupHandDom, null, 2));
  const heldScreenshot = await sourceBrowser.call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
  const heldPng = Buffer.from(heldScreenshot.data, "base64");
  await writeFile(join(output, "strange-disk-held.png"), heldPng);
  report.artifacts["strange-disk-held.png"] = { mime: "image/png", bytes: heldPng.length };
  await sourceBrowser.tile(3, 1);
  await sourceBrowser.tile(3, 1);
  const adam = await waitNode(sourceBrowser,
    'e.tagName === "BUTTON" && e.dataset.packNode.endsWith("/open") && e.textContent.trim() === "Adam.HC"',
    "Adam.HC open action");
  await sourceBrowser.click(exact(adam));
  const viewTab = await waitNode(sourceBrowser,
    'e.tagName === "BUTTON" && e.dataset.packNode.endsWith("/editor/mode/view")', "Adam.HC View tab");
  assert.ok(viewTab, "the read-only file exposes its generated View mode");
  const sourceTab = await waitNode(sourceBrowser,
    'e.tagName === "BUTTON" && e.dataset.packNode.endsWith("/editor/mode/edit")', "Adam.HC Source tab");
  await sourceBrowser.click(exact(sourceTab));
  const sourceRecord = await readBitmapSource(sourceBrowser);
  assert.ok(sourceRecord?.body, "the same opened file exposes its read-only Source payload");
  const sourceBitmap = bitmapFromSource(sourceRecord.body);
  report.evidence.sourcePayload = {
    node: sourceRecord.node,
    width: sourceBitmap.width,
    height: sourceBitmap.height,
    palette: sourceBitmap.palette,
    pixels: sourceBitmap.pixels,
    pixelCount: sourceBitmap.pixels.length,
  };
  await sourceBrowser.click(exact(viewTab));
  const picture = await waitNode(sourceBrowser,
    'e.dataset.packNode.endsWith("/reader/content/picture")', "Adam.HC bitmap reader");
  await delay(200);
  report.evidence.bitmap = await captureBitmap(sourceBrowser, picture, sourceBitmap);

  activePhase = "active-audio";
  const [sourceAudio, listenerAudio] = await Promise.all([
    observeAudio(sourceBrowser, "Adam.HC source player"),
    observeAudio(listenerBrowser, "nearby listener"),
  ]);
  report.evidence.audio = { source: sourceAudio, listener: listenerAudio };
  recordCheck("source-audio-active", sourceAudio.status, sourceAudio);
  recordCheck("nearby-listener-audio", listenerAudio.status, listenerAudio);
  for (const [browser, filename, result, checkName] of [
    [sourceBrowser, "adam-hc-source-audio.webm", sourceAudio, "source-audio-artifact"],
    [listenerBrowser, "adam-hc-nearby-listener.webm", listenerAudio, "listener-audio-artifact"],
  ]) {
    if (result.status !== "passed") {
      recordCheck(checkName, "blocked", "no active audio signal to record");
      continue;
    }
    try {
      report.artifacts[filename] = await saveAudioArtifact(browser, filename);
      recordCheck(checkName, "passed", report.artifacts[filename]);
    } catch (error) {
      recordCheck(checkName, "failed", String(error));
    }
  }

  activePhase = "hidden-lease";
  const beforeHidden = await audioSnapshot(sourceBrowser);
  const leasePrecondition = beforeHidden?.audible === true;
  const listenerBeforeHidden = await audioSnapshot(listenerBrowser);
  const listenerLeasePrecondition = listenerBeforeHidden?.audible === true;
  const visibilityCursor = beforeHidden?.visibilityEvents?.at(-1)?.sequence ?? -1;
  report.evidence.visibility = { sourceBeforeHidden: beforeHidden, listenerBeforeHidden };
  const backgroundTab = await sourceBrowser.createTab();
  await sourceBrowser.activateTab(backgroundTab);
  await sourceBrowser.waitFor("document.hidden === true");
  report.evidence.visibility.backgroundTab = backgroundTab;
  const hiddenProtocol = await observeVisibilityFrame(sourceBrowser, true, visibilityCursor);
  recordCheck("hidden-visibilitychange-sends-frame", hiddenProtocol.status, hiddenProtocol);
  let hiddenAudio = null, hiddenStopped = false, silenceProven = false;
  if (leasePrecondition) {
    try {
      hiddenAudio = await waitForSilence(sourceBrowser, "hidden document audio lease");
      silenceProven = true;
    } catch (error) {
      hiddenAudio = { error: String(error) };
    }
  }
  const contextContinued = hiddenAudio?.taps?.some(tap => tap.context === "running") ?? false;
  hiddenStopped = hiddenProtocol.status === "passed" && contextContinued && silenceProven;
  recordCheck("hidden-stops-source-audio", hiddenStopped ? "passed" : leasePrecondition ? "failed" : "blocked",
    { audio: hiddenAudio, contextContinued, protocol: hiddenProtocol.status });
  let hiddenListener = null, listenerSilenceProven = false;
  if (listenerLeasePrecondition) {
    try {
      hiddenListener = await waitForSilence(listenerBrowser, "nearby listener after source document hides");
      listenerSilenceProven = true;
    } catch (error) {
      hiddenListener = { error: String(error) };
    }
  }
  const listenerStopped = hiddenProtocol.status === "passed" && listenerSilenceProven;
  recordCheck("hidden-stops-nearby-listener-audio", listenerStopped ? "passed" : listenerLeasePrecondition ? "failed" : "blocked",
    { audio: hiddenListener, protocol: hiddenProtocol.status });
  report.evidence.visibility.hidden = { sourceAfterHidden: hiddenAudio, listenerAfterHidden: hiddenListener };
  const visibleCursor = hiddenProtocol.event?.sequence ?? visibilityCursor;
  await sourceBrowser.activateTab(sourceBrowser.targetId);
  await sourceBrowser.waitFor("document.hidden === false");
  await sourceBrowser.closeTab(backgroundTab);
  const visibleProtocol = await observeVisibilityFrame(sourceBrowser, false, visibleCursor);
  recordCheck("visible-visibilitychange-sends-frame", visibleProtocol.status, visibleProtocol);
  report.evidence.visibility.visible = true;
  if (hiddenStopped) {
    try {
      const resumedAudio = await waitForAudio(sourceBrowser, "visible document audio lease resumed", 2, 8000);
      report.evidence.visibility.sourceAfterResume = resumedAudio;
      recordCheck("visible-resumes-source-audio", visibleProtocol.status === "passed" ? "passed" : "failed",
        { audio: resumedAudio, protocol: visibleProtocol.status });
    } catch (error) {
      recordCheck("visible-resumes-source-audio", "failed", String(error));
    }
  } else recordCheck("visible-resumes-source-audio", "blocked", "source audio was not proven stopped while hidden");
  if (listenerStopped) {
    try {
      const resumedListener = await waitForAudio(listenerBrowser, "visible resumes nearby listener audio", 2, 8000);
      report.evidence.visibility.listenerAfterResume = resumedListener;
      recordCheck("visible-resumes-nearby-listener-audio", visibleProtocol.status === "passed" ? "passed" : "failed",
        { audio: resumedListener, protocol: visibleProtocol.status });
    } catch (error) {
      recordCheck("visible-resumes-nearby-listener-audio", "failed", String(error));
    }
  } else recordCheck("visible-resumes-nearby-listener-audio", "blocked",
    "nearby listener silence was not proven while the source document was hidden");

  activePhase = "browser-errors";
  for (const [name, browser] of [["source", sourceBrowser], ["listener", listenerBrowser]]) {
    const unexpected = browser.errors.filter(error => !error.startsWith("AbortError: The play() request was interrupted by a call to pause()."));
    recordCheck(`${name}-browser-errors`, unexpected.length === 0 ? "passed" : "failed", unexpected);
  }
  report.status = report.checks.every(check => check.status === "passed") ? "passed" : "failed";
  report.completedAt = new Date().toISOString();
} catch (error) {
  report.status = "failed";
  report.failure = { phase: activePhase, message: String(error) };
  const screenshotBrowser = sourceBrowser ?? listenerBrowser;
  if (screenshotBrowser) {
    await screenshotBrowser.call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false })
      .then(result => writeFile(join(output, "failure.png"), Buffer.from(result.data, "base64"))).catch(() => {});
    await screenshotBrowser.evaluate("document.body.innerText").then(text =>
      writeFile(join(output, "failure-dom.txt"), String(text).slice(-12000))).catch(() => {});
  }
  await writeFile(join(output, "failure-service.log"), serviceText).catch(() => {});
} finally {
  for (const browser of [sourceBrowser, listenerBrowser]) await browser?.close().catch(() => {});
  await stopLauncher();
  report.finishedAt = new Date().toISOString();
  await writeFile(join(output, "results.json"), JSON.stringify(report, null, 2)).catch(() => {});
  await rm(scratch, { recursive: true, force: true }).catch(() => {});
}

console.log(`${report.status}: ${output}`);
if (report.status !== "passed") process.exitCode = 1;
