// Export the local concept gallery using an already-baked engine atlas.
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const options = new Map();
for (let index = 0; index < args.length; index += 2) {
  const flag = args[index];
  const value = args[index + 1];
  if (!["--engine", "--output"].includes(flag) || !value || options.has(flag)) {
    throw new Error("Usage: node build.mjs --engine /path/to/lunatic --output /tmp/concepts.html");
  }
  options.set(flag, value);
}
if (!options.has("--engine") || !options.has("--output")) {
  throw new Error("Both --engine and --output are required; no repository paths are inferred.");
}
const assets = join(resolve(options.get("--engine")), "web/assets");
const atlasText = await readFile(join(assets, "atlas.ron"), "utf8");
const delivery = await readFile(join(assets, "delivery.ron"), "utf8");
const number = (name) => {
  const value = Number(atlasText.match(new RegExp(`\\b${name}: (\\d+)`))?.[1]);
  if (!Number.isSafeInteger(value) || value < 0) throw new Error(`Missing atlas field: ${name}`);
  return value;
};
const atlas = Object.fromEntries(["tile", "columns", "rows_per_page", "pad", "cells"].map(name => [name, number(name)]));
atlas.sprites = Object.fromEntries([...atlasText.slice(atlasText.indexOf("sprites:"), atlasText.indexOf("\n    ],", atlasText.indexOf("sprites:"))).matchAll(/\("([^"]+)", (\d+)\)/g)].map(match => [match[1], Number(match[2])]));
const atlasDelivery = delivery.match(/\batlas:\s*\[([\s\S]*?)\],/)?.[1];
if (!atlasDelivery) throw new Error("No baked atlas delivery entries found.");
const hashes = [...atlasDelivery.matchAll(/sha256:\s*"([a-f0-9]{64})"/g)].map(match => match[1]);
const expectedPages = Math.ceil(atlas.cells / (atlas.columns * atlas.rows_per_page));
if (hashes.length !== expectedPages || !atlas.sprites.floor) throw new Error("Atlas metadata is incomplete.");
atlas.pages = await Promise.all(hashes.map(async hash => `data:image/png;base64,${(await readFile(join(assets, "obj", `${hash}.png`))).toString("base64")}`));
const names = ["index.html", "concepts.css", "surfaces.css", "actions.css", "scene.js", "surfaces.js", "actions.js", "concepts.js"];
const [template, styles, surfaceStyles, actionStyles, scene, surfaces, actions, concepts] = await Promise.all(names.map(name => readFile(join(here, name), "utf8")));
const replacements = { STYLES: [styles, surfaceStyles, actionStyles].join("\n"),
  ATLAS: `window.conceptAtlas = ${JSON.stringify(atlas).replaceAll("<", "\\u003c")};`,
  SCENE: scene, SURFACES: surfaces, ACTIONS: actions, CONCEPTS: concepts };
const html = template.replace(/\{\{(STYLES|ATLAS|SCENE|SURFACES|ACTIONS|CONCEPTS)\}\}/g, (_, key) => replacements[key]);
const output = resolve(options.get("--output"));
await mkdir(dirname(output), { recursive: true });
await writeFile(output, html, { flag: "wx" });
console.log(`Exported ${output} (${Buffer.byteLength(html)} bytes; ${hashes.length} atlas page).`);
