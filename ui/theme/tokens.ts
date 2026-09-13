// The station's palette: the only file under ui/ that spells a colour.
// Every other value is one of these, or one of these through `alpha`
// (tools/theme-lint.mjs). Flat fills only: the style grammar has no
// gradient, so the look is carried by value contrast and a hairline.

export const black = "#000000";
// Grounds, darkest first: a well, the computer's glass, a pane's back.
export const field = "#101b1f";
export const screen = "#101b23";
export const surface = "#132226";
export const titleFace = "#25373b";
export const face = "#2c383d";
export const raised = "#3a4a4b";
// Lines: the hairline inside a surface, a control's edge, a frame.
export const ruleLine = "#2b3a3e";
export const faceLine = "#4b5657";
export const line = "#526064";
export const titleLine = "#54716b";
// Inks, faintest first; `phosphor` is the computer screen's.
export const faint = "#7c958e";
export const dim = "#93a5a6";
export const ink = "#d4dfdb";
export const bright = "#e8efe9";
export const phosphor = "#cde9d4";
// Accents: the reading that is good, the mark that is yours, the harm.
export const teal = "#91c9b6";
export const amber = "#dcc18a";
export const amberLine = "#b39c67";
export const red = "#e0968a";
export const redLine = "#8a5a50";
// The worn-grid toggle's own blue.
export const skyFace = "#20394e";
export const skyLine = "#5280ac";
export const sky = "#a4c4df";
// Physical writing surfaces and their ink (docs/art-reference/README.md).
export const paper = "#f1ead4";
export const paperInk = "#202c2d";

/** A palette colour at a coverage, as the grammar's `#rrggbbaa`. */
export const alpha = (hex: string, coverage: number): string =>
  hex + Math.round(Math.max(0, Math.min(1, coverage)) * 255).toString(16).padStart(2, "0");
