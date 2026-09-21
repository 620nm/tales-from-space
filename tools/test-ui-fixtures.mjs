// Every fixture this pack ships renders in the pinned interpreter: the
// primary package and each addon the view wakes answer a tree the contract
// accepts, with no id used twice, and clean under the layout lint (the
// engine's docs/pack-ui/lab.md and docs/pack-ui/authoring-lint.md).
import assert from "node:assert/strict";
import {
  assertLintClean, assertUniqueIds, createGuest, engineModule, lintModule,
  packRoot, readBundle, reportSkip,
} from "./ui-runtime-harness.mjs";

const { addonsFor, loadFixtures } = await engineModule("tools/ui-lab/fixtures.mjs");
const { readUiDeclaration } = await engineModule("tools/stage-pack-ui.mjs");

const ui = readUiDeclaration(packRoot, { fallback: true });
if ((ui.entry === undefined) !== (ui.bundle === undefined))
  throw Error("ui.entry and ui.bundle must be declared together");
const hasStaff = ui.staff_entry !== undefined || ui.staff_bundle !== undefined;
if (hasStaff && (ui.staff_entry === undefined || ui.staff_bundle === undefined))
  throw Error("ui.staff_entry and ui.staff_bundle must be declared together");
const skips = [];
let tests = 0;
if (!ui.bundle) {
  skips.push("no built pack UI (fix: xtask build-ui)");
} else {
  const primary = await readBundle(ui.bundle);
  if (!primary && !ui.fallback)
    throw Error(`declared UI bundle ${ui.bundle} is not built (fix: xtask build-ui)`);
  if (!primary) skips.push("no built pack UI (fix: xtask build-ui)");
  else {
    const ordinary = await checkFixtures(primary, "ordinary");
    tests += ordinary.tests;
    if (ordinary.skipped) skips.push(ordinary.skipped);
  }
}
if (hasStaff) {
  const staff = await readBundle(ui.staff_bundle);
  if (!staff)
    throw Error(`declared staff UI bundle ${ui.staff_bundle} is not built (fix: xtask build-ui)`);
  if (staff.audience !== "staff" || staff.slot !== "staff")
    throw Error("declared staff UI bundle must use the staff audience and slot");
  const checked = await checkFixtures(staff, "staff");
  tests += checked.tests;
  if (checked.skipped) skips.push(checked.skipped);
}
for (const reason of skips) reportSkip(`pack fixture checks: ${reason}`);
console.log(`Shipped fixtures: ${tests} rendered clean in the pinned interpreter`);

async function checkFixtures(primary, audience) {
  const rows = await loadFixtures(packRoot, { audience });
  if (rows.length === 0)
    return { tests: 0, skipped: `the ${audience} package ships no ${audience === "staff" ? "ui/staff/fixtures" : "ui/fixtures"}` };
  const ordinary = audience === "ordinary";
  const extensions = ordinary ? (await readBundle("ui/extensions.json")) ?? [] : [];
  const { lintTree } = await lintModule();
  const vm = await createGuest(primary);
  const addons = new Map();
  let checked = 0;
  try {
    for (const fixture of rows) {
      // `render` validates before it answers, so an accepted tree is the
      // assertion: nothing over a limit, nothing the contract refuses.
      const tree = vm.render(fixture.view);
      assert.ok(tree, `${audience} fixture ${fixture.name}: the primary renders a tree`);
      assertUniqueIds(tree, `${audience} fixture ${fixture.name}`);
      assertLintClean(lintTree, tree, primary, `${audience} fixture ${fixture.name}`);
      for (const row of addonsFor(primary, extensions, fixture.view)) {
        if (!addons.has(row.bundle)) {
          const bundle = await readBundle(row.bundle);
          assert.ok(bundle, `${audience} fixture ${fixture.name}: addon ${row.bundle} is not built`);
          addons.set(row.bundle, { bundle, vm: await createGuest(bundle) });
        }
        const addon = addons.get(row.bundle);
        const where = `${audience} fixture ${fixture.name}, addon ${row.slot}`;
        const rendered = addon.vm.render(fixture.view);
        assertUniqueIds(rendered, where);
        assertLintClean(lintTree, rendered, addon.bundle, where);
      }
      checked++;
    }
  } finally {
    vm.dispose();
    for (const addon of addons.values()) addon.vm.dispose();
  }
  return { tests: checked };
}
