// The chrome every package of this pack wears: the kit's defaults, then
// the frame, the typed controls and the row vocabulary the HUD and the
// overlay both draw with. One home for the shapes two sheets share, so
// a repaint of a press lands on every press the station has.
import type { UiStyleRule } from "@lunatic/ui";
import { rule, theme } from "@lunatic/ui";
import {
  amber, amberLine, bright, dim, edge, face, faceLine, faint, field, ink,
  line, press, ring, rule_line, shade, teal,
} from "./theme-tokens";

const paneBack = "#132226f2";
const inner = "#0f1c20cc";

export const baseRules: UiStyleRule[] = [
  ...theme,

  // The frame every floating surface wears: one flat fill, one hairline,
  // one soft drop. No gradient, because the grammar has none and the
  // look does not want one.
  rule("pane", {
    fontFamily: "sans",
    fontSize: 12,
    lineHeight: 1.4,
    color: ink,
    gap: 6,
    padding: 8,
    minWidth: 200,
    maxWidth: 560,
    backgroundColor: paneBack,
    border: edge(line),
    borderRadius: 3,
    boxShadow: shade,
    overflow: "auto",
    pointerEvents: "auto",
  }),
  rule("titlebar", {
    alignItems: "center",
    justifyContent: "space-between",
    gap: 8,
    paddingBottom: 5,
    marginBottom: 4,
    borderBottom: edge(rule_line),
  }),
  rule("titlebar-title", { color: bright, fontSize: 12, fontWeight: 700 }),
  rule("titlebar-close", { color: dim }),
  rule("section", { gap: 4, marginTop: 8 }),
  rule("section-title", {
    color: dim, fontFamily: "mono", fontSize: 9, fontWeight: 700,
    textTransform: "uppercase", letterSpacing: 1,
    paddingBottom: 2, borderBottom: edge(rule_line),
  }),
  rule("list-row", { paddingTop: 3, paddingBottom: 3, borderBottom: edge(rule_line) }),
  rule("list-label", { color: dim, fontSize: 11 }),
  rule("list-value", { color: ink, fontSize: 11, fontWeight: 700 }),
  rule("notice", { color: teal, fontStyle: "normal", fontSize: 11 }),
  rule("choice-grid", { gap: 4 }),

  // Typed controls and presses: a flat face, a hairline, a 2px corner.
  // One system, stated once, so nothing later has to undo half of it.
  rule("btn", {
    paddingTop: 4, paddingBottom: 4, paddingLeft: 8, paddingRight: 8,
    fontSize: 11, color: ink,
    backgroundColor: face, border: edge(faceLine), borderRadius: 2,
    cursor: "pointer",
    transition: [{ property: "backgroundColor", ms: 120 }],
    ...press,
  }),
  rule("btn", { backgroundColor: "#3a4a4b", color: bright }, "hover"),
  rule("btn", { opacity: 0.45, cursor: "not-allowed" }, "disabled"),
  rule("btn", { boxShadow: ring(amber, 2) }, "focus"),
  rule("btn-default", { color: ink, backgroundColor: face, border: edge(faceLine) }),
  rule("btn-primary", { color: amber, backgroundColor: face, border: edge(amberLine) }),
  rule("btn-danger", { color: "#e0968a", backgroundColor: face, border: edge("#8a5a50") }),
  rule("btn-ghost", { color: dim, backgroundColor: "transparent", border: edge("transparent") }),
  rule("btn-ghost", { color: ink, backgroundColor: "#28383b" }, "hover"),
  rule("btn-selected", { color: "#d5eadf", backgroundColor: "#354d46", border: edge(teal) }),
  rule("btn-selected", { backgroundColor: "#40655a" }, "hover"),
  rule("entry", {
    flexGrow: 1, minWidth: 0, color: ink, fontSize: 11,
    backgroundColor: field, border: edge(line), borderRadius: 2,
    paddingTop: 4, paddingBottom: 4, paddingLeft: 6, paddingRight: 6,
    ...press,
  }),
  rule("entry", { border: edge(teal) }, "focus"),
  rule("num", { flexGrow: 0, width: 88, textAlign: "right" }),
  rule("area", {
    width: "100%", minHeight: 220, color: ink,
    fontFamily: "mono", fontSize: 11, lineHeight: 1.45,
    backgroundColor: field, border: edge(line), borderRadius: 2,
    paddingTop: 5, paddingBottom: 5, paddingLeft: 6, paddingRight: 6,
    userSelect: "text",
    ...press,
  }),
  rule("area", { border: edge(teal) }, "focus"),

  // pointer-events inherits, so a press in a group the station shows
  // through hands every click to the floor unless it says otherwise.
  rule("choice-hit", press),
  rule("card", { gap: 5, padding: 8, backgroundColor: inner, border: edge(rule_line), borderRadius: 3 }),
  rule("hint", { color: dim, fontSize: 11, fontStyle: "italic" }),
  rule("marker", { color: amber, fontSize: 11 }),
  rule("grow", { flexGrow: 1, minWidth: 0 }),
  rule("right", { textAlign: "right" }),
  rule("mono", { fontFamily: "mono" }),
  rule("icon", { width: 32, height: 32, flexShrink: 0, imageRendering: "pixelated", pointerEvents: "none" }),

  // A row naming one thing, with its picture: a shelf line, a file, and
  // what stands on the tile under the cursor.
  rule("filerow", { alignItems: "center", gap: 4 }),
  rule("fname", { flexGrow: 1, minWidth: 0, textAlign: "left" }),
  rule("fsize", { color: faint, fontSize: 10, flexShrink: 0 }),
  rule("fopen", { color: teal, border: edge("#4f7a6c") }),
  rule("pname", { color: ink, fontSize: 12, textAlign: "left" }),
  rule("stock", { color: dim, fontSize: 11, textAlign: "right" }),
];
