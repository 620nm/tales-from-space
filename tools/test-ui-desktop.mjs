// This pack's laptop desktop, in the pinned interpreter: every assertion
// below names this pack's own documents, windows, wallpapers and catalog
// keys. The engine's own runtime coverage is its `web/tests/pack-ui/kit/`.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import {
  assertUniqueIds, createGuest, find, ids, packRoot, readBundle, reportSkip,
} from "./ui-runtime-harness.mjs";

/** The two fixtures these assertions are written against. Named here and
 *  nowhere else, so the skip below can say which are missing. */
const REQUIRED = ["laptop/laptop-desktop", "laptop/laptop-files"];

/** The view a shipped fixture carries (the engine's docs/pack-ui/lab.md). */
const fixtureView = async (name) =>
  JSON.parse(await readFile(join(packRoot, `ui/fixtures/${name}.json`), "utf8"))
    .view;
/** That view, or null when the pack ships no such FILE. Absence is the
 *  only skip: a malformed fixture, an unreadable one, a truncated write
 *  or a renamed `view` is a fault, and laundering one into "ships no
 *  fixture" would retire ~40 assertions under a true-looking line. */
const shipped = async (name) => {
  let view;
  try {
    view = await fixtureView(name);
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
  if (!view) throw Error(`ui/fixtures/${name}.json declares no view`);
  return view;
};

// An unbuilt pack is not a failing one: `xtask build-ui` writes this.
// Named, and never counted as a pass: every skip leaves by the channel
// tools/test.mjs reads.
const bundle = await readBundle("ui/bundle.json");
if (!bundle) {
  reportSkip("pack desktop checks: no built pack UI (fix: xtask build-ui)");
  process.exit(0);
}
// A pack that ships no desktop has nothing here to be wrong about.
const views = await Promise.all(REQUIRED.map(shipped));
const absent = REQUIRED.filter((_, at) => !views[at]);
if (absent.length) {
  reportSkip(
    `pack desktop checks: ${packRoot} ships no ${absent.join(" or ")} fixture, ` +
      "and these assertions are written against that one pack's laptop",
  );
  process.exit(0);
}
// One open laptop, plus the little a HUD render reads besides.
const [view, full] = views;
const vm = await createGuest(bundle);
try {
  // `render` validates before it answers, so an accepted tree is the
  // assertion: no duplicate id, nothing over a limit.
  const tree = vm.render(view);
  assert.ok(tree, "the pack renders a tree with a laptop open");
  const seen = assertUniqueIds(tree, "laptop desktop");
  // Power is a glyph press in the heading; the lid closes only by the
  // item interaction, and `/close` belongs to the window the host declares.
  assert.ok(!seen.includes("doc/1/1/lid"), "no node draws a lid press");
  assert.ok(!seen.includes("doc/1/1/close"), "no node draws the window close");
  assert.ok(!seen.includes("doc/1/1/controls"), "no task bar row");
  const screen = find(tree, "doc/1/1");
  assert.equal(screen.window.contentAspectRatio, 16 / 9);
  assert.equal(screen.window.minWidth, 740);
  assert.equal(screen.window.maximizable, true);
  assert.equal(screen.window.titleAsset, "laptop_on");
  assert.equal(find(tree, "doc/1/1/panes").split.panes.length, 3);
  assert.ok(find(tree, "doc/1/1/drive/media/eject"));
  assert.equal(find(tree, "doc/1/1/eject_cartridge"), undefined);
  assert.equal(find(tree, "doc/1/1/power").label, "lunatic/tfs:ui.desktop.power_off");
  assert.ok(find(tree, "doc/1/1/heading"), "power sits in the information heading");
  assert.equal(find(tree, "doc/1/1/drive/host/create").type, "button");
  for (const wallpaper of ["wallpaper_bliss", "wallpaper_moonlake"]) {
    view.documents[1].state.script.data.wallpaper = wallpaper;
    assert.equal(find(vm.render(view), "doc/1/1/wallpaper").asset, wallpaper);
  }
  view.documents[1].state.stores.pop();
  const withoutMedia = vm.render(view);
  assert.equal(find(withoutMedia, "doc/1/1/panes").split.panes.length, 2);
  assert.equal(find(withoutMedia, "doc/1/1/drive/media"), undefined);
  view.documents[1].state = {
    document: "script", status: 2,
    data: { kind: "desktop", powered: false, card: true, cartridge: true },
    actions: [{ id: "power" }, { id: "eject_id" }, { id: "eject_cartridge" }, { id: "close" }],
  };
  const off = vm.render(view);
  assert.equal(find(off, "doc/1/1/panes"), undefined);
  assert.equal(find(off, "doc/1/1/wallpaper"), undefined);
  assert.ok(find(off, "doc/1/1/eject_cartridge"));
  assert.equal(find(off, "doc/1/1/power").label, "lunatic/tfs:ui.desktop.power_on");
  // Two full stores and a long Markdown reader stay inside the 2048-node
  // tree budget: the reader yields to the drives rather than fault the desktop.
  const crowded = vm.render(full);
  assert.ok(crowded, "two full stores plus a long reader still validate");
  assert.ok(ids(crowded).length <= 2048);
  assert.ok(find(crowded, "doc/1/1/reader/content/truncated"), "the reader says what it left out");
  assert.ok(ids(crowded).filter((id) => id.startsWith("doc/1/1/reader/content/line/")).length >= 32, "the reader still shows something");
} finally {
  vm.dispose();
}
console.log("Laptop desktop: 25 pinned-interpreter checks passed");
