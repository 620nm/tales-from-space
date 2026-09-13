import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const pack = fileURLToPath(new URL("..", import.meta.url));
const engine = resolve(process.argv[2] || process.env.LUNATIC_ENGINE || resolve(pack, "../lunatic"));
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: { contents: "export { default as ui } from './main';", resolveDir: resolve(pack, "ui"), loader: "tsx" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(resolve(pack, "locale/en.json"), "utf8")) };
const { ui } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
const fixture = async (name) => JSON.parse(await readFile(resolve(pack, `ui/fixtures/${name}.json`))).view;
const tree = (name) => flatten(ui.render(name));

const paper = tree(await fixture("document-paper"));
const committedRuns = paper.find((node) => node.id === "doc/1/1/paper/committed/part/0").runs;
assert.equal(committedRuns[1].color, "#bb2222");
assert.equal(committedRuns.map((run) => run.text).join(""), "Meet at the airlock. Bring the red key.");
assert.equal(paper.find((node) => node.id === "doc/1/1/paper/draft").type, "textarea");
const paperView = await fixture("document-paper");
tree(paperView);
const paperAction = ui.onEvent({ id: "doc/1/1/paper/draft", type: "change", value: "draft" }, paperView).action;
assert.equal(paperAction.act, "write");
assert.deepEqual(paperAction.payload, { value: "draft" });
const denseView = await fixture("document-paper");
const dense = "**x**".repeat(700);
denseView.documents["1"].state.data.draft = dense;
assert.equal(tree(denseView).find((node) => node.id === "doc/1/1/paper/draft").value, dense.slice(0, 4096));
const unicodeView = await fixture("document-paper");
const unicode = "😀".repeat(1024);
unicodeView.documents["1"].state.data.draft = unicode;
assert.equal(new TextEncoder().encode(tree(unicodeView).find((node) => node.id === "doc/1/1/paper/draft").value).length, 4096);
const splitView = await fixture("document-paper");
splitView.documents["1"].state.data.committed = [
  { text: "**left", style: { color: "#111111", weight: 400 } },
  { text: "right**", style: { color: "#222222", weight: 400 } },
];
const splitRuns = tree(splitView).find((node) => node.id === "doc/1/1/paper/committed/part/0").runs;
assert.equal(splitRuns.map((run) => run.text).join(""), "**leftright**");
assert.equal(splitRuns[0].fontWeight, 400);
const markdownView = await fixture("document-paper");
markdownView.documents["1"].state.data.committed = [{ text: "**marked**", style: { color: "#333333" } }];
const markdownRun = tree(markdownView).find((node) => node.id === "doc/1/1/paper/committed/part/0").runs[0];
assert.equal(markdownRun.text, "marked");
assert.equal(markdownRun.fontWeight, 700);
const italicView = await fixture("document-paper");
italicView.documents["1"].state.data.committed = [{ text: "*italic*" }];
const italicRun = tree(italicView).find((node) => node.id === "doc/1/1/paper/committed/part/0").runs[0];
assert.equal(italicRun.text, "italic");
assert.equal(italicRun.fontStyle, "italic");
const nativeMarkdownView = await fixture("document-paper");
nativeMarkdownView.documents["1"].state.data.committed = [
  { text: "**red**", style: { color: "#bb2222", font_family: "patrick-hand" } },
  { text: "**blue**", style: { color: "#2222bb", font_family: "kalam-bold" } },
  { text: "*open", style: { color: "#111111" } },
  { text: "close*", style: { color: "#111111" } },
];
const nativeRuns = tree(nativeMarkdownView).find((node) => node.id === "doc/1/1/paper/committed/part/0").runs;
assert.deepEqual(nativeRuns.map((run) => run.text), ["red", "blue", "*open", "close*"]);
assert.equal(nativeRuns[0].fontWeight, 700);
assert.equal(nativeRuns[1].fontWeight, 700);
assert.equal(nativeRuns[0].color, "#bb2222");
assert.equal(nativeRuns[1].color, "#2222bb");
const fullView = await fixture("document-paper");
const full = "z".repeat(8192);
fullView.documents["1"].state.data.committed = [{ text: full, style: { font_family: "patrick-hand", color: "#202c2d", weight: 400 } }];
const fullRuns = tree(fullView).filter((node) => node.id.startsWith("doc/1/1/paper/committed/part/"))
  .flatMap((node) => node.runs ?? []);
assert.equal(fullRuns.map((run) => run.text).join(""), full);
const structuredView = await fixture("document-paper");
const structured = "q".repeat(8192);
structuredView.documents["1"].state.data.committed = [{ text: structured, style: { color: "#202c2d" } }];
const structuredRuns = tree(structuredView).filter((node) => node.id.startsWith("doc/1/1/paper/committed/part/"))
  .flatMap((node) => node.runs ?? []);
assert.equal(structuredRuns.map((run) => run.text).join(""), structured);
const faxView = await fixture("document-fax");
const fax = tree(faxView);
assert(fax.some((node) => node.id === "doc/2/1/directory/entry/0/target"));
assert(fax.some((node) => node.id === "doc/2/1/send"));
assert(fax.some((node) => node.id === "doc/2/1/controls/eject"));
assert(!fax.some((node) => node.id === "doc/2/1/controls/power"));
const targetAction = ui.onEvent({ id: "doc/2/1/directory/entry/0/target", type: "activate" }, faxView).action;
assert.equal(targetAction.act, "confirm");
assert.deepEqual(targetAction.payload, { value: "ops" });
const confirmAction = ui.onEvent({ id: "doc/2/1/send", type: "activate" }, faxView).action;
assert.equal(confirmAction.act, "confirm");
assert.deepEqual(confirmAction.payload, { value: "ops" });
const nameAction = ui.onEvent({ id: "doc/2/1/controls/name/set", type: "activate", value: "Relay" }, faxView).action;
assert.equal(nameAction.act, "name");
assert.deepEqual(nameAction.payload, { value: "Relay" });
const copierView = await fixture("document-copier");
const copier = tree(copierView);
assert.equal(copier.find((node) => node.id === "doc/3/1/count").value, "1");
assert.equal(copier.find((node) => node.id === "doc/3/1/mode").value, "bw");
assert(copier.some((node) => node.id === "doc/3/1/copy"));
assert(copier.some((node) => node.id === "doc/3/1/eject"));
const countAction = ui.onEvent({ id: "doc/3/1/count", type: "change", value: "4" }, copierView).action;
assert.equal(countAction.act, "set_count");
assert.deepEqual(countAction.payload, { value: "4" });
const copyAction = ui.onEvent({ id: "doc/3/1/copy", type: "activate" }, copierView).action;
assert.equal(copyAction.act, "copy");
assert.deepEqual(copyAction.payload, { value: "" });
const emptyFax = tree(await fixture("document-fax-empty"));
assert(emptyFax.some((node) => node.id === "doc/2/1/loaded/empty"));
assert(emptyFax.some((node) => node.id === "doc/2/1/directory/page"));
const confirmingFax = tree(await fixture("document-fax-confirm"));
assert(confirmingFax.some((node) => node.id === "doc/2/1/confirm"));
assert(confirmingFax.some((node) => node.id === "doc/2/1/directory/entry/1/name" && node.text.includes("[aa:02]")));
const emptyCopier = tree(await fixture("document-copier-empty"));
assert(emptyCopier.some((node) => node.id === "doc/3/1/original/empty"));
const busyCopier = tree(await fixture("document-copier-busy"));
assert(busyCopier.some((node) => node.id === "doc/3/1/progress"));
console.log("Writing UI: paper, fax, and copier projections passed");
