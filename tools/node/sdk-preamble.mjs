import assert from "node:assert/strict";
import { loadEnglishLocale } from "../ui-runtime-harness.mjs";

const outcomes = [];
Object.defineProperty(globalThis, "__lunaticRecordLabelOutcomes", {
  value: (...reasons) => { outcomes.push(...reasons); },
});
globalThis.__lunaticLocale = await loadEnglishLocale();

/** Check and consume the outcomes a direct SDK test expects. */
export function assertLabelOutcomes(expected) {
  assert.deepEqual(outcomes, expected, "unexpected direct SDK label outcomes");
  outcomes.length = 0;
}
process.once("exit", () => assertLabelOutcomes([]));
