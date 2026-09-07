import type { UiNode } from "@lunatic/ui";
import { panel, row, text } from "./view";
import * as S from "./strings";

/** The keys each gesture holds down, in the order a hand presses them. */
const MODIFIERS: Record<string, string[]> = {
  ctrl_shift: ["ctrl", "shift"],
  alt: ["alt"],
  examine: ["shift"],
};

/** Which of the three buttons a gesture lights: left unless it says so. */
const BUTTON: Record<string, number> = { secondary: 2, middle: 1 };

/** How many keys a row's rail must fit. The card sizes one rail off the
 *  widest row and gives it to every row, so the left edges stay one edge. */
export function modifierCount(name: string): number {
  return (MODIFIERS[name] ?? []).length;
}

/** Compact input glyphs use the same origin as the composed preview above.
 *  `tight` narrows the pills for a card whose widest row holds two keys. */
export function gesture(id: string, name: string, tight = false): UiNode {
  const keyCls = tight ? ["hover-key", "hover-key-tight"] : ["hover-key"];
  const children = (MODIFIERS[name] ?? [])
    .map((key) => text(`${id}/${key}`, S.tfs(`ui.key.${key}`), keyCls));
  if (name === "self") children.push(text(`${id}/self`, S.tfs("ui.key.self"), keyCls));
  else {
    // All three buttons are drawn and the gesture's own one is lit, so a
    // glance says which part of the mouse the verb is on.
    const lit = BUTTON[name] ?? 0;
    children.push(panel(`${id}/mouse`, ["left", "middle", "right"].map((side, index) =>
      panel(`${id}/mouse/${side}`, [], {
        cls: index === lit ? ["mouse-key", "mouse-key-on"] : ["mouse-key"],
        style: { left: 1 + index * 4 },
      })), { cls: ["mouse-glyph"] }));
  }
  return row(id, children, { cls: ["hover-keys"] });
}
