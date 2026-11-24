import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

// PACK_LANES is hand-kept and the selector validates only against
// itself, so a lane named there with no reporting call would select
// green, and a reporting call with no PACK_LANES entry could never
// be selected. Keep the two lists one list.
const gate = await readFile(
  process.env.PACK_CHECK_SH ?? new URL("./check.sh", import.meta.url),
  "utf8",
);

const listed = gate.match(/^PACK_LANES="([^"]*)"$/m)?.[1].split(/\s+/).filter(Boolean);
assert(listed, "tools/check.sh declares PACK_LANES");

const reported = new Set();
for (const line of gate.split("\n")) {
  if (/^\s*#/.test(line)) continue;
  const call =
    line.match(/^\s*(?:elif\s+|if\s+)?run\s+([a-z][a-z0-9-]*)\s/) ??
    line.match(/\)\s*run\s+([a-z][a-z0-9-]*)\s/) ??
    line.match(/^\s*gated\s+"[^"]*"\s+([a-z][a-z0-9-]*)\s/) ??
    line.match(/^\s*(?:blocked|skip|lane_skip)\s+([a-z][a-z0-9-]*)\s/);
  if (call) reported.add(call[1]);
}

test("PACK_LANES names every lane the gate reports, and no other", () => {
  assert.equal(new Set(listed).size, listed.length, "PACK_LANES has no duplicate");
  assert.deepEqual(
    [...reported].sort(),
    [...listed].sort(),
    "the lanes lane_pack reports and the lanes PACK_LANES selects are one set",
  );
});
