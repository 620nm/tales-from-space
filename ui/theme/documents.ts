// The surfaces a document opens in: the host window's parts the pack
// paints, a document's head strip and body, the readout hierarchy
// inside it, and the action strip. Appended after `kit.ts`.
import type { UiStyleRule } from "@lunatic/ui";
import { rule } from "@lunatic/ui";
import { edge, none, stroke } from "./parts";
import {
  alpha, amberLine, dim, face, faceLine, faint, field, ink, raised, surface, teal,
  titleFace, titleLine,
  paper, paperInk,
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
  rule("window-body", { display: "flex", flexDirection: "column", padding: 0, overflow: "hidden" }),
  rule("window-close", {
    width: 28, minWidth: 28, height: 28, padding: 0, fontFamily: "mono", fontSize: 17, color: ink,
    backgroundColor: "transparent", border: none, borderRadius: 3,
  }),
  rule("window-close", { backgroundColor: raised }, "hover"),
  // The tail under a fresh window, pointing back at the control it came
  // out of: the same amber every other "this is yours" mark wears.
  rule("window-caret", { backgroundColor: amberLine }),

  // A document window: a head strip that reads as part of the title bar.
  rule("doc-pane", { padding: 0, gap: 0, maxWidth: "100%", backgroundColor: surface, border: edge(titleLine), borderRadius: 5, overflow: "hidden" }),
  rule("doc-heading", { fontSize: 15, fontWeight: 700, color: ink, minWidth: 0 }),
  // A device's heading carries its address and link state, small.
  rule("doc-head", { alignItems: "center", gap: 8, minWidth: 0 }),
  rule("doc-heading-meta", { fontFamily: "mono", fontSize: 11, color: dim, whiteSpace: "nowrap" }),
  // The link state keeps its reading's tone: no colour here.
  rule("doc-heading-state", { fontFamily: "mono", fontSize: 11, whiteSpace: "nowrap" }),
  rule("doc-status", { fontSize: 11, color: dim }),
  rule("doc-unavailable", { fontSize: 11, color: ink }),
  rule("toolbar", { padding: 12, borderBottom: edge(titleLine) }, { within: "doc-pane" }),
  rule("screen-footer", { padding: 12, borderTop: edge(titleLine) }, { within: "doc-pane" }),
  rule("doc-body", { padding: 16, gap: 6 }),

  // A module readout: eyebrow, heading, stat blocks, then its rows. A
  // stat's own label is an eyebrow too.
  rule("mod-eyebrow", { justifyContent: "space-between", gap: 8, fontFamily: "mono", fontSize: 11, letterSpacing: 1, textTransform: "uppercase", color: dim }),
  rule("mod-head", { fontSize: 15, fontWeight: 700, lineHeight: 1.2, color: ink, marginTop: 14, marginBottom: 14 }),
  rule("mod-stats", { gap: 25, flexWrap: "wrap", marginBottom: 4 }),
  rule("mod-stat-value", { fontFamily: "mono", fontSize: 23, fontWeight: "bold", lineHeight: 1, color: ink }),
  rule("mod-unit", { fontSize: 11, color: dim, fontStyle: "normal" }),
  rule("gauge", { height: 6, marginTop: 12, marginBottom: 4, backgroundColor: field, border: edge(titleLine), borderRadius: 0, accentColor: teal }),
  rule("module-row", { alignItems: "center", justifyContent: "space-between", gap: 15, marginTop: 8, fontSize: 11 }),
  rule("mod-pill", {
    minWidth: 64, fontSize: 11, paddingTop: 4, paddingBottom: 4, paddingLeft: 13, paddingRight: 13,
    borderRadius: 2, color: ink, backgroundColor: face, border: edge(faceLine),
  }),
  rule("mod-foot", { justifyContent: "space-between", gap: 8, borderTop: edge(titleLine), paddingTop: 11, marginTop: 13, fontFamily: "mono", fontSize: 11, fontStyle: "normal", color: faint }),

  // Action groups wrap within the control region above the hands.
  rule("action-strip", { width: "100%", flexWrap: "wrap", alignItems: "end", justifyContent: "end", gap: 8, pointerEvents: "none" }),
  rule("action-group", { position: "relative", minWidth: 0, maxWidth: "100%", flexShrink: 1, paddingTop: 0, gap: 4, alignItems: "end" }),
  rule("action-buttons", { display: "flex", minWidth: 0, maxWidth: "100%", whiteSpace: "nowrap", flexDirection: "row-reverse", alignItems: "end", gap: 4 }),
  rule("group-label", { whiteSpace: "nowrap", fontFamily: "mono", fontSize: 11, letterSpacing: 1, textTransform: "uppercase", color: ink, textShadow: stroke }),
  rule("ability", {
    position: "relative", width: 34, height: 34, minWidth: 34, padding: 0, alignItems: "center", justifyContent: "center",
    backgroundColor: alpha(face, 0.87), border: edge(titleLine), borderRadius: 2, overflow: "hidden",
  }),
  rule("ability", { backgroundColor: alpha(raised, 0.87) }, "hover"),
  rule("ability-icon", { width: 32, height: 32, pointerEvents: "none" }),
  rule("action-button", { minHeight: 34, maxWidth: 180, whiteSpace: "normal", minWidth: 44, fontSize: 12, paddingLeft: 6, paddingRight: 6, backgroundColor: face, border: edge(faceLine), borderRadius: 2 }),

  // Physical documents keep their own paper and handwriting surfaces.
  rule("paper-identity", { alignItems: "center", justifyContent: "space-between", gap: 8 }),
  rule("paper-title", { fontFamily: "patrick-hand", fontSize: 22, color: ink }),
  rule("paper-sheet", { display: "block", backgroundColor: paper, color: paperInk, padding: 14, minHeight: 100, whiteSpace: "pre-wrap" }),
  rule("paper-line", { display: "inline", fontFamily: "patrick-hand", fontSize: 22, lineHeight: 1.25, color: paperInk, whiteSpace: "pre-wrap" }),
  rule("paper-committed", { fontWeight: 400 }),
  rule("paper-label", { flexShrink: 0, whiteSpace: "nowrap", fontFamily: "mono", fontSize: 11, textTransform: "uppercase", letterSpacing: 1, color: dim }),
  rule("paper-draft-area", { gap: 6, paddingTop: 10 }),
  rule("paper-draft", { width: "100%", minHeight: 90, fontFamily: "patrick-hand", fontSize: 19, color: paperInk, backgroundColor: paper }),
  rule("fax-identity", { width: "100%", alignItems: "center", gap: 12, flexWrap: "wrap" }),
  rule("fax-controls", { width: "100%", alignItems: "center", gap: 6, flexWrap: "wrap", paddingBottom: 8, borderBottom: edge(titleLine) }),
  rule("fax-name-entry", { minWidth: 100, flexGrow: 1 }),
  rule("fax-count", { fontFamily: "mono", fontSize: 11, color: dim }),
  rule("fax-body", { width: "100%", alignItems: "start", gap: 10, paddingTop: 10 }),
  rule("fax-paper", { display: "block", backgroundColor: paper, color: paperInk, padding: 12, minHeight: 160 }),
  rule("fax-directory-side", { gap: 8, minWidth: 0 }),
  rule("fax-directory", { gap: 4, width: "100%", minWidth: 0 }),
  rule("fax-directory-row", { alignItems: "center", justifyContent: "space-between", gap: 5, width: "100%", minWidth: 0, overflow: "hidden" }),
  rule("fax-directory-name", { minWidth: 0, flexGrow: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }),
  rule("fax-directory-target", { width: 58, minWidth: 58, flexShrink: 0, paddingLeft: 3, paddingRight: 3, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }),
  rule("fax-directory-nav", { justifyContent: "space-between", alignItems: "center", paddingTop: 6, minWidth: 0 }),
  rule("fax-directory-page", { flexShrink: 0, minWidth: 76, whiteSpace: "nowrap" }),
  rule("fax-directory-previous", { width: 58, minWidth: 58, flexShrink: 0, paddingLeft: 3, paddingRight: 3, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }),
  rule("fax-directory-next", { width: 36, minWidth: 36, flexShrink: 0, paddingLeft: 3, paddingRight: 3, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }),
  rule("copier-identity", { alignItems: "center", justifyContent: "space-between", gap: 8 }),
  rule("copier-controls", { width: "100%", alignItems: "center", gap: 8, paddingBottom: 8, borderBottom: edge(titleLine) }),
  rule("copier-paper", { display: "block", backgroundColor: paper, color: paperInk, padding: 12, minHeight: 180 }),
];
