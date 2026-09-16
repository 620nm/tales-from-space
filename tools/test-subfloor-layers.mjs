import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const compositions = await readFile(new URL("../content/compositions.luau", import.meta.url), "utf8");

test("cables draw above pipes: power outranks pipe", () => {
  const block = compositions.match(/layers = \{(.*?)\n    \},/s)?.[1];
  assert(block, "layers block parses");
  assert.match(block, /\{ id = "pipe", parent = "infrastructure" \}/);
  assert.match(block, /\{ id = "power", parent = "infrastructure" \}/);
  const pipe = block.indexOf('{ id = "pipe"');
  const power = block.indexOf('{ id = "power"');
  assert(pipe < power, "pipe declared before power, so power draws above");
});
