import assert from "node:assert/strict";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Set LUNATIC_ENGINE or pass the absolute engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  entryPoints: [fileURLToPath(new URL("../ui/files-buffer.ts", import.meta.url))],
  bundle: true, format: "esm", platform: "node", write: false,
});
const B = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const id = "doc/1/2";
const doc = { id: 1, generation: 2, title: "Computer" };
const command = { kind: "eject" };
const state = (binding = "old", revision = 3, body = "saved", store = "media") => ({
  stores: [{ binding }], open: { binding, store, uid: 1, name: "x", ext: "md", revision, body },
});
const documents = (s) => [{ ...doc, state: s }];
const acknowledged = (s, request) => ({ ...s,
  save_ack: { request, binding: s.open.binding, uid: s.open.uid, revision: s.open.revision },
});
function dirty(store = "media") {
  B.retainOpenFileBuffers([]);
  const b = B.editorBuffer(id, doc, state("old", 3, "saved", store));
  B.editBuffer(b, "draft");
  return b;
}
function pending() {
  const b = dirty();
  B.guard(id, command)({});
  const action = B.saveBuffer(b, { value: "draft", revision: 3 }, true);
  assert.equal(action.payload.request, b.pending.request);
  return b;
}

test("B ejection does not guard dirty A work", () => {
  const b = dirty("host");
  assert.equal(B.guard(id, command, "media")({}), command);
  assert.equal(b.guard, undefined);
});
test("affected dirty work offers confirmation", () => {
  const b = dirty();
  assert.equal(B.guard(id, command, "media")({}), undefined);
  assert.deepEqual(b.guard, command);
});
test("matching successful save continues exactly once", () => {
  const b = pending();
  const next = documents(acknowledged(state("old", 4, "draft"), b.pending.request));
  assert.deepEqual(B.pollContinuation(next), command);
  assert.equal(B.pollContinuation(next), undefined);
});
test("refused save retains draft and does not continue", () => {
  const b = pending();
  assert.equal(B.pollContinuation(documents(state())), undefined);
  assert.equal(b.dirty, true);
  assert.equal(b.text, "draft");
});
test("identical concurrent save requires our receipt", () => {
  const b = pending();
  assert.equal(B.pollContinuation(documents(state("old", 4, "draft"))), undefined);
  assert.equal(b.dirty, true);
});
test("another request receipt does not acknowledge our save", () => {
  const b = pending();
  const next = acknowledged(state("old", 4, "draft"), "another-request");
  assert.equal(B.pollContinuation(documents(next)), undefined);
  assert.equal(b.dirty, true);
});
test("replacement media with identical uid and revision cancels continuation", () => {
  const b = pending();
  const next = acknowledged(state("replacement", 4, "draft"), b.pending.request);
  assert.equal(B.pollContinuation(documents(next)), undefined);
});
test("document closure cancels late acknowledgement", () => {
  const b = pending();
  const next = acknowledged(state("old", 4, "draft"), b.pending.request);
  assert.equal(B.pollContinuation([]), undefined);
  assert.equal(B.pollContinuation(documents(next)), undefined);
});
test("provider revocation cancels late acknowledgement", () => {
  const b = pending();
  const next = acknowledged(state("old", 4, "draft"), b.pending.request);
  assert.equal(B.pollContinuation(documents({})), undefined);
  assert.equal(B.pollContinuation(documents(next)), undefined);
});
test("other store replacement cancels a deferred cross-store operation", () => {
  B.retainOpenFileBuffers([]);
  const original = state(); original.stores.push({ binding: "destination" });
  const b = B.editorBuffer(id, doc, original);
  B.editBuffer(b, "draft"); B.guard(id, command)({}); B.saveBuffer(b, {}, true);
  const next = acknowledged(state("old", 4, "draft"), b.pending.request);
  next.stores.push({ binding: "new-destination" });
  assert.equal(B.pollContinuation(documents(next)), undefined);
});
test("concurrent conflicting save leaves dirty editor open", () => {
  const b = pending();
  assert.equal(B.pollContinuation(documents(state("old", 4, "other writer"))), undefined);
  assert.equal(b.dirty, true);
});
test("editing after submission cancels the deferred operation", () => {
  const b = pending();
  const next = acknowledged(state("old", 4, "draft"), b.pending.request);
  B.editBuffer(b, "newer draft");
  assert.equal(B.pollContinuation(documents(next)), undefined);
  assert.equal(b.text, "newer draft");
});
test("Cancel preserves dirty work", () => {
  const b = dirty(); B.guard(id, command)({}); B.cancelGuard(b);
  assert.equal(b.guard, undefined);
  assert.equal(b.dirty, true);
});
test("Discard releases the buffer and continues", () => {
  const b = dirty(); B.guard(id, command)({});
  assert.deepEqual(B.discardGuard(b), command);
  assert.equal(B.bodyId(id), undefined);
});
test("guard captures an unflushed live editor draft", () => {
  B.retainOpenFileBuffers([]);
  const b = B.editorBuffer(id, doc, state());
  B.guard(id, command)({ value: "unflushed" });
  assert.equal(b.dirty, true);
  assert.deepEqual(b.guard, command);
});
test("Discard and release cannot execute twice", () => {
  const b = dirty(); let released = 0;
  B.guard(id, command, undefined, () => released++)({});
  assert.deepEqual(B.discardGuard(b), command);
  assert.equal(B.discardGuard(b), undefined);
  assert.equal(released, 1);
});
test("Cancel while saving cancels only the continuation", () => {
  const b = pending(); const request = b.pending.request;
  B.cancelGuard(b);
  assert.equal(b.pending, undefined, "Cancel releases a refused or unanswered save");
  assert.equal(B.pollContinuation(documents(acknowledged(state("old", 4, "draft"), request))), undefined);
});
test("create naming draft survives extension changes with one owner", () => {
  B.retainOpenFileBuffers([]);
  B.openCreateDialog(`${id}/host`, "md");
  B.createDialog(`${id}/host`).stem = "Station notes";
  B.openCreateDialog(`${id}/host`, "atmo");
  assert.equal(B.createDialog(`${id}/host`).stem, "Station notes");
  B.openCreateDialog(`${id}/media`, "pem");
  assert.equal(B.createDialog(`${id}/host`), undefined);
  assert.equal(B.createDialog(`${id}/media`).ext, "pem");
});
test("conflicting receipt releases pending lock while retaining guard and draft", () => {
  const b = pending();
  B.editorBuffer(id, doc, state("old", 4, "Other writer"));
  assert.equal(b.pending, undefined);
  assert.deepEqual(b.guard, command);
  assert.equal(b.text, "draft");
  assert.equal(b.continuation, undefined);
});
