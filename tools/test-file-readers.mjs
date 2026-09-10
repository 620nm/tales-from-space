import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const pack = fileURLToPath(new URL("..", import.meta.url));
const engine = path.resolve(process.argv[2] || process.env.LUNATIC_ENGINE || path.join(pack, "../lunatic"));
const { build } = await import(pathToFileURL(path.join(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  entryPoints: [path.join(pack, "ui/files-reader.ts")],
  alias: { "@lunatic/ui": path.join(engine, "web/sdk/index.ts") },
  bundle: true, platform: "node", format: "esm", write: false,
});
globalThis.__lunaticLocale = {
  tag: "en", catalog: JSON.parse(await readFile(path.join(pack, "locale/en.json"), "utf8")),
};
const { fileReader } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);

const read = (ext, body) => fileReader("reader", ext, body);
const atmo = (changes = {}) => JSON.stringify({
  version: 1, temperature_k: 293.15, pressure_kpa: 101.325,
  gases: [{ id: "oxygen", moles: 3 }], ...changes,
});

assert.equal(read("disl", "print(1)"), undefined);
assert.equal(read("doc", "legacy extension"), undefined);
assert.equal(read("unknown", "text"), undefined);

const attack = '<script>alert(1)</script>\n![remote](https://example.invalid/image)\n[link](javascript:alert(1))';
const markdown = read("md", `# Title\n${attack}\n> Quote\n- List item\n\x60\x60\x60luau\n# Code\n\x60\x60\x60`);
assert.equal(markdown[0].text, "Title");
assert.ok(markdown[0].class.includes("reader-head"));
assert.equal(markdown[0].style.fontSize, 20);
assert.ok(markdown[4].class.includes("reader-quote"));
assert.equal(markdown[1].text, '<script>alert(1)</script>');
assert.equal(markdown[2].text, '![remote](https://example.invalid/image)');
assert.equal(markdown[3].text, '[link](javascript:alert(1))');
assert.equal(markdown[4].text, "Quote");
assert.equal(markdown[5].text, "- List item");
assert.equal(markdown[6].text, "# Code");
assert.ok(markdown[6].class.includes("mono"));
assert.ok(markdown.every((node) => node.type === "text" && !node.events && !node.asset));

for (const ext of ["md", "pem"]) {
  for (const body of ["a".repeat(70000), "a\n".repeat(70000), "```\n".repeat(17000)]) {
    const nodes = read(ext, body);
    assert.ok(nodes.length <= 384);
    assert.ok(nodes.every((node) => node.text.length <= 4096));
    assert.equal(new Set(nodes.map((node) => node.id)).size, nodes.length);
    assert.match(nodes.at(-1).text, /Preview shortened/);
  }
}
assert.ok(!read("md", "Complete file").some((node) => /Preview shortened/.test(node.text)));
const pem = read("pem", "PRIVATE KEY\n# literal text");
assert.match(pem[0].text, /Access material/);
assert.equal(pem[2].text, "# literal text");
assert.ok(pem.every((node) => node.type === "text" && !node.events));

const valid = read("atmo", atmo());
assert.equal(valid.length, 4);
assert.equal(valid[1].text, "Temperature: 293.15 K");
assert.equal(valid[2].text, "Pressure: 101.325 kPa");
assert.equal(valid[3].text, "oxygen: 3 mol");
assert.equal(read("atmo", atmo({ gases: [], temperature_k: 0, pressure_kpa: 0 })).length, 3);
for (const invalid of [
  "", " ", "{", "{}", "null", "[]", "a".repeat(65537),
  atmo({ version: 2 }), atmo({ temperature_k: -1 }), atmo({ pressure_kpa: "1" }),
  atmo({ unknown: true }), atmo({ title: "x".repeat(161) }),
  atmo({ gases: [{ id: " ", moles: 1 }] }),
  atmo({ gases: [{ id: "x", moles: -1 }] }),
  atmo({ gases: [{ id: "x", moles: 1, extra: true }] }),
  atmo({ gases: [{ id: "x", moles: 1 }, { id: "x", moles: 2 }] }),
  atmo({ gases: Array.from({ length: 33 }, (_, i) => ({ id: String(i), moles: 1 })) }),
  atmo().replace("293.15", "1e999"),
]) assert.equal(read("atmo", invalid), undefined, invalid.slice(0, 120));

console.log("File readers: bounded text, inert Markdown, ATMO validation, and PEM checks passed");
