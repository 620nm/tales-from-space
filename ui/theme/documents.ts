// The surfaces a document opens in: the host window's parts the pack
// paints, a document's head strip and body, the readout hierarchy
// inside it, and the action strip. Appended after `kit.ts`.
import type { UiStyleRule } from "@lunatic/ui";
import { rule } from "@lunatic/ui";
import { edge, none, stroke } from "./parts";
import {
  alpha, amberLine, dim, face, faceLine, faint, field, ink, raised, surface, teal,
  titleFace, titleLine,
} from "./tokens";

export const documentRules: UiStyleRule[] = [
  // Host window parts: the title strip, and a body whose padding belongs
  // to the document drawn inside it (docs/pack-ui/style-host.md).
  rule("window-title", {
    minHeight: 24, alignItems: "center", paddingTop: 5, paddingBottom: 5, paddingLeft: 9, paddingRight: 9,
    textTransform: "uppercase", backgroundColor: titleFace, borderBottom: edge(titleLine),
    fontFamily: "mono", fontSize: 11, letterSpacing: 1, color: ink,
  }),
  // The body hands scrolling down to the Screen laid in it
  // (docs/pack-ui/components.md, "Scrolling and the height chain").
  rule("window-body", { padding: 0, overflow: "hidden" }),
  rule("window-close", {
    width: 26, minWidth: 26, height: 25, padding: 0, fontFamily: "mono", fontSize: 17, color: ink,
    backgroundColor: "transparent", border: none, borderRadius: 3,
  }),
  rule("window-close", { backgroundColor: raised }, "hover"),
  // The tail under a fresh window, pointing back at the control it came
  // out of: the same amber every other "this is yours" mark wears.
  rule("window-caret", { backgroundColor: amberLine }),

  // A document window: a head strip that reads as part of the title bar.
  rule("doc-pane", { padding: 0, gap: 0, maxWidth: "100%", backgroundColor: surface, border: edge(titleLine), borderRadius: 5, overflow: "hidden" }),
  rule("doc-body", { padding: 16, gap: 6 }),

  // A module readout: eyebrow, heading, stat blocks, then its rows. A
  // stat's own label is an eyebrow too.
  rule("mod-eyebrow", { justifyContent: "space-between", gap: 8, fontFamily: "mono", fontSize: 8, letterSpacing: 1, textTransform: "uppercase", color: dim }),
  rule("mod-head", { fontSize: 17, fontWeight: "normal", lineHeight: 1.2, color: ink, marginTop: 14, marginBottom: 14 }),
  rule("mod-stats", { gap: 25, flexWrap: "wrap", marginBottom: 4 }),
  rule("mod-stat-value", { fontFamily: "mono", fontSize: 23, fontWeight: "bold", lineHeight: 1, color: ink }),
  rule("mod-unit", { fontSize: 10, color: dim, fontStyle: "normal" }),
  rule("gauge", { height: 6, marginTop: 12, marginBottom: 4, backgroundColor: field, border: edge(titleLine), borderRadius: 0, accentColor: teal }),
  rule("module-row", { alignItems: "center", justifyContent: "space-between", gap: 15, marginTop: 8, fontSize: 11 }),
  rule("mod-pill", {
    minWidth: 64, fontSize: 9, paddingTop: 4, paddingBottom: 4, paddingLeft: 13, paddingRight: 13,
    borderRadius: 2, color: ink, backgroundColor: face, border: edge(faceLine),
  }),
  rule("mod-foot", { justifyContent: "space-between", gap: 8, borderTop: edge(titleLine), paddingTop: 11, marginTop: 13, fontFamily: "mono", fontSize: 8, fontStyle: "normal", color: faint }),

  // The action strip, centred on the same origin as the hands. A stated
  // width, because a box sized by its content inside a zero-width origin
  // shrinks to its widest group and the rest overflows it; its right edge
  // sits halfway along an anchor of the same width whose left edge is the
  // origin (ui/actions.ts), which is how a box wider than the grammar's
  // 64px margin is centred on a point.
  rule("action-strip", { position: "absolute", right: "50%", bottom: 0, width: 640, alignItems: "end", justifyContent: "center", gap: 9, pointerEvents: "none" }),
  rule("action-group", { position: "relative", flexShrink: 0, paddingTop: 11, gap: 4, alignItems: "end" }),
  rule("action-buttons", { display: "flex", maxWidth: 4096, whiteSpace: "nowrap", flexDirection: "row-reverse", alignItems: "end", gap: 4 }),
  rule("group-label", { position: "absolute", whiteSpace: "nowrap", left: 1, top: 0, fontFamily: "mono", fontSize: 7, letterSpacing: 1, textTransform: "uppercase", color: ink, textShadow: stroke }),
  rule("ability", {
    width: 34, height: 34, minWidth: 34, padding: 0, alignItems: "center", justifyContent: "center",
    backgroundColor: alpha(face, 0.87), border: edge(titleLine), borderRadius: 2, overflow: "hidden",
  }),
  rule("ability", { backgroundColor: alpha(raised, 0.87) }, "hover"),
  rule("ability-icon", { width: 24, height: 24 }),
  rule("action-button", { height: 34, minWidth: 44, fontSize: 8, paddingLeft: 6, paddingRight: 6, backgroundColor: face, border: edge(faceLine), borderRadius: 2 }),
];
