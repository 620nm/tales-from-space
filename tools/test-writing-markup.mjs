import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const pack = fileURLToPath(new URL("..", import.meta.url));
const engine = path.resolve(process.argv[2] || process.env.LUNATIC_ENGINE || path.join(pack, "../lunatic"));
const sourcePath = path.join(pack, "reference/text/blood-type-compatibility.md");
const source = await readFile(sourcePath, "utf8");
const { build } = await import(pathToFileURL(path.join(engine, "web/node_modules/esbuild/lib/main.js")));
const bundle = await build({
  entryPoints: [path.join(pack, "ui/writing-markup.ts")],
  bundle: true, platform: "node", format: "esm", write: false,
});
const { parseWritingMarkup } = await import(
  `data:text/javascript;base64,${Buffer.from(bundle.outputFiles[0].text).toString("base64")}`
);

assert.equal(Buffer.byteLength(source, "utf8"), 3487);
const parsed = parseWritingMarkup(source);
assert.ok(parsed);
assert.equal(parsed.heading, "Blood Type Compatibility");
assert.equal(parsed.caption, "Donor");
assert.deepEqual(parsed.columns, ["Receiver", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "L", "U"]);
assert.deepEqual(parsed.rows, [
  ["A+", "✓", "✓", "", "", "", "", "✓", "✓", "", ""],
  ["A-", "", "✓", "", "", "", "", "", "✓", "", ""],
  ["B+", "", "", "✓", "✓", "", "", "✓", "✓", "", ""],
  ["B-", "", "", "", "✓", "", "", "", "✓", "", ""],
  ["AB+", "✓", "✓", "✓", "✓", "✓", "✓", "✓", "✓", "", ""],
  ["AB-", "", "✓", "", "✓", "", "✓", "", "✓", "", ""],
  ["O+", "", "", "", "", "", "", "✓", "✓", "", ""],
  ["O-", "", "", "", "", "", "", "", "✓", "", ""],
  ["L", "", "", "", "", "", "", "", "", "✓", ""],
  ["U", "✓", "✓", "✓", "✓", "✓", "✓", "✓", "✓", "✓", "✓"],
]);
assert.deepEqual(parsed.paragraphs, [
  "Blood types not written above can only receive from the same blood type.",
  "Certain species do not have blood.",
]);

const alternateSource = source
  .replace("Blood Type Compatibility", "Crew Schedule")
  .replaceAll("Donor", "Across")
  .replaceAll("Receiver", "Down")
  .replaceAll("A+", "North");
const alternate = parseWritingMarkup(alternateSource);
assert.ok(alternate);
assert.equal(alternate.heading, "Crew Schedule");
assert.equal(alternate.caption, "Across");
assert.equal(alternate.columns[0], "Down");
assert.equal(alternate.columns[1], "North");
assert.equal(alternate.rows[0][0], "North");

const firstRowStart = source.indexOf("<tr>");
const firstRowClose = source.indexOf("</tr>", firstRowStart);
assert.notEqual(firstRowStart, -1);
assert.notEqual(firstRowClose, -1);
const firstRowEnd = firstRowClose + "</tr>".length;
const firstRow = source.slice(firstRowStart, firstRowEnd);
const lastHeaderCell = '<td style="background-color: red; color: white;">U</td>';
assert.ok(source.includes(lastHeaderCell));

const nineParagraphs = source.slice(0, source.indexOf("\n\tBlood types"))
  + "\n\n" + Array.from({ length: 9 }, (_, index) => `Note ${index + 1}.`).join("\n");
const overTokenBudget = source.replace("<br/>", "<br/>".repeat(900));
assert.ok(Buffer.byteLength(overTokenBudget, "utf8") <= 8192);

for (const malformed of [
  "# Ordinary Markdown\nNo HTML table here.",
  `<article>${source}</article>`,
  source.replace("</h2>", "</table>"),
  source.replace("<table style=", '<table onclick="run()" style='),
  source.replace('border="1"', 'border="1'),
  source.replace('border="1"', 'border="1" width="100%"'),
  source.replace('width="25px" height="25px"', 'width="25px"height="25px"'),
  source.replace("<tbody>", '<tbody class="unknown">'),
  source.replace("</tr>", "</tbody></tr>"),
  source.replace(lastHeaderCell, `${lastHeaderCell}<td></td>`),
  source.replace('colspan="10"', 'colspan="13"'),
  source.replace('rowspan="10"', 'rowspan="9"'),
  source.replace("</td>", "<strong>nested</strong></td>"),
  source.replace("</tbody>", "</table>"),
  source.replace("<br/>", "<br/><script>run()</script>"),
  `${source}<td`,
  source.replace("<h2>Blood Type Compatibility</h2>", `<h2>${"x".repeat(513)}</h2>`),
  source.replace('style="text-align:center;"', `style="${"x".repeat(129)}"`),
  nineParagraphs,
  source.replace("</tbody>", `${firstRow}</tbody>`),
  overTokenBudget,
  source + "\ud800",
  "x".repeat(8193),
]) {
  assert.equal(parseWritingMarkup(malformed), undefined);
}
