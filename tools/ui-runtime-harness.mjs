// The engine seams every pack UI test shares: esbuild from the engine's
// web install, the pinned QuickJS guest runtime and layout lint built from
// the engine's own source, and the helpers that read one render. The engine
// checkout is argv[2] or LUNATIC_ENGINE, resolved as tools/test.mjs does.
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const packRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
export const engineRoot = resolve(
  process.argv[2] ?? process.env.LUNATIC_ENGINE ?? join(packRoot, "..", "lunatic"),
);
export const sdkEntry = join(engineRoot, "web/sdk/index.ts");

const { build } = await import(
  pathToFileURL(join(engineRoot, "web/node_modules/esbuild/lib/main.js")).href
);
export { build };

/** An engine module, by its path inside the engine checkout. */
export const engineModule = (relative) =>
  import(pathToFileURL(join(engineRoot, relative)).href);

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

/** The guest package the runtime accepts, around one compiled module. */
export const guestPackage = (source) => ({
  version: 6,
  id: "test",
  slot: "hud",
  entry: "main.js",
  modules: { "main.js": source },
});

/** The interpreter the engine pins; a bundled runtime cannot find it itself. */
const wasmLocation = join(
  engineRoot,
  "web/node_modules/@jitl/quickjs-wasmfile-release-sync/dist/emscripten-module.wasm",
);

let runtime;
/** The engine's QuickJS host, built once per process from its source. */
function guestRuntime() {
  return (runtime ??= (async () => {
    const bundle = await build({
      entryPoints: [join(engineRoot, "web/src/pack-ui/runtime.ts")],
      bundle: true,
      format: "esm",
      platform: "node",
      packages: "bundle",
      write: false,
    });
    const scratch = process.env.LUNATIC_TEST_TMP ?? tmpdir();
    await mkdir(scratch, { recursive: true });
    const dir = await mkdtemp(join(scratch, "pack-ui-runtime-"));
    const file = join(dir, "runtime-test.mjs");
    await writeFile(file, bundle.outputFiles[0].text);
    try {
      return (await import(pathToFileURL(file).href)).GuestRuntime;
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  })());
}

/** One guest package running in that host, on the pinned interpreter. */
export async function createGuest(pkg) {
  return (await guestRuntime()).create(pkg, wasmLocation);
}

let lint;
/** The engine's `web/src/pack-ui/lint.ts`, built once per process. */
export function lintModule() {
  return (lint ??= (async () => {
    const built = await build({
      entryPoints: [join(engineRoot, "web/src/pack-ui/lint.ts")],
      bundle: true,
      format: "esm",
      platform: "node",
      write: false,
    });
    const source = Buffer.from(built.outputFiles[0].text).toString("base64");
    return import(`data:text/javascript;base64,${source}`);
  })());
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
