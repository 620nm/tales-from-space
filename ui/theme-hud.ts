// The floating HUD over the station: the hand cluster, the worn grid,
// the target block, the storage tray, and — through `theme-hud-doc.ts` —
// the surfaces a document opens in. These rules append after
// `theme.ts`'s, so each is the last word on its class.
import { rule } from "@lunatic/ui";
import { docRules } from "./theme-hud-doc";
import { amber, amberLine, dim, edge, flat, ink, none, outline, press, teal } from "./theme-tokens";

export const hudRules = [
  // The hand cluster: two 60x61 cells over a row of compact controls.
  rule("hand-cluster", { gap: 4, pointerEvents: "none" }),
  rule("hand-slot", {
    width: 60,
    height: 61,
    backgroundColor: "#1e2b2fe8",
    border: none,
    borderRadius: 0,
    boxShadow: [{ x: 0, y: 0, blur: 0, spread: 2, color: "#142126", inset: true }],
  }),
  rule("slot-active", {
    border: edge(amber),
    backgroundColor: "#4a483584",
    boxShadow: [{ x: 0, y: 0, blur: 0, spread: 2, color: "#504632", inset: true }],
  }),
  rule("hand-actions", { gap: 3, height: 20, pointerEvents: "none" }),
  rule("hand-action", {
    position: "relative",
    flexGrow: 1,
    height: 20,
    alignItems: "center",
    justifyContent: "center",
    gap: 3,
    backgroundColor: "#1f2e31db",
    border: edge("#667173"),
    borderRadius: 2,
    overflow: "hidden",
  }),
  rule("hand-action", { backgroundColor: "#2c4145e8" }, "hover"),
  rule("hand-action-on", { backgroundColor: "#4a483584", border: edge(amber) }),
  rule("hud-glyph", { fontFamily: "mono", fontSize: 11, lineHeight: 1, color: ink }),
  rule("hud-cap", {
    fontFamily: "mono",
    fontSize: 6,
    lineHeight: 1,
    letterSpacing: 1,
    textTransform: "uppercase",
    color: "#b3c3b7",
  }),
  // The transparent press stretched over a box that draws itself.
  rule("hud-hit", {
    position: "absolute",
    left: 0,
    top: 0,
    width: "100%",
    height: "100%",
    padding: 0,
    backgroundColor: "transparent",
    border: none,
    borderRadius: 0,
    boxShadow: flat,
    cursor: "pointer",
    ...press,
  }),

  // The worn grid and its stationary toggle.
  rule("slot-label", {
    fontFamily: "mono",
    fontSize: 7,
    lineHeight: 1.2,
    maxHeight: 9,
    letterSpacing: 1,
    textTransform: "uppercase",
    color: "#b5c6b5",
    backgroundColor: "transparent",
    textShadow: outline,
  }),
  // The edge belongs to the PRESS, not to the box behind it. An
  // absolutely placed child fills its parent's PADDING box, so a border
  // out here leaves the pressable node two pixels short of the square a
  // player aims at. The box stays bare; the press is the 40 and draws
  // the edge, so what is hit and what is seen are one rectangle.
  rule("worn-toggle", {
    position: "relative",
    width: 40,
    height: 40,
    minWidth: 40,
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    gap: 2,
    padding: 0,
    backgroundColor: "#20394ee8",
    border: none,
    borderRadius: 0,
    overflow: "hidden",
  }),
  rule("worn-on", { backgroundColor: "#315673ed" }),
  rule("worn-hit", { border: edge("#5280ac"), borderRadius: 0 }),
  rule("worn-hit-on", { border: edge("#b2d7ff") }),
  rule("worn-glyph", { fontFamily: "mono", fontSize: 18, lineHeight: 1, color: "#a4c4df" }),
  rule("worn-cap", {
    fontFamily: "mono",
    fontSize: 7,
    lineHeight: 1,
    letterSpacing: 1,
    textTransform: "uppercase",
    color: "#a4c4df",
  }),

  // The target block: the figure, a reserved pill slot and one status line.
  rule("target-meta", { gap: 7, alignItems: "center" }),
  rule("target-reserve", {
    width: 56,
    maxWidth: 56,
    height: 28,
    backgroundColor: "transparent",
    border: none,
    borderRadius: 0,
    boxShadow: flat,
  }),
  rule("status-row", { alignItems: "center", gap: 4 }),
  rule("target-status", {
    alignItems: "start",
    gap: 1,
    whiteSpace: "nowrap",
    justifyContent: "end",
    fontFamily: "mono",
    fontSize: 8,
    letterSpacing: 1,
    color: "#b5d5bc",
    textShadow: outline,
  }),
  rule("status-dot", { color: teal, fontFamily: "mono", fontSize: 8 }),
  rule("status-key", { color: dim, fontFamily: "mono", fontSize: 8, textTransform: "uppercase" }),

  // The storage tray, the one amber-framed surface.
  rule("storage-window", {
    padding: 0,
    gap: 0,
    minWidth: 0,
    maxWidth: "100%",
    backgroundColor: "#22302fe8",
    border: edge(amberLine),
    borderRadius: 4,
    overflow: "hidden",
  }),
  rule("storage-head", {
    height: 23,
    alignItems: "center",
    gap: 8,
    paddingLeft: 7,
    paddingRight: 7,
    fontFamily: "mono",
    fontSize: 9,
    color: "#ddc99e",
  }),
  rule("storage-count", {
    marginLeft: "auto",
    fontFamily: "mono",
    fontSize: 9,
    color: "#a4b19f",
  }),
  rule("storage-grid", {
    display: "grid",
    gridTemplateColumns: { repeat: 7, min: 40, max: 40 },
    gap: 4,
    paddingLeft: 7,
    paddingRight: 7,
    paddingBottom: 8,
  }),
  ...docRules,
];
