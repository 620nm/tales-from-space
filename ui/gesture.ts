import type { UiNode } from "@lunatic/ui";
import { panel, row, text } from "./view";
import * as S from "./strings";

/** Compact input glyphs use the same origin as the composed preview above. */
export function gesture(id: string, name: string): UiNode {
  const modifiers = name === "ctrl_shift" ? ["ctrl", "shift"] : name === "alt" ? ["alt"] : name === "examine" ? ["shift"] : [];
  const children = modifiers.map((key) => text(`${id}/${key}`, S.tfs(`ui.key.${key}`), ["hover-key"]));
  if (name === "self") children.push(text(`${id}/self`, S.tfs("ui.key.self"), ["hover-key"]));
  else {
    // Both buttons are drawn and the gesture's own one is lit, so a
    // glance says which side of the mouse the verb is on.
    const right = name === "secondary";
    children.push(panel(`${id}/mouse`, [
      panel(`${id}/mouse/left`, [], {
        cls: right ? ["mouse-key"] : ["mouse-key", "mouse-key-on"],
        style: { left: 1 },
      }),
      panel(`${id}/mouse/right`, [], {
        cls: right ? ["mouse-key", "mouse-key-on"] : ["mouse-key"],
        style: { right: 1 },
      }),
    ], { cls: ["mouse-glyph"] }));
  }
  return row(id, children, { cls: ["hover-keys"] });
}
