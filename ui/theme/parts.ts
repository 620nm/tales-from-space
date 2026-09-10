// The shapes every rule is built out of: an edge, a ring, a drop, the
// text outline, and the press that claims the pointer back.
import type { StyleValue } from "@lunatic/ui";
import { alpha, black } from "./tokens";

export const edge = (color: string, width = 1) =>
  ({ width, style: "solid", color }) as const;
export const none = { width: 0, style: "none", color: "transparent" } as const;
export const shade = [{ x: 0, y: 3, blur: 12, spread: 0, color: alpha(black, 0.44) }];
export const sunk = [{ x: 0, y: 1, blur: 2, color: black }];
export const ring = (color: string, spread: number) => [
  { x: 0, y: 0, blur: 0, spread, color },
];
/** A 1px line inside one edge of the padding box: an edge a state turns
 *  on without moving anything (docs/pack-ui/box-model.md). */
export const insetLine = (side: "left" | "bottom", color: string) => [
  { x: side === "left" ? 1 : 0, y: side === "bottom" ? -1 : 0, blur: 0, spread: 0, color, inset: true },
];
// An empty shadow list renders `none`: how a later rule cancels an earlier.
export const flat: StyleValue[] = [];
// The 1px black text outline BYOND draws with `-dm-text-outline`, and the
// only thing that holds a bare HUD word together over a lit floor.
export const stroke = [
  { x: -1, y: 0, blur: 0, color: black },
  { x: 1, y: 0, blur: 0, color: black },
  { x: 0, y: -1, blur: 0, color: black },
  { x: 0, y: 1, blur: 0, color: black },
];
// A press inside a click-through group has to claim the pointer back.
export const press = { pointerEvents: "auto" } as const;
/** A sprite drawn at one atlas cell. */
export const sprite = { width: 32, height: 32, flexShrink: 0, imageRendering: "pixelated", pointerEvents: "none" } as const;
/** A layer stretched over its parent's padding box. */
export const cover = { position: "absolute", left: 0, top: 0, width: "100%", height: "100%" } as const;
