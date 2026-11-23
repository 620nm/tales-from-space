import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const root = process.argv[2];
assert.ok(root, "pass the ui-shots output directory");

const cases = [
  { file: "preparation.rects.json", contact: "preparation-contact", width: 1280, height: 800 },
  { file: "preparation-contact.rects.json", contact: "contact/window", width: 1280, height: 800 },
  { file: "preparation-compact.rects.json", contact: "preparation-contact", width: 1024, height: 640 },
  { file: "preparation-contact-compact.rects.json", contact: "contact/window", width: 1024, height: 640 },
];
const intersects = (a, b) =>
  a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

for (const { file, contact, width, height } of cases) {
  test(`${file}: contact leaves OOC visible at ${width}x${height}`, () => {
    const geometry = JSON.parse(readFileSync(join(root, "preparation", file), "utf8"));
    assert.equal(geometry.viewport.w, width);
    assert.equal(geometry.viewport.h, height);
    const boxes = [
      ["contact", geometry.boxes[`lunatic/tfs/${contact}`]],
      ["footer", geometry.boxes["lunatic/tfs/chat-pane/footer"]],
      ["entry", geometry.boxes["lunatic/tfs/chat"]],
    ];
    for (const [name, box] of boxes) {
      assert.ok(box, `${name} has a rectangle`);
      assert.ok(box.x >= 0 && box.y >= 0, `${name} starts inside the viewport`);
      assert.ok(box.x + box.w <= width && box.y + box.h <= height,
        `${name} ends inside the viewport`);
    }
    const [, contactBox] = boxes[0];
    const [, footer] = boxes[1];
    const [, entry] = boxes[2];
    assert.ok(!intersects(contactBox, footer), "contact does not intersect the chat footer");
    assert.ok(!intersects(contactBox, entry), "contact does not intersect the chat entry");
  });
}
