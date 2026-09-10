// The floating HUD over the station: the root sheet, the inventory
// squares, the hand cluster, the worn grid, the target figure and its
// readouts, the storage tray, the crew board, the matter readout and
// the words over a head. Appended after `kit.ts`, so each rule is the
// last word on its class.
import type { UiStyleRule } from "@lunatic/ui";
import { rule } from "@lunatic/ui";
import { cover, edge, flat, none, press, stroke } from "./parts";
import {
  alpha, amber, amberLine, black, bright, dim, face, faint, ink, line,
  ruleLine, sky, skyFace, skyLine, surface, teal, titleFace,
} from "./tokens";

export const hudRules: UiStyleRule[] = [
  // The root: a transparent sheet the station shows through.
  rule("hud", {
    position: "relative", width: "100%", height: "100%",
    padding: 0, gap: 0, maxWidth: "100%",
    backgroundColor: "transparent", border: none, borderRadius: 0,
    boxShadow: flat, overflow: "hidden", pointerEvents: "none",
  }),
  // A HUD region: a group pinned to an edge with no box of its own
  // (tg code/__DEFINES/hud.dm:37, :238). It follows `pane`, so a Pane
  // wearing it keeps the type and loses the frame. maxWidth in pixels:
  // the HUD anchor is a zero-width box, so a percentage collapses it.
  rule("hudgroup", {
    padding: 0, gap: 6, maxWidth: 4096, backgroundColor: "transparent",
    border: none, borderRadius: 0, boxShadow: flat, pointerEvents: "none",
  }),
  // Captions and readings float bare over the station, so both wear
  // the stroke. Inside a pane it is a black edge on a black face.
  rule("caption", {
    color: dim, fontFamily: "mono", fontSize: 9, fontWeight: 700,
    textTransform: "uppercase", letterSpacing: 1, textShadow: stroke,
  }),
  rule("chipval", { color: bright, fontSize: 11, fontWeight: 700, textShadow: stroke }),

  // A slot is a bare square, not a card: tg draws an inventory box as a
  // screen icon over a transparent HUD (code/_onclick/hud/inventory_slot.dm:20-30).
  // Its stack: frame art under the sprite, the label over it, the press
  // over everything; the frame is absolutely placed, so the sprite has
  // to be positioned to paint above it.
  rule("slot", { backgroundColor: "transparent", border: none, borderRadius: 0, boxShadow: flat }),
  rule("slot-empty", { backgroundColor: "transparent", opacity: 1 }),
  rule("slot-frame", { ...cover, imageRendering: "pixelated", pointerEvents: "none" }),
  rule("slot-icon", { position: "relative", zIndex: 1 }),
  rule("slot-fill", { zIndex: 2 }),
  // One clipped line: a name will not fit a 40px square, and a wrapped
  // one climbs over the sprite it belongs to.
  rule("slot-label", {
    zIndex: 3, fontFamily: "mono", fontSize: 7, lineHeight: 1.2, maxHeight: 9,
    paddingLeft: 1, paddingRight: 1, letterSpacing: 1, textTransform: "uppercase", color: ink,
    backgroundColor: "transparent", overflow: "hidden", textShadow: stroke,
  }),
  rule("slot-hit", { zIndex: 4, borderRadius: 2, ...press }),
  // The lit square: an outline, never a border, so the frame art and
  // the press stretched over it do not shrink (docs/pack-ui/box-model.md).
  // The inset ring starts at the padding edge, one pixel in from the
  // stroke, so spread 3 paints the two a player sees.
  rule("slot-active", {
    outline: edge(amber), outlineOffset: -1, backgroundColor: alpha(amber, 0.3),
    boxShadow: [{ x: 0, y: 0, blur: 0, spread: 3, color: alpha(amberLine, 0.5), inset: true }],
  }),
  rule("slot-active-ring", { ...cover, pointerEvents: "none", zIndex: 5, border: edge(amber), backgroundColor: "transparent" }),

  // The hand cluster: two 60x61 cells over a row of compact controls,
  // centred on the HUD origin by its own half width.
  rule("hand-cluster", { gap: 4, marginLeft: -62, pointerEvents: "none" }),
  rule("hand-slot", {
    width: 60, height: 61, backgroundColor: alpha(titleFace, 0.9), border: none, borderRadius: 0,
    boxShadow: [{ x: 0, y: 0, blur: 0, spread: 2, color: surface, inset: true }],
  }),
  // A glyph over its word: each line box holds the face's whole ascent
  // and descent (mono runs past 1.2em), and the control is the two plus a gap.
  rule("hand-actions", { gap: 3, height: 23, pointerEvents: "none" }),
  rule("hand-action", {
    position: "relative", flexGrow: 1, height: 23, alignItems: "center", justifyContent: "center", gap: 1,
    backgroundColor: alpha(titleFace, 0.85), outline: edge(line), outlineOffset: -1, borderRadius: 2, overflow: "hidden",
  }),
  rule("hand-action", { backgroundColor: alpha(face, 0.9) }, "hover"),
  rule("hand-action-on", { backgroundColor: alpha(amber, 0.3), outline: edge(amber) }),
  rule("hud-glyph", { fontFamily: "mono", fontSize: 11, lineHeight: 1.3, color: ink }),
  rule("hud-cap", { fontFamily: "mono", fontSize: 6, lineHeight: 1.2, letterSpacing: 1, textTransform: "uppercase", color: ink }),
  // The transparent press stretched over a box that draws itself.
  rule("hud-hit", {
    ...cover, padding: 0, backgroundColor: "transparent", border: none, borderRadius: 0,
    boxShadow: flat, cursor: "pointer", ...press,
  }),

  // The worn grid's stationary toggle: its edge outlines the box, so what
  // is hit and what is seen are one rectangle.
  rule("worn-toggle", {
    position: "relative", width: 40, height: 40, minWidth: 40,
    flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 2, padding: 0,
    backgroundColor: alpha(skyFace, 0.9), border: none, outline: edge(skyLine), outlineOffset: -1,
    borderRadius: 0, overflow: "hidden",
  }),
  rule("worn-on", { backgroundColor: alpha(skyLine, 0.6), outline: edge(sky) }),
  rule("worn-glyph", { fontFamily: "mono", fontSize: 18, lineHeight: 1.2, color: sky }),
  rule("worn-cap", { fontFamily: "mono", fontSize: 7, lineHeight: 1.2, letterSpacing: 1, textTransform: "uppercase", color: sky }),

  // The target figure: one atlas cell at twice its size, so a hand and a
  // foot are separable at a glance; the aiming rectangles are
  // percentages of this box. A chosen zone lights by outline.
  rule("doll-block", { minWidth: 64, flexShrink: 0 }),
  rule("doll", {
    position: "relative", width: 64, height: 64, maxWidth: 64, flexShrink: 0,
    backgroundColor: alpha(black, 0.55), border: edge(line), borderRadius: 2,
  }),
  rule("dollart", { position: "absolute", left: 0, top: 0, width: 64, height: 64, imageRendering: "pixelated", pointerEvents: "none" }),
  rule("dollhit", { position: "absolute", padding: 0, backgroundColor: "transparent", border: none, borderRadius: 2, cursor: "pointer", ...press }),
  rule("dollhit", { backgroundColor: alpha(teal, 0.25) }, "hover"),
  rule("dollon", { backgroundColor: alpha(teal, 0.18), outline: edge(amber), outlineOffset: -1 }),
  // Beside the figure: a slot held for the intent pill, and readouts.
  rule("target-reserve", { width: 56, maxWidth: 56, height: 28, backgroundColor: "transparent", border: none, borderRadius: 0, boxShadow: flat }),
  rule("target-status", {
    alignItems: "start", gap: 1, whiteSpace: "nowrap", justifyContent: "end",
    fontFamily: "mono", fontSize: 8, letterSpacing: 1, color: ink, textShadow: stroke,
  }),
  rule("status-dot", { color: teal, fontFamily: "mono", fontSize: 8 }),
  rule("status-key", { color: dim, fontFamily: "mono", fontSize: 8, textTransform: "uppercase" }),

  // The storage tray, the one amber-framed surface: a screen whose
  // toolbar is the tray's head and whose body is the grid.
  rule("storage-window", {
    padding: 0, gap: 0, minWidth: 0, maxWidth: "100%",
    backgroundColor: alpha(titleFace, 0.9), border: edge(amberLine), borderRadius: 4, overflow: "hidden",
  }),
  rule("toolbar", { height: 23, gap: 8, paddingBottom: 0, paddingLeft: 7, paddingRight: 7, fontFamily: "mono", fontSize: 9, color: amber }, { within: "storage-window" }),
  rule("storage-count", { marginLeft: "auto", fontFamily: "mono", fontSize: 9, color: dim }),
  rule("storage-grid", { display: "grid", gridTemplateColumns: { repeat: 7, min: 40, max: 40 }, gap: 4, paddingLeft: 7, paddingRight: 7, paddingBottom: 8 }),

  // The crew board.
  rule("job", {
    position: "relative", alignItems: "center", justifyContent: "space-between", gap: 16,
    paddingTop: 5, paddingBottom: 5, paddingLeft: 9, paddingRight: 9,
    borderRadius: 2, backgroundColor: alpha(surface, 0.6), border: edge(ruleLine),
  }),
  rule("job", { backgroundColor: alpha(face, 0.6) }, "hover"),
  rule("full", { opacity: 0.45 }),

  // What a vessel, a tile or a run is holding.
  rule("matter", { gap: 2, marginTop: 2 }),
  rule("mstate", { color: bright, fontSize: 11, fontWeight: 700, marginTop: 4, paddingBottom: 2, borderBottom: edge(ruleLine) }),
  rule("mrow", { alignItems: "center", gap: 6, paddingTop: 1 }),
  rule("mname", { flexGrow: 1, minWidth: 0, color: dim, fontSize: 11 }),
  rule("mval", { color: ink, fontSize: 11, textAlign: "right" }),
  rule("dot", { width: 10, height: 10, flexShrink: 0, borderRadius: 2, border: edge(alpha(bright, 0.35)) }),

  // Words over a head: tgstation's runechat, lettering and not a box
  // (interface/skin.dmf:79). CHAT_MESSAGE_WIDTH 112 on a 32px tile is
  // 168 on this camera's ~48; the pixel face draws at a whole multiple
  // of its native 11 (`PIXEL_NATIVE`), the one nearest the 12 the tile
  // ratio would give. Fixed width, because an anchored box with auto
  // width shrink-wraps against the viewport edge into a word tower.
  rule("rune", {
    width: 168, gap: 3, paddingLeft: 2, paddingRight: 2,
    flexWrap: "wrap", alignItems: "center", justifyContent: "center", textAlign: "center",
    fontFamily: "pixel", fontSize: 11, lineHeight: 1,
    backgroundColor: "transparent", border: none, boxShadow: flat, userSelect: "none", textShadow: stroke,
  }),
  rule("rune-said", { minWidth: 0, whiteSpace: "pre-wrap" }),
  rule("rune-chan", { color: amber, flexShrink: 0 }),

  // The top-right status: where this body is, and who it is.
  rule("statusline", {
    alignItems: "center", gap: 8, padding: 0, backgroundColor: "transparent", border: none, borderRadius: 0,
    boxShadow: flat, fontFamily: "mono", fontSize: 11, color: ink, textShadow: stroke, pointerEvents: "none",
  }),
  rule("statusdot", { width: 5, height: 5, flexShrink: 0, backgroundColor: teal, borderRadius: 0 }),
  rule("statusname", { marginLeft: 3, paddingLeft: 11, borderLeft: edge(faint), fontFamily: "mono", fontSize: 11, color: dim, textShadow: stroke }),
];
