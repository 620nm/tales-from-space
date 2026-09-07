// Sandboxed Chrome capture, with trusted input over its private loopback CDP endpoint.
import { spawn } from 'node:child_process';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { checkConcept } from './checks.mjs';

const directory = dirname(fileURLToPath(import.meta.url));
const profile = await mkdtemp(join(tmpdir(), 'tfs-terminal-browser-'));
const output = process.argv[2] ?? await mkdtemp(join(tmpdir(), 'tfs-terminal-captures-'));
await mkdir(output, { recursive: true });
const browser = spawn('google-chrome-stable', [
  '--headless=new', '--disable-dev-shm-usage', '--no-first-run',
  '--no-default-browser-check', '--disable-background-networking', '--no-proxy-server',
  '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0',
  `--user-data-dir=${profile}`, 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });
let socket;
let sequence = 0;
const pending = new Map();
const errors = [];
const contexts = new Map();
function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`DevTools timeout: ${method}`));
    }, 15000);
    pending.set(id, { resolve, reject, timer });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression) {
  const result = await call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
  return result.result.value;
}
const settle = () => evaluate('new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))');
async function rect(selector) {
  return evaluate(`(() => { const node = document.querySelector(${JSON.stringify(selector)}); if (!node) throw new Error('Missing selector: ' + ${JSON.stringify(selector)}); const r = node.getBoundingClientRect(); return {x:r.x,y:r.y,width:r.width,height:r.height}; })()`);
}
async function click(selector) {
  const r = await rect(selector);
  if (!r.width || !r.height) throw new Error(`Hidden target: ${selector}`);
  const x = r.x + r.width / 2, y = r.y + r.height / 2;
  await call('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await call('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  await settle();
}
async function drag(selector, dx, dy) {
  const r = await rect(selector), x = r.x + r.width / 2, y = r.y + r.height / 2;
  await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await call('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  for (let i = 1; i <= 8; i++) await call('Input.dispatchMouseEvent', {
    type: 'mouseMoved', x: x + dx * i / 8, y: y + dy * i / 8, button: 'left', buttons: 1,
  });
  await call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x + dx, y: y + dy, button: 'left', clickCount: 1 });
  await settle();
}
async function screenshot(name) {
  await evaluate('Promise.all([...document.images].map(image => image.decode()))');
  await settle();
  const shot = await call('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  await writeFile(join(output, `${name}.png`), Buffer.from(shot.data, 'base64'));
  console.log(`Captured ${name}`);
}
try {
  const endpoint = await new Promise((resolve, reject) => {
    let log = '';
    const timer = setTimeout(() => reject(new Error(`Browser timeout: ${log.slice(-1500)}`)), 15000);
    browser.once('error', error => { clearTimeout(timer); reject(error); });
    browser.once('exit', code => { clearTimeout(timer); reject(new Error(`Browser exited: ${code}; ${log.slice(-1500)}`)); });
    browser.stderr.on('data', chunk => {
      log = (log + chunk).slice(-6000);
      const match = log.match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (match) { clearTimeout(timer); resolve(match[1]); }
    });
  });
  const response = await fetch(`http://${new URL(endpoint).host}/json/new?about:blank`, { method: 'PUT' });
  if (!response.ok) throw new Error(`Cannot open capture tab: ${response.status}`);
  const target = await response.json();
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.method === 'Runtime.executionContextCreated') contexts.set(message.params.context.id, message.params.context);
    if (message.method === 'Runtime.executionContextDestroyed') contexts.delete(message.params.executionContextId);
    if (message.method === 'Runtime.executionContextsCleared') contexts.clear();
    if (message.method === 'Runtime.exceptionThrown') {
      const detail = message.params.exceptionDetails;
      errors.push(detail.exception?.description ?? detail.text);
    }
    if (message.method === 'Runtime.consoleAPICalled' && ['error', 'assert'].includes(message.params.type)) {
      errors.push(message.params.args.map(arg => arg.value ?? arg.description).join(' '));
    }
    const job = pending.get(message.id);
    if (!job) return;
    clearTimeout(job.timer);
    pending.delete(message.id);
    if (message.error) job.reject(new Error(message.error.message));
    else job.resolve(message.result);
  });
  await call('Page.enable');
  await call('Runtime.enable');
  await call('Emulation.setDeviceMetricsOverride', { width: 1600, height: 1000, deviceScaleFactor: 1, mobile: false });
  await call('Page.navigate', { url: pathToFileURL(join(directory, 'index.html')).href });
  for (let i = 0; i < 100; i++) {
    if (await evaluate('document.readyState === "complete" && !!window.TerminalConcept')) break;
    await new Promise(resolve => setTimeout(resolve, 50));
    if (i === 99) throw new Error('Concept did not initialize');
  }
  for (const context of contexts.values()) {
    if (!context.auxData?.isDefault) continue;
    const ready = await call('Runtime.evaluate', {
      contextId: context.id,
      expression: 'Promise.all([window.ConceptScene?.ready, window.ConceptSlotSkin?.ready])',
      awaitPromise: true, returnByValue: true,
    });
    if (ready.exceptionDetails) throw new Error('Backdrop image readiness failed');
  }
  await settle();
  await checkConcept({ call, evaluate, rect, click, drag, screenshot, settle });
  await call('Emulation.setDeviceMetricsOverride', { width: 1600, height: 1000, deviceScaleFactor: 1, mobile: false });
  await call('Page.navigate', { url: pathToFileURL(join(directory, 'sprites.html')).href });
  for (let i = 0; i < 100; i++) {
    if (await evaluate('document.readyState === "complete" && !!document.querySelector(".cell .large")')) break;
    await new Promise(resolve => setTimeout(resolve, 50));
    if (i === 99) throw new Error('Sprite family page did not load');
  }
  await evaluate('Promise.all([...document.images].map(image => image.decode()))');
  const familyValid = await evaluate(`[...document.images].every(image => {
    const style = getComputedStyle(image), size = image.classList.contains('large') ? '128px' : '32px';
    return image.naturalWidth === 32 && image.naturalHeight === 32 && style.width === size && style.height === size && style.imageRendering === 'pixelated';
  }) && document.querySelectorAll('.cell .large').length === 5`);
  if (!familyValid) throw new Error('Sprite family must contain five 32px PNG assets with 4× pixelated previews');
  const familyNames = await evaluate(`[...new Set([...document.images].map(image => image.getAttribute('src').split('/').pop()))].sort().join(',')`);
  if (familyNames !== 'computer.png,file-atmo.png,file-disl.png,file-md.png,file-pem.png') throw new Error('Sprite family contains an unexpected asset');
  await screenshot('sprite-family');
  if (errors.length) throw new Error(`Browser errors: ${errors.join('; ')}`);
  console.log('PASS: interaction checks, viewport bounds, no console errors');
} finally {
  for (const job of pending.values()) clearTimeout(job.timer);
  socket?.close();
  const stopped = browser.exitCode !== null || browser.signalCode !== null
    ? Promise.resolve() : new Promise(resolve => browser.once('exit', resolve));
  browser.kill('SIGTERM');
  await stopped;
  await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
}
