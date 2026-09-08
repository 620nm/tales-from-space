// The HUD package's stylesheet: the chrome both of this pack's packages
// share, then the rules that make the gameplay sheet the station's own.
// Class names outside the kit's vocabulary are this pack's
// (docs/pack-ui/components.md); a later rule for the same class wins, so
// every override below appends. Tokens live in `theme-tokens.ts`, the
// shared chrome in `theme-base.ts`, the floating surfaces in
// `theme-surfaces.ts`, the overlay package's sheet in `overlay/styles.ts`.
import type { UiStyleRule } from "@lunatic/ui";
import { defineStyles, rule } from "@lunatic/ui";
import { workspaceRules } from "./theme-workspace";
import { baseRules } from "./theme-base";
import { surfaceRules } from "./theme-surfaces";
import { hudRules } from "./theme-hud";
import {
  amber, bright, dim, edge, field, flat, ink, line, none, stroke, press,
  ring, rule_line, teal,
} from "./theme-tokens";

export default defineStyles([
  ...baseRules,

  // A slot is a bare square, not a card: tg draws an inventory box as a
  // screen icon over a transparent HUD, backed by an icon state rather
  // than by chrome (code/_onclick/hud/inventory_slot.dm:20-30). The two
  // states that SAY something are restated after it, or they lose to it.
  rule("slot", { backgroundColor: "transparent", border: none, borderRadius: 0, boxShadow: flat }),
  // An stroke, never a border: the frame art and the press are absolutely
  // placed over the square and a border would shrink both
  // (docs/pack-ui/box-model.md).
  rule("slot-active", { outline: edge(amber), outlineOffset: -1, boxShadow: ring(amber, 1) }),
  // Two-tone, because a bare square has to be findable on a lit floor as
  // well as in a dark corridor: a light dash over a dark pane, which is
  // what tg's `template` icon state is a drawn version of.
  rule("slot-empty", { backgroundColor: "transparent", opacity: 1 }),
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
  // Captions and readings float bare over the station now, so both wear
  // the stroke. Inside a pane it is a black edge on a black face and
  // costs nothing.
  rule("caption", {
    color: dim, fontFamily: "mono", fontSize: 9, fontWeight: 700,
    textTransform: "uppercase", letterSpacing: 1, textShadow: stroke,
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
  rule("chipval", { color: bright, fontSize: 11, fontWeight: 700, textShadow: stroke }),

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
  // black stroke, line-height 1 — scaled from BYOND's 32px tile to the
  // ~48 CSS px one this camera draws at its default zoom, so 6pt (8px)
  // becomes 12 and tg's CHAT_MESSAGE_WIDTH of 112 (3.5 tiles) becomes
  // 168. The text outline is what `-dm-text-outline: 1px black` means once
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
    textShadow: stroke,
  }),
  // The words themselves wear the speaker's hue, written inline; the run
  // only has to be allowed to wrap inside the cap above.
  rule("rune-said", { minWidth: 0, whiteSpace: "pre-wrap" }),
  // A radio line keeps its prefix, in the colour the log gives channels.
  rule("rune-chan", { color: amber, flexShrink: 0 }),

  ...surfaceRules,
  ...hudRules,
  ...workspaceRules,
] as UiStyleRule[]);
