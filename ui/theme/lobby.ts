// Crew board and round-preparation surfaces. The shell uses two sibling
// screens so both columns keep their body scroller and footer pinned.
import type { UiStyleRule } from "@lunatic/ui";
import { rule } from "@lunatic/ui";
import { edge, flat, press, shade } from "./parts";
import {
  alpha, amber, amberLine, bright, dim, face, faceLine, faint, field,
  ink, line, ruleLine, surface, teal, titleFace, titleLine,
} from "./tokens";

export const lobbyRules: UiStyleRule[] = [
  rule("lobby-shell", {
    width: "100%", height: "100%", maxWidth: 1200, maxHeight: "100%",
    minWidth: 0, minHeight: 0, flexDirection: "row", gap: 10, padding: 10,
    backgroundColor: alpha(surface, 0.96), border: edge(titleLine), borderRadius: 4,
    boxShadow: shade, pointerEvents: "auto", overflow: "hidden",
  }),
  rule("lobby-ooc-screen", {
    width: "40%", maxWidth: "100%", minWidth: 0, height: "100%", flexGrow: 2,
    flexShrink: 1, backgroundColor: alpha(field, 0.92), border: edge(line),
    boxShadow: flat, overflow: "hidden", fontFamily: "sans",
  }),
  rule("lobby-setup-screen", {
    width: "60%", maxWidth: "100%", minWidth: 0, height: "100%", flexGrow: 3,
    flexShrink: 1, backgroundColor: alpha(titleFace, 0.92), border: edge(amberLine),
    boxShadow: flat, overflow: "hidden",
  }),
  rule("lobby-editor", { gap: 10, minWidth: 0, maxWidth: "100%", padding: 10 }),
  rule("lobby-section-title", {
    color: bright, fontFamily: "mono", fontSize: 13, fontWeight: 700,
    letterSpacing: 1, paddingBottom: 4, borderBottom: edge(ruleLine),
  }),
  rule("lobby-field", { alignItems: "center", gap: 8, minWidth: 0, maxWidth: "100%" }),
  rule("lobby-field-label", {
    width: 88, minWidth: 88, flexShrink: 0, color: dim, fontFamily: "mono",
    fontSize: 11, textTransform: "uppercase",
  }),
  rule("lobby-name-entry", { minWidth: 0, width: "100%" }),
  rule("lobby-ranked", { gap: 4, minWidth: 0, maxWidth: "100%" }),
  rule("lobby-rank-row", {
    alignItems: "center", gap: 7, minHeight: 32, paddingTop: 2, paddingBottom: 2,
    paddingLeft: 5, paddingRight: 5, backgroundColor: alpha(face, 0.72),
    border: edge(faceLine), borderRadius: 2,
  }),
  rule("lobby-rank-number", {
    width: 22, minWidth: 22, flexShrink: 0, color: amber, fontFamily: "mono",
    fontSize: 11, textAlign: "right",
  }),
  rule("lobby-rank-name", { flexGrow: 1, minWidth: 0, color: ink, fontSize: 12, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }),
  rule("lobby-rank-controls", { flexShrink: 0, gap: 3, alignItems: "center" }),
  rule("lobby-rank-button", { minWidth: 30, width: 30, paddingLeft: 2, paddingRight: 2, fontFamily: "mono", fontSize: 11 }),
  rule("lobby-add-select", { flexGrow: 1, minWidth: 0, width: "100%" }),
  rule("lobby-fallback-select", { flexGrow: 1, minWidth: 0, width: "100%" }),
  rule("lobby-notice", {
    flexShrink: 0, paddingTop: 7, paddingBottom: 7, paddingLeft: 8, paddingRight: 8,
    color: amber, backgroundColor: alpha(amber, 0.12), border: edge(amberLine),
    fontSize: 11, lineHeight: 1.35,
  }),
  rule("lobby-round", { marginLeft: "auto", color: dim, fontFamily: "mono", fontSize: 11 }),
  rule("lobby-ooc-line", { alignItems: "start", gap: 5, paddingTop: 4, paddingBottom: 4, borderBottom: edge(ruleLine), lineHeight: 1.4 }),
  rule("lobby-ooc-name", { flexShrink: 0, color: teal, fontWeight: 700, fontSize: 11 }),
  rule("lobby-ooc-text", { flexGrow: 1, minWidth: 0, color: ink, fontSize: 12, whiteSpace: "pre-wrap" }),
  rule("lobby-ooc-entry", { width: "100%" }),
  rule("lobby-status-footer", {
    flexGrow: 0, flexShrink: 0, minHeight: 26, alignItems: "center", gap: 8,
    paddingTop: 3, paddingBottom: 3, borderTop: edge(ruleLine), color: dim,
    fontFamily: "mono", fontSize: 11,
  }),
  rule("lobby-phase", { color: bright, fontWeight: 700, textTransform: "uppercase" }),
  rule("lobby-timer", { marginLeft: "auto", color: amber }),
  rule("lobby-paused", { color: amber, textTransform: "uppercase" }),
  rule("lobby-readiness-footer", {
    flexGrow: 0, flexShrink: 0, minHeight: 36, alignItems: "center", gap: 8,
    paddingTop: 4, paddingBottom: 3, borderTop: edge(ruleLine), color: dim,
    fontFamily: "mono", fontSize: 11,
  }),
  rule("lobby-ready-count", { color: teal }),
  rule("lobby-connected-count", { color: dim }),
  rule("lobby-ready-button", { marginLeft: "auto", minWidth: 100 }),
];
