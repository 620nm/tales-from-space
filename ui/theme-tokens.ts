// The station's palette and the four shapes every rule is built out of.
// Flat fills only: the style grammar has no gradient, no blur and no
// transform (docs/pack-ui/styles.md), so the look is carried by value
// contrast and one hairline instead.
import type { StyleValue } from "@lunatic/ui";

export const bg = "#11191d";
export const line = "#526064";
export const dim = "#93a5a6";
export const faint = "#7c958e";
export const ink = "#d4dfdb";
export const bright = "#e8efe9";
export const teal = "#91c9b6";
export const amber = "#dcc18a";
export const amberLine = "#b39c67";
export const face = "#2c383d";
export const faceLine = "#4b5657";
export const field = "#101b1f";
export const rule_line = "#2b3a3e";
export const titleFace = "#25373b";
export const titleLine = "#54716b";

export const edge = (color: string, width = 1) =>
  ({ width, style: "solid", color }) as const;
export const none = { width: 0, style: "none", color: "transparent" } as const;
export const shade = [{ x: 0, y: 3, blur: 12, spread: 0, color: "#00000070" }];
export const ring = (color: string, spread: number) => [
  { x: 0, y: 0, blur: 0, spread, color },
];
// An empty shadow list renders `none`: how a later rule cancels an earlier.
export const flat: StyleValue[] = [];
// The 1px black text outline BYOND draws with `-dm-text-outline`, and the
// only thing that holds a bare HUD word together over a lit floor.
export const stroke = [
  { x: -1, y: 0, blur: 0, color: "#000000" },
  { x: 1, y: 0, blur: 0, color: "#000000" },
  { x: 0, y: -1, blur: 0, color: "#000000" },
  { x: 0, y: 1, blur: 0, color: "#000000" },
];
// A press inside a click-through group has to claim the pointer back.
export const press = { pointerEvents: "auto" } as const;
