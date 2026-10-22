import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const pack = fileURLToPath(new URL("..", import.meta.url));
const engine = path.resolve(process.argv[2] || process.env.LUNATIC_ENGINE || path.join(pack, "../lunatic"));
const sourcePath = path.join(pack, "reference/text/blood-type-compatibility.md");
const source = await readFile(sourcePath, "utf8");
const { build } = await import(pathToFileURL(path.join(engine, "web/node_modules/esbuild/lib/main.js")));
const MAX_INPUT_BYTES = 8192;
const MAX_TOKENS = 1024;
const markupPath = path.join(pack, "ui/writing-markup.ts");
const markupSource = await readFile(markupPath, "utf8");
async function loadMarkupWithTokenLimit(tokenLimit) {
  const limitSetting = "const MAX_TOKENS = 1024;";
  assert.ok(markupSource.includes(limitSetting), "the test transform finds the tokenizer limit");
  const configuredSource = tokenLimit === MAX_TOKENS
    ? markupSource
    : markupSource.replace(limitSetting, `const MAX_TOKENS = ${tokenLimit};`);
  if (tokenLimit !== MAX_TOKENS) {
    assert.notEqual(configuredSource, markupSource, "the test transform raises the tokenizer limit");
  }
  const bundle = await build({
    stdin: {
      contents: `${configuredSource}\nexport { tokenize };`,
      loader: "ts",
      resolveDir: path.dirname(markupPath),
      sourcefile: path.basename(markupPath),
    },
    bundle: true, platform: "node", format: "esm", write: false,
  });
  return import(`data:text/javascript;base64,${Buffer.from(bundle.outputFiles[0].text).toString("base64")}`);
}
const [markup, liftedMarkup] = await Promise.all([
  loadMarkupWithTokenLimit(MAX_TOKENS),
  loadMarkupWithTokenLimit(MAX_TOKENS * 2),
]);
const { parseWritingMarkup } = markup;

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
const extraDataRow = `<tr>${"<td></td>".repeat(11)}</tr>`;
const overTokenBudget = source.replace("</tbody>", `${extraDataRow.repeat(22)}</tbody>`);
assert.notEqual(overTokenBudget, source, "extra well-formed rows expand the table");
assert.ok(Buffer.byteLength(overTokenBudget, "utf8") <= MAX_INPUT_BYTES,
  "the over-token fixture stays below the input byte limit");
assert.equal(markup.tokenize(overTokenBudget), undefined,
  "the default tokenizer cap rejects the well-formed expanded table");
const liftedTokens = liftedMarkup.tokenize(overTokenBudget);
assert.ok(Array.isArray(liftedTokens), "raising the cap allows tokenization to finish");
assert.ok(liftedTokens.length > MAX_TOKENS,
  "the expanded table exceeds MAX_TOKENS before document grammar limits run");

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
  source + "\ud800",
  "x".repeat(8193),
]) {
  assert.equal(parseWritingMarkup(malformed), undefined);
}
