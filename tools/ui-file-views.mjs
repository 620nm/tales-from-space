// This pack's file workspace through one guest: Markdown preview and edit
// keep the draft, and a read-only record offers no edit. Its node ids are
// this pack's `ui/` content; tools/test-ui-providers.mjs drives it.
import assert from "node:assert/strict";
import { find } from "./ui-runtime-harness.mjs";

/** The file workspace keeps drafts across Markdown mode changes, and a
 *  read-only record offers no edit. */
export async function fileViews(vm, view, file) {
  const id = "doc/2/1";
  const record = structuredClone(file);
  Object.assign(record.state.open, { ext: "md", body: "# Original" });
  record.state.editor.body = record.state.open.body;
  record.state.files = [{ ...record.state.open, size: 10 }];
  const current = { ...view, documents: { 2: record } };
  const render = () => vm.render(current);
  const activate = (suffix, extra = {}) => vm.event({ id: `${id}/${suffix}`, type: "activate", ...extra }, current);
  const all = (node) => [node, ...(node.children ?? []).flatMap(all)];
  let tree = await render();
  assert.ok(find(tree, `${id}/reader`));
  assert.equal(all(tree).some((node) => node.type === "textarea"), false);
  assert.equal(find(tree, `${id}/editor/save`).submit, undefined,
    "preview actions must not submit a hidden textarea: the host rejects missing targets");
  assert.equal(find(tree, `${id}/drive/host/file/0/open`).submit, undefined);

  await activate("editor/edit");
  tree = await render();
  assert.equal(find(tree, `${id}/reader`), undefined);
  const bodyId = find(tree, `${id}/editor/save`).submit;
  assert.equal(find(tree, bodyId).value, "# Original");
  await activate("editor/view", { value: "# Unsent draft", revision: 1 });
  tree = await render();
  assert.equal(find(tree, bodyId), undefined);
  assert.equal(find(tree, `${id}/reader/content/line/0`).text, "Unsent draft");
  assert.equal(find(tree, `${id}/editor/save`).submit, undefined);
  const saved = (await activate("editor/save")).action;
  assert.equal(saved.payload.text, "# Unsent draft");
  assert.equal(saved.payload.revision, 1);
  record.state.open.body = "# Unsent draft";
  record.state.open.revision = 2;
  record.state.save_ack = { request: saved.payload.request, binding: "fixture-host", uid: 1, revision: 2 };
  await render();

  await activate("editor/edit");
  await render();
  await activate("editor/view", { value: "# Another draft", revision: 2 });
  await render();
  assert.equal((await activate("drive/host/file/0/open")).action, undefined,
    "changing files from preview still guards the retained draft");
  tree = await render();
  assert.ok(find(tree, `${id}/editor/guard/save`));
  assert.equal(find(tree, `${id}/editor/guard/save`).submit, undefined);
  await activate("editor/guard/cancel");
  await render();
  await activate("editor/edit");
  tree = await render();
  assert.equal(find(tree, find(tree, `${id}/editor/save`).submit).value, "# Another draft");
  await vm.render({ ...view, documents: {} });

  for (const ext of ["md", "disl"]) {
    Object.assign(record.state.open, { ext, body: "readonly body" });
    record.state.editor.read_only = true;
    record.state.files[0].fixed = true;
    tree = await render();
    assert.ok(find(tree, `${id}/drive/host/file/0/read-only`));
    assert.equal(find(tree, `${id}/drive/host/file/0/delete`), undefined);
    assert.ok(find(tree, `${id}/editor/read-only`));
    for (const suffix of ["save", "revert", "rename"])
      assert.equal(find(tree, `${id}/editor/${suffix}`), undefined);
    assert.equal(all(tree).some((node) => node.primarySave), false);
    if (ext === "md") {
      await activate("editor/edit");
      tree = await render();
      assert.equal(find(tree, `${id}/reader`), undefined);
    }
    const source = all(tree).find((node) => node.type === "textarea");
    assert.equal(source.disabled, true);
    assert.equal(source.value, "readonly body");
    if (ext === "disl") assert.equal(source.language, "luau");
    await vm.render({ ...view, documents: {} });
  }
}
