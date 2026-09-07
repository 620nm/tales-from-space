import type { UiNode } from "@lunatic/ui";
import { panel, row, text } from "./view";
import * as S from "./strings";

/** Compact input glyphs use the same origin as the composed preview above. */
export function gesture(id: string, name: string): UiNode {
  const modifiers = name === "ctrl_shift" ? ["ctrl", "shift"] : name === "alt" ? ["alt"] : name === "examine" ? ["shift"] : [];
  const children = modifiers.map((key) => text(`${id}/${key}`, S.tfs(`ui.key.${key}`), ["hover-key"]));
  if (name === "self") children.push(text(`${id}/self`, S.tfs("ui.key.self"), ["hover-key"]));
  else children.push(panel(`${id}/mouse`, [
    panel(`${id}/mouse/button`, [], { style: { position: "absolute", top: 1, left: name === "secondary" ? 6 : 1, width: 4, height: 5, backgroundColor: "#b9d2ca", borderRadius: 1 } }),
  ], { cls: ["mouse-glyph"] }));
  return row(id, children, { style: { gap: 3, alignItems: "center" } });
}
