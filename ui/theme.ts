// The pack's stylesheet: the kit's defaults, then the rules that make
// these screens the station's own. Class names outside the kit's
// vocabulary are this pack's (docs/pack-ui/components.md); a later rule
// for the same class wins, so every override below appends. Tokens live
// in `theme-tokens.ts`; the floating surfaces in `theme-surfaces.ts`.
import type { UiStyleRule } from "@lunatic/ui";
import { defineStyles, rule, theme } from "@lunatic/ui";
import { surfaceRules } from "./theme-surfaces";
import { hudRules } from "./theme-hud";
import {
  amber, amberLine, bright, dim, edge, face, faceLine, faint, field, flat,
  ink, line, none, outline, press, ring, rule_line, shade, teal,
} from "./theme-tokens";

const paneBack = "#132226f2";
const inner = "#0f1c20cc";

export default defineStyles([
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

  // A slot is a bare square, not a card: tg draws an inventory box as a
  // screen icon over a transparent HUD, backed by an icon state rather
  // than by chrome (code/_onclick/hud/inventory_slot.dm:20-30). The two
  // states that SAY something are restated after it, or they lose to it.
  rule("slot", { backgroundColor: "transparent", border: none, borderRadius: 0, boxShadow: flat }),
  rule("slot-active", { border: edge(amber), boxShadow: ring(amber, 1) }),
  // Two-tone, because a bare square has to be findable on a lit floor as
  // well as in a dark corridor: a light dash over a dark pane, which is
  // what tg's `template` icon state is a drawn version of.
  rule("slot-empty", { border: none, backgroundColor: "transparent", opacity: 1 }),
  rule("slot-hit", { borderRadius: 2, ...press }),
  // One line, clipped: an item's whole name will not fit a 40px square,
  // and a wrapped one climbs over the sprite it belongs to.
  rule("slot-label", {
    maxHeight: 10, lineHeight: 1.1, fontSize: 8,
    paddingLeft: 1, paddingRight: 1,
    backgroundColor: "#04050ad9", borderRadius: 2, overflow: "hidden",
  }),
  rule("cell", { justifyContent: "center", paddingTop: 2, paddingBottom: 2 }),

  // The root: a transparent sheet the station shows through.
  rule("hud", {
    position: "relative", width: "100%", height: "100%",
    padding: 0, gap: 0, maxWidth: "100%",
    backgroundColor: "transparent", border: none, borderRadius: 0,
    boxShadow: flat, overflow: "hidden", pointerEvents: "none",
  }),
  rule("dock", { gap: 10 }),
  // A HUD region: a group pinned to an edge with no box of its own. tg's
  // hand cluster, zone selector and open storage are three such groups,
  // each placed on its own (code/__DEFINES/hud.dm:37, :238). It follows
  // `pane`, so a Pane wearing it keeps the type and loses the frame.
  // maxWidth in pixels: the shell clamps a panel to 100% of its parent,
  // and the HUD anchor is a zero-width box, so a percentage collapses it.
  rule("hudgroup", {
    padding: 0, gap: 6, maxWidth: 4096, backgroundColor: "transparent",
    border: none, borderRadius: 0, boxShadow: flat, pointerEvents: "none",
  }),
  // pointer-events inherits, so a group the station shows through hands
  // every press inside it to the floor unless the press says otherwise.
  rule("choice-hit", press),
  rule("card", { gap: 5, padding: 8, backgroundColor: inner, border: edge(rule_line), borderRadius: 3 }),
  rule("hint", { color: dim, fontSize: 11, fontStyle: "italic" }),
  rule("marker", { color: amber, fontSize: 11 }),
  rule("grow", { flexGrow: 1, minWidth: 0 }),
  rule("right", { textAlign: "right" }),
  rule("mono", { fontFamily: "mono" }),
  rule("icon", { width: 32, height: 32, flexShrink: 0, imageRendering: "pixelated", pointerEvents: "none" }),
  // Captions and readings float bare over the station now, so both wear
  // the outline. Inside a pane it is a black edge on a black face and
  // costs nothing.
  rule("caption", {
    color: dim, fontFamily: "mono", fontSize: 9, fontWeight: 700,
    textTransform: "uppercase", letterSpacing: 1, textShadow: outline,
  }),

  // The tray: hands and worn slots over the station's bottom edge.
  rule("tray", { alignItems: "end", gap: 8 }),
  rule("trayset", { gap: 4 }),
  rule("chip", {
    alignItems: "center", gap: 5,
    paddingTop: 2, paddingBottom: 2, paddingLeft: 7, paddingRight: 7,
    backgroundColor: field, border: edge(rule_line), borderRadius: 2,
  }),
  rule("chipkey", {
    color: dim, fontFamily: "mono", fontSize: 8,
    textTransform: "uppercase", letterSpacing: 1,
  }),
  rule("chipval", { color: bright, fontSize: 11, fontWeight: 700, textShadow: outline }),

  // The target figure: one atlas cell at twice its size, so a hand and a
  // foot are separable at a glance. The renderer scales a cell to the
  // size its element declares (docs/pack-ui/styles.md), and the aiming
  // rectangles are percentages of this box, so they follow it.
  rule("doll-block", { minWidth: 64, flexShrink: 0 }),
  rule("doll", {
    position: "relative", width: 64, height: 64, maxWidth: 64, flexShrink: 0,
    backgroundColor: "#0a1216b8", border: edge(line), borderRadius: 2,
  }),
  rule("dollart", {
    position: "absolute", left: 0, top: 0, width: 64, height: 64,
    imageRendering: "pixelated", pointerEvents: "none",
  }),
  rule("dollhit", {
    position: "absolute", padding: 0, backgroundColor: "transparent",
    border: none, borderRadius: 2, cursor: "pointer", ...press,
  }),
  rule("dollhit", { backgroundColor: "#91c9b640" }, "hover"),
  rule("dollon", { backgroundColor: "#91c9b62e", border: edge(amber) }),

  // The job board.
  rule("job", {
    position: "relative", alignItems: "center", justifyContent: "space-between",
    gap: 16, paddingTop: 5, paddingBottom: 5, paddingLeft: 9, paddingRight: 9,
    borderRadius: 2, backgroundColor: "#16242899", border: edge(rule_line),
  }),
  rule("job", { backgroundColor: "#22343899" }, "hover"),
  rule("full", { opacity: 0.45 }),

  // A shelf row and a file row.
  rule("stock", { color: dim, fontSize: 11, textAlign: "right" }),
  rule("pname", { color: ink, fontSize: 12, textAlign: "left" }),
  rule("filerow", { alignItems: "center", gap: 4 }),
  rule("fname", { flexGrow: 1, minWidth: 0, textAlign: "left" }),
  rule("fsize", { color: faint, fontSize: 10, flexShrink: 0 }),
  rule("fopen", { color: teal, border: edge("#4f7a6c") }),
  rule("panes", { gap: 10, alignItems: "start" }),

  // What a vessel, a tile or a run is holding.
  rule("matter", { gap: 2, marginTop: 2 }),
  rule("mstate", {
    color: bright, fontSize: 11, fontWeight: 700,
    marginTop: 4, paddingBottom: 2, borderBottom: edge(rule_line),
  }),
  rule("mrow", { alignItems: "center", gap: 6, paddingTop: 1 }),
  rule("mname", { flexGrow: 1, minWidth: 0, color: dim, fontSize: 11 }),
  rule("mval", { color: ink, fontSize: 11, textAlign: "right" }),
  rule("dot", { width: 10, height: 10, flexShrink: 0, borderRadius: 2, border: edge("#ffffff59") }),
  rule("good", { color: teal }),
  // The slot's stack, restated after the sizes above so the press stays
  // over the label and the label over the sprite.
  rule("slot-icon", { position: "relative", zIndex: 1 }),
  rule("slot-fill", { zIndex: 2 }),
  rule("slot-label", { zIndex: 3 }),
  rule("slot-hit", { zIndex: 4 }),

  // Words over a head: tgstation's runechat, which is lettering and not
  // a box. The look is `interface/skin.dmf:79` — Grand9K Pixel, a 1px
  // black outline, line-height 1 — scaled from BYOND's 32px tile to the
  // ~48 CSS px one this camera draws at its default zoom, so 6pt (8px)
  // becomes 12 and tg's CHAT_MESSAGE_WIDTH of 112 (3.5 tiles) becomes
  // 168. The outline is what `-dm-text-outline: 1px black` means once
  // spelled as shadows; both it and the font inherit to the runs.
  rule("rune", {
    // Fixed, like tg's CHAT_MESSAGE_WIDTH: an anchored box with auto
    // width shrink-wraps against the viewport edge into a word tower.
    width: 168,
    gap: 3,
    paddingLeft: 2,
    paddingRight: 2,
    flexWrap: "wrap",
    alignItems: "center",
    justifyContent: "center",
    textAlign: "center",
    fontFamily: "pixel",
    fontSize: 12,
    lineHeight: 1,
    backgroundColor: "transparent",
    border: none,
    boxShadow: flat,
    userSelect: "none",
    textShadow: [
      { x: -1, y: 0, blur: 0, color: "#000000" },
      { x: 1, y: 0, blur: 0, color: "#000000" },
      { x: 0, y: -1, blur: 0, color: "#000000" },
      { x: 0, y: 1, blur: 0, color: "#000000" },
    ],
  }),
  // The words themselves wear the speaker's hue, written inline; the run
  // only has to be allowed to wrap inside the cap above.
  rule("rune-said", { minWidth: 0, whiteSpace: "pre-wrap" }),
  // A radio line keeps its prefix, in the colour the log gives channels.
  rule("rune-chan", { color: amber, flexShrink: 0 }),

  ...surfaceRules,
  ...hudRules,
] as UiStyleRule[]);
