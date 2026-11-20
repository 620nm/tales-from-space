// The engine seams every pack UI test shares: esbuild from the engine's
// web install, guests in the engine's own guest host (`xtask spec-ui
// --raw`, one process per package), the layout lint built from the
// engine's source, and the helpers that read one render. The engine
// checkout is argv[2] or LUNATIC_ENGINE, resolved as tools/test.mjs does.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { createInterface } from "node:readline";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const packRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
export const engineRoot = resolve(
  process.argv[2] ?? process.env.LUNATIC_ENGINE ?? join(packRoot, "..", "lunatic"),
);
export const sdkEntry = join(engineRoot, "web/sdk/index.ts");
export const uiVersion = JSON.parse(await readFile(join(engineRoot, "idl/ui-v1.json"), "utf8")).version;

const { build } = await import(
  pathToFileURL(join(engineRoot, "web/node_modules/esbuild/lib/main.js")).href
);
export { build };

/** An engine module, by its path inside the engine checkout. */
export const engineModule = (relative) =>
  import(pathToFileURL(join(engineRoot, relative)).href);

/** Load a TypeScript engine module in the Node harness. */
async function importEngineTypeScript(relative) {
  const built = await build({
    entryPoints: [join(engineRoot, relative)],
    bundle: true,
    format: "esm",
    platform: "node",
    write: false,
  });
  return import(`data:text/javascript;base64,${Buffer.from(built.outputFiles[0].contents).toString("base64")}`);
}

/** One pack UI source compiled against the engine SDK, as the host builds it. */
export async function compilePackModule(entry) {
  const result = await build({
    entryPoints: [join(packRoot, entry)],
    alias: { "@lunatic/ui": sdkEntry },
    bundle: true,
    format: "esm",
    platform: "neutral",
    write: false,
  });
  return result.outputFiles[0].text;
}

/** The manifest names the declarations, as the production package build does. */
const uiManifest = JSON.parse(await readFile(join(packRoot, "ui/manifest.json"), "utf8"));
let packMotions;
if (uiManifest.motions !== undefined) {
  const motionsSource = await compilePackModule(join("ui", uiManifest.motions));
  ({ default: packMotions } = await import(
    `data:text/javascript;base64,${Buffer.from(motionsSource).toString("base64")}`
  ));
}

/** The guest package the runtime accepts, around one compiled module. */
export const guestPackage = (source) => ({
  version: uiVersion,
  id: "test",
  slot: "hud",
  entry: "main.js",
  modules: { "main.js": source },
  ...(packMotions === undefined ? {} : { motions: packMotions }),
});

/** The engine's guest host binary, from the debug build the pack gate's
 *  `build` lane makes in the engine's own `target/`. */
const xtaskBinary = join(
  engineRoot,
  "target/debug",
  process.platform === "win32" ? "xtask.exe" : "xtask",
);

/** Every guest process still running, killed if this test exits early. */
const live = new Set();
process.on("exit", () => {
  for (const child of live) child.kill("SIGKILL");
});

/** A guest error line as an Error; `.fault` names a guest fault's kind. */
function guestError(line) {
  const error = Error(line.error);
  if (line.fault !== undefined) error.fault = line.fault;
  return error;
}

let englishLocale;

/** Feed the engine's viewer catalog loader the same English sources as the client. */
export async function loadEnglishLocale() {
  const [{ loadCatalogChain }, engine, pack] = await Promise.all([
    importEngineTypeScript("web/src/i18n.ts"),
    readFile(join(engineRoot, "crates/lunatic-core/locale/en.json"), "base64"),
    readFile(join(packRoot, "locale/en.json"), "base64"),
  ]);
  const catalog = await loadCatalogChain("en",
    () => `data:application/json;base64,${engine}`,
    () => `data:application/json;base64,${pack}`,
  );
  return { tag: "en", catalog };
}

/** One guest package in the engine's guest host (`xtask spec-ui --raw`,
 *  the engine's docs/pack-ui/authoring.md, "Testing a panel outside a
 *  round"). The default locale is English. An explicit `{tag, catalog}` selects
 *  a fixture locale and `null` starts a guest without one. Every call is one
 *  round trip; a refused or fatal line rejects. Call `dispose()` always. */
export async function createGuest(pkg, { locale } = {}) {
  if (!existsSync(xtaskBinary))
    throw Error(
      `${xtaskBinary} is missing: build it with \`cargo build -p xtask\` in ${engineRoot} ` +
        "(the pack gate's `build` lane, `sh tools/check.sh build`)",
    );
  if (locale === undefined) locale = await (englishLocale ??= loadEnglishLocale());
  const child = spawn(xtaskBinary, ["spec-ui", "--raw"], { stdio: ["pipe", "pipe", "pipe"] });
  live.add(child);
  const waiting = [];
  let stderr = "";
  let ended = null;
  // Whether a caller already saw this guest fail, so `dispose` adds nothing.
  let reported = false;
  let stopped = false;
  const end = (reason) => {
    ended ??= reason;
    live.delete(child);
    for (const turn of waiting.splice(0)) {
      reported = true;
      turn.reject(Error(`${ended}${stderr ? `\n${stderr}` : ""}`));
    }
  };
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => {
    stderr = (stderr + chunk).slice(-8192);
  });
  child.stdin.on("error", () => {});
  child.on("error", (error) => end(`guest host did not run: ${error.message}`));
  // `close` follows the last stdout line, so a fatal line reaches its turn first.
  let clean = false;
  child.on("close", (code, signal) => {
    clean = stopped && code === 0;
    end(`guest host exited (${signal ?? code})`);
  });
  createInterface({ input: child.stdout }).on("line", (text) => {
    const turn = waiting.shift();
    if (!turn) return end(`guest host wrote an unasked line: ${text}`);
    let line;
    try {
      line = JSON.parse(text);
    } catch {
      return turn.reject(Error(`guest host wrote a line that is not JSON: ${text}`));
    }
    if (typeof line?.error === "string") {
      reported = true;
      turn.reject(guestError(line));
    } else turn.resolve(line);
  });
  const ask = (request) =>
    new Promise((resolve, reject) => {
      if (ended) return reject(Error(ended));
      waiting.push({ resolve, reject });
      child.stdin.write(`${JSON.stringify(request)}\n`);
    });
  const disposed = new Promise((resolve) => child.once("close", resolve));
  /** Stops the guest. Exit 0 after `stop` is clean; any other end no
   *  caller has seen yet (a nonzero exit, no exit within 5 s) rejects. */
  const dispose = async () => {
    if (!ended && child.stdin.writable) {
      stopped = true;
      child.stdin.write(`${JSON.stringify({ kind: "stop" })}\n`);
      child.stdin.end();
    }
    const timer = setTimeout(() => child.kill("SIGKILL"), 5000);
    await disposed;
    clearTimeout(timer);
    if (!clean && !reported) {
      reported = true;
      throw Error(`${ended}${stopped ? " after stop" : ""}${stderr ? `\n${stderr}` : ""}`);
    }
  };
  try {
    await ask({ kind: "start", package: pkg, ...(locale ? { locale } : {}) });
  } catch (error) {
    await dispose();
    throw error;
  }
  return {
    /** `onView(view)` then `render(view)`: both answers. */
    update: (view) => ask({ kind: "update", view }),
    /** `onView(view)` then the admitted render tree. */
    render: async (view) => (await ask({ kind: "update", view })).tree,
    /** `onEvent(event, view)`'s reply; it needs one earlier update. */
    event: async (event, view) => (await ask({ kind: "event", event, view })).reply,
    dispose,
  };
}

let lint;
/** The engine's `web/src/pack-ui/lint.ts`, built once per process. */
export function lintModule() {
  return (lint ??= importEngineTypeScript("web/src/pack-ui/lint.ts"));
}

/** A built bundle, or null when `xtask build-ui` has not written it. */
export async function readBundle(relative) {
  try {
    return JSON.parse(await readFile(join(packRoot, relative), "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
    return null;
  }
}

/** Every id in the tree, in order, so a repeat is nameable. */
export function ids(node, out = []) {
  if (!node || typeof node !== "object") return out;
  if (typeof node.id === "string") out.push(node.id);
  for (const child of node.children ?? []) ids(child, out);
  return out;
}

export function assertUniqueIds(tree, where) {
  const seen = ids(tree);
  assert.deepEqual(seen.filter((id, at) => seen.indexOf(id) !== at), [], `${where}: no id is used twice`);
  return seen;
}

/** A render against its package's rules: every finding named, none allowed. */
export function assertLintClean(lintTree, tree, bundle, where) {
  const findings = lintTree(tree, bundle.styles ?? [], bundle.fonts ?? []).map((f) => `${f.rule} ${f.node ?? f.class ?? ""}: ${f.message}`);
  assert.deepEqual(findings, [], `${where}: the layout lint is clean`);
}

/** The node carrying an id, anywhere in the tree. */
export const find = (node, id) =>
  node?.id === id
    ? node
    : (node?.children ?? []).map((child) => find(child, id)).find(Boolean);

/** A skip the runner reports: tools/test.mjs harvests these lines. */
export const reportSkip = (reason) => console.log(`SKIP ${reason}`);
