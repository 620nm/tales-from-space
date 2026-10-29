import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const pack = fileURLToPath(new URL("..", import.meta.url));
const engine = path.resolve(process.argv[2] || process.env.LUNATIC_ENGINE || path.join(pack, "../lunatic"));
const { build } = await import(pathToFileURL(path.join(engine, "web/node_modules/esbuild/lib/main.js")));
globalThis.__lunaticLocale = {
  tag: "en", catalog: JSON.parse(await readFile(path.join(pack, "locale/en.json"), "utf8")),
};

async function load(entry) {
  const result = await build({
    entryPoints: [path.join(pack, entry)],
    alias: { "@lunatic/ui": path.join(engine, "web/sdk/index.ts") },
    bundle: true, platform: "node", format: "esm", write: false,
  });
  return import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
}

const [markup, writing, reader, paper, fax, copier] = await Promise.all([
  load("ui/writing-markup.ts"),
  load("ui/writing-text.ts"),
  load("ui/files-reader.ts"),
  load("ui/documents-paper.ts"),
  load("ui/documents-fax.ts"),
  load("ui/documents-copier.ts"),
]);

const source = await readFile(path.join(pack, "reference/text/blood-type-compatibility.md"), "utf8");
const normalized = markup.parseWritingMarkup(source);
assert.ok(normalized, "the pinned reference is recognized as one complete compatibility fragment");
assert.equal(normalized.columns.length, 11);
assert.equal(normalized.rows.length, 10);
assert.deepEqual(normalized.rows.map((row) => row.length), Array(10).fill(11));
assert.deepEqual(normalized.paragraphs, [
  "Blood types not written above can only receive from the same blood type.",
  "Certain species do not have blood.",
]);
assert.ok(normalized.columns.includes("L"));
assert.ok(normalized.columns.includes("U"));

const fixtureNames = [
  "document-blood-types.json",
  "document-blood-types-narrow.json",
  "document-blood-types-appended.json",
  "document-blood-types-copier.json",
  "document-blood-types-fax.json",
  "document-blood-types-file.json",
];
const fixtures = Object.fromEntries(await Promise.all(fixtureNames.map(async (name) => [
  name,
  JSON.parse(await readFile(path.join(pack, "ui/fixtures/document", name), "utf8")),
])));
const at = (fixture, ...parts) => parts.reduce((value, key) => value?.[key], fixture);
for (const [name, parts] of [
  [fixtureNames[0], ["view", "documents", "1", "state", "data", "committed", 0, "text"]],
  [fixtureNames[1], ["view", "documents", "1", "state", "data", "committed", 0, "text"]],
  [fixtureNames[2], ["view", "documents", "1", "state", "data", "committed", 0, "text"]],
  [fixtureNames[3], ["view", "documents", "3", "state", "data", "original", 0, "text"]],
  [fixtureNames[4], ["view", "documents", "2", "state", "data", "loadedpaper", 0, "text"]],
  [fixtureNames[5], ["view", "documents", "1", "state", "open", "fragments", 0, "text"]],
]) assert.equal(at(fixtures[name], ...parts), source, `${name} embeds the pinned source bytes`);
assert.equal(at(fixtures[fixtureNames[5]], "view", "documents", "1", "state", "open", "body"), source);
assert.equal(at(fixtures[fixtureNames[2]], "view", "documents", "1", "state", "data", "committed", 1, "text"),
  "\n\nSupplemental note: Keep the recipient card beside the transfusion record.");

function walk(nodes, visitor) {
  for (const node of nodes) {
    visitor(node);
    if (node.children) walk(node.children, visitor);
  }
}

function find(nodes, predicate) {
  let found;
  walk(nodes, (node) => { if (!found && predicate(node)) found = node; });
  return found;
}

function nodeCount(nodes) {
  return nodes.reduce((sum, node) => sum + 1 + nodeCount(node.children ?? []), 0);
}

function allText(nodes) {
  const values = [];
  walk(nodes, (node) => { if (typeof node.text === "string") values.push(node.text); });
  return values.join("");
}

function tableCellNodes(nodes) {
  const table = find(nodes, (node) => node.class?.includes("writing-markup-table"));
  assert.ok(table, "a recognized fragment produces one kit Table");
  const cells = (table.children ?? []).filter((cell) => cell.class?.includes("writing-markup-cell"));
  return { table, cells };
}

function cellText(cell) {
  return cell.children?.[0]?.text;
}

function assertCompleteTable(nodes, fragmentId) {
  const { table, cells } = tableCellNodes(nodes);
  const columnCount = normalized.columns.length;
  assert.equal(table.id, `${fragmentId}/table`);
  assert.equal(cells.length, columnCount * (normalized.rows.length + 1));

  const headers = cells.slice(0, columnCount);
  assert.deepEqual(headers.map((cell) => cell.id),
    normalized.columns.map((_, column) => `${table.id}/head/${column}`));
  assert.deepEqual(headers.map((cell) => cell.children?.[0]?.id),
    normalized.columns.map((_, column) => `${table.id}/head/${column}/text`));
  assert.deepEqual(headers.map(cellText), normalized.columns);

  const bodyCells = cells.slice(columnCount);
  assert.equal(bodyCells.length, normalized.rows.length * columnCount);
  for (let row = 0; row < normalized.rows.length; row++) {
    const rowCells = bodyCells.slice(row * columnCount, (row + 1) * columnCount);
    assert.equal(rowCells.length, columnCount, `row ${row} retains every source column`);
    assert.deepEqual(rowCells.map((cell) => cell.id),
      normalized.columns.map((_, column) => `${table.id}/${row}/${column}`));
    assert.deepEqual(rowCells.map((cell) => cell.children?.[0]?.id),
      normalized.columns.map((_, column) => `${table.id}/${row}/${column}/text`));
    assert.deepEqual(rowCells.map(cellText), normalized.rows[row], `row ${row} retains source values`);
  }
  return cells.map(cellText);
}

function assertFullProjection(nodes, flowId) {
  assert.ok(nodeCount(nodes) <= 384, `preview subtree has ${nodeCount(nodes)} recursive nodes`);
  const flow = find(nodes, (node) => node.class?.includes("writing-markup-flow"));
  assert.ok(flow, "recognized content is grouped in one markup flow wrapper");
  assert.equal(flow.id, flowId, "the flow wrapper retains the stable markup ID");
  let nestedScroller;
  walk([flow], (node) => {
    if (node.class?.some((name) => name === "scroll" || name.startsWith("scroll-"))) nestedScroller = node;
  });
  assert.equal(nestedScroller, undefined, "markup content leaves vertical scrolling to its document body");

  const rendered = allText(nodes);
  assert.ok(!rendered.includes("<h2>") && !rendered.includes("<table"), "recognized tags never reach visible text");
  const fragmentId = `${flowId}/0`;
  assert.equal(find([flow], (node) => node.id === `${fragmentId}/heading`)?.text, normalized.heading);
  assert.equal(find([flow], (node) => node.id === `${fragmentId}/caption`)?.text, normalized.caption);
  for (const [index, paragraph] of normalized.paragraphs.entries()) {
    assert.equal(find([flow], (node) => node.id === `${fragmentId}/paragraph/${index}`)?.text, paragraph);
  }
  for (const value of [normalized.heading, normalized.caption, ...normalized.columns,
    ...normalized.rows.flat(), ...normalized.paragraphs]) {
    assert.ok(rendered.includes(value), `complete projection retains ${value}`);
  }
  assert.ok(rendered.indexOf(normalized.paragraphs[0]) < rendered.indexOf(normalized.paragraphs[1]),
    "the trailing source sentences retain their order");
  return assertCompleteTable(nodes, `${flowId}/0`);
}

const sourceFragment = { text: source };
const directFlow = writing.writingMarkupNodes("direct", [sourceFragment], ["paper-line"], 384);
assert.ok(directFlow);
assert.equal(directFlow.length, 1);
assert.equal(directFlow[0].id, "direct/markup");
assert.ok(directFlow[0].class.includes("writing-markup-flow"));
assertFullProjection(directFlow, "direct/markup");

const paperDocument = { id: 1, generation: 1, title: "Blood type compatibility" };
const paperState = at(fixtures[fixtureNames[0]], "view", "documents", "1", "state", "data");
const paperNodes = paper.paperBody("doc/1/1", paperDocument, paperState, true);
const paperPreview = find(paperNodes, (node) => node.id === "doc/1/1/paper/committed");
assert.ok(paperPreview);
const paperCells = assertFullProjection([paperPreview], `${paperPreview.id}/markup`);

const narrowData = at(fixtures[fixtureNames[1]], "view", "documents", "1", "state", "data");
const narrowNodes = paper.paperBody("doc/1/1", paperDocument, narrowData, true);
const narrowPreview = find(narrowNodes, (node) => node.id === "doc/1/1/paper/committed");
assert.ok(narrowPreview);
assert.deepEqual(assertFullProjection([narrowPreview], `${narrowPreview.id}/markup`), paperCells);

const appendedData = at(fixtures[fixtureNames[2]], "view", "documents", "1", "state", "data");
const appendedNodes = paper.paperBody("doc/1/1", paperDocument, appendedData, true);
const appendedPreview = find(appendedNodes, (node) => node.id === "doc/1/1/paper/committed");
assert.ok(appendedPreview);
assert.deepEqual(assertFullProjection([appendedPreview], `${appendedPreview.id}/markup`), paperCells);
const appendedFlow = find([appendedPreview], (node) => node.id === `${appendedPreview.id}/markup`);
const appendedNote = find([appendedFlow], (node) => node.id === `${appendedPreview.id}/fragment/1/part/0`);
assert.equal(appendedNote?.text, appendedData.committed[1].text);
assert.ok(appendedNote.class.includes("paper-line"), "later fragments keep handwriting styling");
const footerIds = [
  `${appendedPreview.id}/markup/0/paragraph/0`,
  `${appendedPreview.id}/markup/0/paragraph/1`,
];
assert.ok(appendedFlow.children.findIndex((node) => node.id === footerIds[0])
  < appendedFlow.children.findIndex((node) => node.id === footerIds[1]));
assert.ok(appendedFlow.children.findIndex((node) => node.id === footerIds[1])
  < appendedFlow.children.findIndex((node) => node.id === appendedNote.id),
"the appended note follows both source footer sentences");

const copierData = at(fixtures[fixtureNames[3]], "view", "documents", "3", "state", "data");
const copierNodes = copier.copierBody("doc/3/1", { id: 3, generation: 1, title: "Photocopier" }, copierData, true);
const copierPreview = find(copierNodes, (node) => node.id === "doc/3/1/original");
assert.ok(copierPreview);
assert.deepEqual(assertFullProjection([copierPreview], `${copierPreview.id}/markup`), paperCells);

const faxData = at(fixtures[fixtureNames[4]], "view", "documents", "2", "state", "data");
const faxNodes = fax.faxBody("doc/2/1", { id: 2, generation: 1, title: "Fax machine" }, faxData, true);
const faxPreview = find(faxNodes, (node) => node.id === "doc/2/1/loaded");
assert.ok(faxPreview);
assert.deepEqual(assertFullProjection([faxPreview], `${faxPreview.id}/markup`), paperCells);

const fileState = at(fixtures[fixtureNames[5]], "view", "documents", "1", "state");
const fileNodes = reader.fileReader("doc/1/1/reader/content", "md", fileState.open.body, 384, fileState.open.fragments);
assert.ok(fileNodes);
assert.deepEqual(assertFullProjection(fileNodes, "doc/1/1/reader/content/markup"), paperCells);

const alternate = source.replace(">Donor</td>", ">Contributor</td>");
assert.notEqual(alternate, source, "the source contains the pinned donor caption");
const alternateMarkup = markup.parseWritingMarkup(alternate);
assert.equal(alternateMarkup?.caption, "Contributor", "visible labels stay source-driven");
const alternateNodes = writing.writingPreview("alternate", [{ text: alternate }]);
assert.ok(allText(alternateNodes).includes("Contributor"));
assert.equal(find(alternateNodes, (node) => node.class?.includes("writing-markup-flow"))?.id, "alternate/markup");

const malformed = `${source}\n<script>untrusted()</script>`;
assert.equal(markup.parseWritingMarkup(malformed), undefined);
const malformedNodes = writing.writingPreview("malformed", [{ text: malformed }]);
assert.equal(find(malformedNodes, (node) => node.class?.includes("writing-markup-table")), undefined);
assert.equal(malformedNodes.length, 1);
assert.equal(malformedNodes[0].text, malformed, "an invalid fragment falls back whole and inert");
assert.ok(malformedNodes[0].class.includes("paper-line"));

const escapedImage = "&lt;img src=x onerror=alert(1)&gt;";
const rawImage = "<img src=x onerror=alert(1)>";
const escapedImageSource = source.replace(">✓</td>", `>${escapedImage}</td>`);
assert.notEqual(escapedImageSource, source, "the reference has a table cell for the hostile text");
const escapedImageNodes = writing.writingPreview("hostile-escaped", [{ text: escapedImageSource }]);
const escapedImageCell = find(escapedImageNodes, (node) =>
  node.class?.includes("writing-markup-cell") && cellText(node) === escapedImage);
assert.ok(escapedImageCell, "escaped HTML stays in a rendered table cell as text");
assert.equal(escapedImageCell.children?.length, 1, "the hostile cell contains only its text node");
assert.equal(escapedImageCell.children?.[0]?.text, escapedImage);
assert.equal(escapedImageCell.children?.[0]?.children, undefined, "escaped HTML creates no nested element");

const rawImageSource = source.replace(">✓</td>", `>${escapedImage} ${rawImage}</td>`);
assert.notEqual(rawImageSource, source, "the reference has a table cell for raw HTML fallback");
const rawImageNodes = writing.writingPreview("hostile-raw", [{ text: rawImageSource }]);
assert.equal(find(rawImageNodes, (node) => node.class?.includes("writing-markup-table")), undefined,
  "raw HTML makes the unsupported fragment use the inert text path");
assert.equal(rawImageNodes.length, 1);
assert.equal(rawImageNodes[0].text, rawImageSource, "raw HTML in a cell is preserved as literal fallback text");
assert.equal(rawImageNodes[0].children, undefined, "raw HTML fallback creates no element");

const twoTables = writing.writingPreview("two-tables", [sourceFragment, sourceFragment]);
assert.equal((() => { let count = 0; walk(twoTables, (node) => { if (node.class?.includes("writing-markup-table")) count++; }); return count; })(), 1,
  "a second recognized fragment that cannot fit stays whole on the inert text fallback");
const twoTableFlow = find(twoTables, (node) => node.class?.includes("writing-markup-flow"));
assert.ok(twoTableFlow);
const secondFragmentFallback = find([twoTableFlow], (node) => node.text === source);
assert.equal(secondFragmentFallback?.id, "two-tables/fragment/1/part/0");
assert.ok(secondFragmentFallback.class.includes("paper-line"));
assert.ok(nodeCount(twoTables) <= 384);
assert.equal(writing.writingMarkupNodes("too-small", [sourceFragment], ["reader-inline"], 100), undefined,
  "the renderer signals whole-fragment fallback when a complete Table cannot fit");

const blankPaper = paper.paperBody("blank", paperDocument, { committed: [], draft: "", revision: 1 }, true);
const blankDraft = find(blankPaper, node => node.type === "textarea");
assert.equal(blankDraft.placeholder, "The sheet is blank.");
assert.equal(blankDraft.markdown, true);
assert.equal(blankDraft.value, "");
assert.equal(find(blankPaper, node => node.text === blankDraft.placeholder), undefined,
  "blank-sheet guidance is a disappearing placeholder, never sheet content");

const plainPaper = writing.writingPreview("plain", [{ text: "**typed** and *plain*" }]);
assert.equal(plainPaper.length, 1);
assert.equal(plainPaper[0].id, "plain/part/0");
assert.equal(plainPaper[0].text, "**typed** and *plain*");
assert.equal(plainPaper[0].markdown, true, "committed ink uses the same trusted Markdown renderer as drafts");
const plainReader = reader.fileReader("plain-file", "md", "", 384, [
  { text: "**type**", style: { color: "#bb2222", font_family: "patrick-hand", weight: 400 } },
]);
assert.equal(plainReader.length, 1);
assert.equal(plainReader[0].id, "plain-file/flow");
assert.equal(plainReader[0].children[0].id, "plain-file/part/0");
assert.deepEqual(plainReader[0].children[0].runs, [{ text: "type", color: "#bb2222", fontFamily: "patrick-hand", fontWeight: 700 }]);

const smallReader = reader.fileReader("small-reader", "md", source, 12, [sourceFragment]);
assert.ok(smallReader);
assert.ok(nodeCount(smallReader) <= 12, "caller node limits include the reader wrapper and reservation");
assert.equal(find(smallReader, (node) => node.class?.includes("writing-markup-table")), undefined);
assert.equal(allText(smallReader), source, "a projection too large for a small reader stays whole text");

const largeReader = reader.fileReader("large-reader", "md", "", 384, [
  sourceFragment,
  { text: "x".repeat(4096) },
  { text: "y".repeat(4096) },
]);
assert.ok(largeReader);
assertFullProjection(largeReader, "large-reader/markup");
const largeText = allText(largeReader);
assert.ok(largeText.includes("x".repeat(4096)) && largeText.includes("y".repeat(4096)),
  "committed file fragments retain the 65536-byte reader budget instead of the paper 8192-byte cap");
assert.equal(find(largeReader, (node) => node.id === "large-reader/truncated"), undefined);

console.log("Writing markup: source-driven tables, whole-fragment fallback, shared previews, and bounded readers passed");
