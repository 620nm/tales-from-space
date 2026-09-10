// What the overlay package draws: the hover card the cursor drags
// around and the mouse glyph in each of its rows. The menu over a tile
// is built out of `kit.ts` and needs nothing of its own.
import type { UiStyleRule } from "@lunatic/ui";
import { rule } from "@lunatic/ui";
import { edge, flat, none, shade, sunk } from "./parts";
import { alpha, amber, dim, face, faint, ink, line, red, surface, teal, titleFace, titleLine } from "./tokens";

export const overlayRules: UiStyleRule[] = [
  // The overlay's root covers the whole viewport and shows the station
  // through: only the two surfaces inside it take the pointer back.
  rule("overlay", {
    position: "relative", width: "100%", height: "100%", padding: 0, gap: 0, maxWidth: "100%",
    backgroundColor: "transparent", border: none, borderRadius: 0, boxShadow: flat, overflow: "hidden", pointerEvents: "none",
  }),

  // The hover card. Sans, translucent, click-through: it is a reading of
  // what is under the cursor, never a thing to press.
  rule("hover-card", {
    minWidth: 0, maxWidth: 520, gap: 5, paddingTop: 9, paddingBottom: 9, paddingLeft: 10, paddingRight: 10,
    backgroundColor: alpha(surface, 0.93), border: edge(line), borderRadius: 3, boxShadow: shade, overflow: "hidden",
    fontFamily: "sans", fontSize: 11, lineHeight: 1.35, color: ink, textShadow: sunk, userSelect: "none", pointerEvents: "none",
  }),
  rule("hover-head", { alignItems: "center", gap: 6, minWidth: 0, marginBottom: 2 }),
  rule("hover-preview", { width: 32, height: 32, flexShrink: 0, imageRendering: "pixelated", pointerEvents: "none" }),
  rule("hover-title", { minWidth: 0, fontSize: 12, fontWeight: 700, whiteSpace: "normal" }),
  // Two tracks, so the left cell of every hint starts exactly where the
  // header's icon starts; the card sizes the shared first track for its
  // widest input/item combination.
  rule("hover-actions", { display: "grid", gridTemplateColumns: ["auto", "1fr"], alignItems: "center", gap: 8 }),
  rule("hover-row", { minWidth: 0, gap: 2, whiteSpace: "normal" }),
  rule("hover-group", { color: dim, fontSize: 10, marginTop: 4 }),
  rule("hover-unavailable", { color: faint, opacity: 0.6 }),
  rule("hover-role", { color: red }),
  rule("hover-danger", { color: red }),
  rule("hover-construction", { color: amber }),
  rule("hover-requirement", { color: dim, fontSize: 10, whiteSpace: "normal" }),
  rule("hover-keys", { display: "flex", alignItems: "center", justifyContent: "start", gap: 4, minHeight: 20, minWidth: 0, flexWrap: "wrap", maxWidth: 240 }),
  rule("hover-combination-plus", { width: 8, flexShrink: 0, textAlign: "center" }),
  rule("hover-accessible", { position: "absolute", width: 1, height: 1, overflow: "hidden" }),
  rule("hover-implement", { width: 32, height: 32, flexShrink: 0, imageRendering: "pixelated", pointerEvents: "none" }),
  // A floor under the pill, so "Alt" and "Shift" leave the same gap
  // before the mouse whichever word a language uses.
  rule("hover-key", {
    fontFamily: "sans", fontSize: 9, lineHeight: 1.4, minWidth: 0, whiteSpace: "normal",
    paddingTop: 1, paddingBottom: 1, paddingLeft: 4, paddingRight: 4,
    color: ink, backgroundColor: face, textAlign: "center",
    border: edge(titleLine), borderBottom: edge(titleLine, 2), borderRadius: 2,
  }),
  // Two keys and a mouse in one rail: the pills give back what the
  // second one costs.
  rule("hover-key-tight", { fontSize: 8, minWidth: 20, paddingLeft: 3, paddingRight: 3 }),
  rule("hover-description", { minWidth: 0, fontSize: 11, color: ink, whiteSpace: "normal" }),
  // A mouse in fourteen by twenty pixels: a bordered body and the three
  // buttons at 1, 5 and 9, of which the gesture's own is lit.
  rule("mouse-glyph", { position: "relative", width: 14, height: 20, flexShrink: 0, border: edge(teal), borderRadius: 4, backgroundColor: titleFace, pointerEvents: "none" }),
  rule("mouse-key", { position: "absolute", top: 2, width: 3, height: 6, backgroundColor: titleLine }),
  rule("mouse-key-on", { backgroundColor: amber }),
];
