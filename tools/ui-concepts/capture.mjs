// Capture the standalone concepts through a local Chromium DevTools connection.
import { spawn } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { checkConcept } from "./checks.mjs";

const args = process.argv.slice(2);
const options = new Map();
for (let index = 0; index < args.length; index += 2) {
  const flag = args[index];
  const value = args[index + 1];
  if (!["--input", "--output", "--browser", "--width", "--height", "--check"].includes(flag) || !value || options.has(flag)) {
    throw new Error("Usage: node capture.mjs --input /tmp/concepts.html --output /tmp/shots [--browser /path/to/chrome] [--width 1600 --height 1000] [--check true]");
  }
  options.set(flag, value);
}
if (!options.has("--input") || !options.has("--output")) throw new Error("--input and --output are required.");
if (options.has("--check") && options.get("--check") !== "true") throw new Error("--check accepts true only.");
const width = Number(options.get("--width") ?? 1600);
const height = Number(options.get("--height") ?? 1000);
if (![width, height].every(value => Number.isSafeInteger(value) && value >= 600 && value <= 4096)) {
  throw new Error("Capture dimensions must be integers between 600 and 4096.");
}
const profile = await mkdtemp(join(tmpdir(), "tfs-concept-browser-"));
const directory = resolve(options.get("--output"));
await mkdir(directory, { recursive: true });
const browser = spawn(options.get("--browser") ?? "google-chrome-stable", [
  "--headless=new", "--no-sandbox", "--disable-dev-shm-usage", "--no-first-run",
  "--no-default-browser-check", "--disable-background-networking", "--no-proxy-server",
  "--remote-debugging-address=127.0.0.1", "--remote-debugging-port=0",
  `--user-data-dir=${profile}`, "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });
let socket;
let sequence = 0;
const pending = new Map();
const errors = [];
function call(method, params = {}) {
  return new Promise((resolveCall, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`DevTools timed out: ${method}`));
    }, 15000);
    pending.set(id, { resolve: resolveCall, reject, timer });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
try {
  const endpoint = await new Promise((resolveEndpoint, reject) => {
    let log = "";
    const timer = setTimeout(() => reject(new Error(`Browser startup timeout: ${log.slice(-1500)}`)), 15000);
    browser.once("error", error => { clearTimeout(timer); reject(error); });
    browser.once("exit", code => { clearTimeout(timer); reject(new Error(`Browser exited: ${code}`)); });
    browser.stderr.on("data", chunk => {
      log = (log + chunk.toString()).slice(-6000);
      const match = log.match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (match) { clearTimeout(timer); resolveEndpoint(match[1]); }
    });
  });
  const response = await fetch(`http://${new URL(endpoint).host}/json/new?about:blank`, { method: "PUT" });
  if (!response.ok) throw new Error(`Cannot open capture tab: ${response.status}`);
  const target = await response.json();
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolveSocket, reject) => {
    socket.addEventListener("open", resolveSocket, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  socket.addEventListener("message", event => {
    const message = JSON.parse(event.data);
    if (message.method === "Runtime.exceptionThrown") {
      const details = message.params.exceptionDetails;
      errors.push(details.exception?.description ?? details.text);
    }
    const job = pending.get(message.id);
    if (!job) return;
    clearTimeout(job.timer);
    pending.delete(message.id);
    if (message.error) job.reject(new Error(message.error.message));
    else job.resolve(message.result);
  });
  await call("Page.enable");
  await call("Runtime.enable");
  await call("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile: false });
  for (const role of ["crew", "cyborg", "ai"]) {
    const url = pathToFileURL(resolve(options.get("--input")));
    url.searchParams.set("role", role);
    const loaded = new Promise(resolveLoad => {
      const listener = event => {
        if (JSON.parse(event.data).method !== "Page.loadEventFired") return;
        socket.removeEventListener("message", listener);
        resolveLoad();
      };
      socket.addEventListener("message", listener);
    });
    await call("Page.navigate", { url: url.href });
    let loadTimer;
    try {
      await Promise.race([loaded, new Promise((_, reject) => {
        loadTimer = setTimeout(() => reject(new Error("Page load timeout")), 10000);
      })]);
    } finally { clearTimeout(loadTimer); }
    const ready = await call("Runtime.evaluate", {
      expression: "Promise.all([ConceptScene.ready, ConceptSlotSkin.ready]).then(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))",
      awaitPromise: true, returnByValue: true,
    });
    if (ready.exceptionDetails) throw new Error(`Concept failed: ${ready.exceptionDetails.exception?.description ?? ready.exceptionDetails.text}; ${errors.join("; ")}`);
    const screenshot = async name => {
      const shot = await call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
      await writeFile(join(directory, `${name}.png`), Buffer.from(shot.data, "base64"), { flag: "wx" });
    };
    await screenshot(role);
    console.log(`Captured ${role}: ${width}×${height}`);
    if (options.has("--check")) await checkConcept(call, role, screenshot);
  }
  if (errors.length) throw new Error(`Browser exceptions: ${errors.join("; ")}`);
} finally {
  for (const job of pending.values()) clearTimeout(job.timer);
  socket?.close();
  const stopped = browser.exitCode !== null || browser.signalCode !== null
    ? Promise.resolve() : new Promise(resolveExit => browser.once("exit", resolveExit));
  browser.kill("SIGTERM");
  await stopped;
  await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
}
