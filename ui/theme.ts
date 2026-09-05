// The pack's stylesheet: the kit's defaults, then the rules that make
// these screens the station's own. Class names outside the kit's
// vocabulary are this pack's (docs/pack-ui/components.md); a later rule
// for the same class wins, so every override below appends.
import { defineStyles, rule, theme } from "@lunatic/ui";

const ink = "#d8def0";
const bright = "#e8ecfa";
const dim = "#9aa3c0";
const faint = "#7f879f";
const line = "#3a3f55";
const rule_line = "#242a3e";
const face = "#232839";
const raised = "#303751";
const field = "#14172a";
const accent = "#ff6eb4";
const info = "#8fb4ff";
const good = "#7fd18c";
const paneBack = "#0e101af2";
const inner = "#141828cc";
const innerLine = "#262c42";

const edge = (color: string, width = 1) =>
  ({ width, style: "solid", color }) as const;
const none = { width: 0, style: "none", color: "transparent" } as const;
const drop = [{ x: 0, y: 6, blur: 18, spread: 0, color: "#00000073" }];

export default defineStyles([
  ...theme,
  // The frame every floating surface wears.
  rule("pane", {
    fontFamily: "sans",
    fontSize: 12,
    lineHeight: 1.35,
    color: ink,
    gap: 6,
    padding: 10,
    minWidth: 200,
    maxWidth: 560,
    backgroundColor: paneBack,
    border: edge(line),
    borderRadius: 8,
    boxShadow: drop,
    overflow: "auto",
    pointerEvents: "auto",
  }),
  rule("titlebar", {
    alignItems: "center",
    justifyContent: "space-between",
    gap: 8,
    paddingBottom: 6,
    marginBottom: 4,
    borderBottom: edge(line),
  }),
  rule("titlebar-title", {
    color: bright,
    fontSize: 12,
    fontWeight: 700,
    letterSpacing: 0.3,
  }),
  rule("section", { gap: 4, marginTop: 8 }),
  rule("list-row", {
    paddingTop: 3,
    paddingBottom: 3,
    borderBottom: edge(rule_line),
  }),
  rule("list-label", { fontSize: 11 }),
  rule("list-value", { fontSize: 11, fontWeight: 700 }),
  rule("notice", { color: info, fontStyle: "normal", fontSize: 11 }),
  rule("choice-grid", { gap: 4 }),
  rule("cell", { justifyContent: "center", paddingTop: 2, paddingBottom: 2 }),

  // The root: a transparent sheet the station shows through.
  rule("hud", {
    position: "relative",
    width: "100%",
    height: "100%",
    padding: 0,
    gap: 0,
    maxWidth: "100%",
    backgroundColor: "transparent",
    border: none,
    borderRadius: 0,
    boxShadow: [{ x: 0, y: 0, blur: 0, spread: 0, color: "transparent" }],
    overflow: "hidden",
    pointerEvents: "none",
  }),
  rule("dock", { gap: 10 }),
  rule("card", {
    gap: 5,
    padding: 8,
    backgroundColor: inner,
    border: edge(innerLine),
    borderRadius: 6,
  }),
  rule("hint", { color: dim, fontSize: 11, fontStyle: "italic" }),
  rule("grow", { flexGrow: 1, minWidth: 0 }),
  rule("right", { textAlign: "right" }),
  rule("mono", { fontFamily: "mono" }),
  rule("icon", {
    width: 32,
    height: 32,
    flexShrink: 0,
    imageRendering: "pixelated",
    pointerEvents: "none",
  }),
  rule("caption", {
    color: faint,
    fontSize: 9,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: 0.6,
  }),

  // The tray: hands and worn slots over the station's bottom edge.
  rule("tray", { alignItems: "end", gap: 8 }),
  rule("trayset", { gap: 4 }),
  rule("chip", {
    alignItems: "center",
    gap: 5,
    paddingTop: 2,
    paddingBottom: 2,
    paddingLeft: 7,
    paddingRight: 7,
    backgroundColor: field,
    border: edge(innerLine),
    borderRadius: 10,
  }),
  rule("chipkey", {
    color: dim,
    fontSize: 9,
    textTransform: "uppercase",
    letterSpacing: 0.4,
  }),
  rule("chipval", { color: ink, fontSize: 11, fontWeight: 700 }),

  // The target figure: one atlas cell, aimed at by its own rectangles.
  rule("doll", {
    position: "relative",
    width: 32,
    height: 32,
    flexShrink: 0,
    backgroundColor: "#04050ab8",
    border: edge(line),
    borderRadius: 4,
  }),
  rule("dollart", {
    position: "absolute",
    left: 0,
    top: 0,
    width: 32,
    height: 32,
    pointerEvents: "none",
  }),
  rule("dollhit", {
    position: "absolute",
    padding: 0,
    backgroundColor: "transparent",
    border: none,
    borderRadius: 2,
    cursor: "pointer",
  }),
  rule("dollhit", { backgroundColor: "#ff6eb440" }, "hover"),
  rule("dollon", { backgroundColor: "#ff6eb42e", border: edge(accent) }),

  // Typed controls. The kit styles the press, never the box beside it.
  rule("entry", {
    flexGrow: 1,
    minWidth: 0,
    color: ink,
    fontSize: 11,
    backgroundColor: field,
    border: edge(line),
    borderRadius: 4,
    paddingTop: 3,
    paddingBottom: 3,
    paddingLeft: 5,
    paddingRight: 5,
  }),
  rule("entry", { border: edge("#6f7aa8") }, "focus"),
  rule("num", { flexGrow: 0, width: 88, textAlign: "right" }),
  rule("area", {
    width: "100%",
    minHeight: 220,
    color: ink,
    fontFamily: "mono",
    fontSize: 11,
    lineHeight: 1.4,
    backgroundColor: field,
    border: edge(line),
    borderRadius: 4,
    paddingTop: 5,
    paddingBottom: 5,
    paddingLeft: 6,
    paddingRight: 6,
    userSelect: "text",
  }),

  // Comms.
  rule("log", { gap: 2, overflowY: "auto" }),
  rule("line", { alignItems: "start", gap: 5, flexWrap: "wrap" }),
  rule("chan", { color: info, fontSize: 11, flexShrink: 0 }),
  rule("who", { color: "#c6d0f0", fontWeight: 700, flexShrink: 0 }),
  rule("said", { color: ink, flexGrow: 1, minWidth: 0, whiteSpace: "pre-wrap" }),
  rule("sys", { color: dim, fontStyle: "italic" }),

  // The job board.
  rule("job", {
    position: "relative",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 16,
    paddingTop: 5,
    paddingBottom: 5,
    paddingLeft: 9,
    paddingRight: 9,
    borderRadius: 4,
    backgroundColor: "#171b2c",
    border: edge(innerLine),
  }),
  rule("job", { backgroundColor: raised }, "hover"),
  rule("full", { opacity: 0.45 }),

  // A shelf row and a file row.
  rule("stock", { color: dim, fontSize: 11, textAlign: "right" }),
  rule("pname", { color: ink, fontSize: 12, textAlign: "left" }),
  rule("filerow", { alignItems: "center", gap: 4 }),
  rule("fname", { flexGrow: 1, minWidth: 0, textAlign: "left" }),
  rule("fsize", { color: dim, fontSize: 10, flexShrink: 0 }),
  rule("fopen", { color: "#b7e8c1", border: edge("#4d7f5a") }),
  rule("panes", { gap: 10, alignItems: "start" }),

  // What a vessel, a tile or a run is holding.
  rule("matter", { gap: 2, marginTop: 2 }),
  rule("mstate", {
    color: bright,
    fontSize: 11,
    fontWeight: 700,
    marginTop: 4,
    paddingBottom: 2,
    borderBottom: edge(rule_line),
  }),
  rule("mrow", { alignItems: "center", gap: 6, paddingTop: 1 }),
  rule("mname", { flexGrow: 1, minWidth: 0, color: dim, fontSize: 11 }),
  rule("mval", { color: ink, fontSize: 11, textAlign: "right" }),
  rule("dot", {
    width: 10,
    height: 10,
    flexShrink: 0,
    borderRadius: 2,
    border: edge("#ffffff59"),
  }),
  rule("good", { color: good }),
]);
