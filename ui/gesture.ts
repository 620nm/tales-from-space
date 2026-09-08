// The one place a gesture id is read. An id is `[<modifiers>_]<button>`
// with the modifiers in the engine's fixed spelling, and its rank is
// `group * 3 + button` — the same number the server sorts hint rows by
// (lunatic docs/luau-api/click.md, "Declared item gestures").
import type { UiNode } from "@lunatic/ui";
import { panel, row, text } from "./view";
import * as S from "./strings";

const GROUPS = ["", "shift", "ctrl", "alt", "shift_ctrl", "shift_alt", "ctrl_alt"];
const BUTTONS = ["primary", "secondary", "middle"];
/** Where each button sits on the glyph: the middle one is drawn between
 *  its neighbours, and ranks after them. */
const SQUARE = [0, 2, 1];

export type Gesture = { id: string; keys: string[]; button: number; rank: number };

/** The id as its keys, its button and its rank, or null for a name that
 *  is no pointer slot: `self`, or a spelling nothing declares. */
export function parse(id: string): Gesture | null {
  const parts = id.split("_");
  const button = BUTTONS.indexOf(parts[parts.length - 1] ?? "");
  if (button < 0) return null;
  const group = GROUPS.indexOf(parts.slice(0, -1).join("_"));
  if (group < 0) return null;
  return {
    id,
    keys: group > 0 ? GROUPS[group]!.split("_") : [],
    button,
    rank: group * 3 + button,
  };
}

/** The gesture a slot press means: the button from the event's kind, the
 *  keys from its flags. Three modifiers at once name no slot. */
export function fromEvent(
  e: { type: string; alt?: boolean; ctrl?: boolean; shift?: boolean },
): Gesture | null {
  const button = e.type === "activate" ? "primary"
    : e.type === "context" ? "secondary"
      : e.type === "middle" ? "middle" : null;
  if (!button) return null;
  const keys = [e.shift ? "shift" : "", e.ctrl ? "ctrl" : "", e.alt ? "alt" : ""];
  return parse([...keys.filter((key) => key !== ""), button].join("_"));
}

/** Where a row sits in the card: the bare click, then the use key, then
 *  every pointer gesture by rank — the order the server already sent. */
export function order(name: string): number {
  if (name === "primary") return 0;
  if (name === "self") return 1;
  return 2 + (parse(name)?.rank ?? 0);
}

/** How many keys a row's rail must fit. The card sizes one rail off the
 *  widest row and gives it to every row, so the left edges stay one edge. */
export function modifierCount(name: string): number {
  return parse(name)?.keys.length ?? 0;
}

/** Compact input glyphs use the same origin as the composed preview above.
 *  `tight` narrows the pills for a card whose widest row holds two keys. */
export function gesture(id: string, name: string, tight = false): UiNode {
  const keyCls = tight ? ["hover-key", "hover-key-tight"] : ["hover-key"];
  const shape = parse(name);
  const children = (shape?.keys ?? [])
    .map((key) => text(`${id}/${key}`, S.tfs(`ui.key.${key}`), keyCls));
  if (!shape) children.push(text(`${id}/self`, S.tfs("ui.key.self"), keyCls));
  else {
    // All three buttons are drawn and the gesture's own one is lit, so a
    // glance says which part of the mouse the verb is on.
    const lit = SQUARE[shape.button];
    children.push(panel(`${id}/mouse`, ["left", "middle", "right"].map((side, index) =>
      panel(`${id}/mouse/${side}`, [], {
        cls: index === lit ? ["mouse-key", "mouse-key-on"] : ["mouse-key"],
        style: { left: 1 + index * 4 },
      })), { cls: ["mouse-glyph"] }));
  }
  return row(id, children, { cls: ["hover-keys"] });
}
