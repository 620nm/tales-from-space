// The floating HUD's palette and the shorthands its rules are spelled
// with. One home for the colours `theme-hud.ts` and `theme-hud-doc.ts`
// both paint from (docs/pack-ui/styles.md).
export const ink = "#d4dfdb";
export const dim = "#93a5a6";
export const teal = "#91c9b6";
export const amber = "#dcc18a";
export const amberLine = "#b39c67";
export const face = "#2c383d";
export const faceLine = "#4b5657";
export const titleFace = "#25373b";
export const titleLine = "#54716b";

export const edge = (color: string, width = 1) =>
  ({ width, style: "solid", color }) as const;
export const none = { width: 0, style: "none", color: "transparent" } as const;
export const flat: { x: number; y: number; blur: number; color: string }[] = [];
// The 1px black outline every bare HUD word needs over a lit floor.
export const outline = [
  { x: -1, y: 0, blur: 0, color: "#000000" },
  { x: 1, y: 0, blur: 0, color: "#000000" },
  { x: 0, y: -1, blur: 0, color: "#000000" },
  { x: 0, y: 1, blur: 0, color: "#000000" },
];
// A press inside a click-through group claims the pointer back.
export const press = { pointerEvents: "auto" } as const;
