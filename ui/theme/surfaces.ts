// The HUD's floating surfaces: the inspection toasts down the left edge,
// the chat well, the host's action-bar parts, and the lines a file
// reader lays out. Appended after `kit.ts`.
import type { UiStyleRule } from "@lunatic/ui";
import { rule } from "@lunatic/ui";
import { edge, flat, insetLine, none, press, shade, sunk } from "./parts";
import {
  alpha, amber, bright, dim, face, faceLine, faint, field, ink, line, teal,
  titleFace, titleLine,
} from "./tokens";

export const surfaceRules: UiStyleRule[] = [
  // An inspection toast: a fixed-width card with a lit left edge, a
  // short preview, and a press that opens the rest of it.
  rule("inspect-toast", {
    width: "100%", minWidth: 0, maxWidth: "100%", flexShrink: 0, gap: 5,
    paddingTop: 9, paddingBottom: 10, paddingLeft: 10, paddingRight: 10,
    backgroundColor: alpha(field, 0.9), border: edge(alpha(faint, 0.4)), borderLeft: edge(teal, 2),
    borderRadius: 3, boxShadow: shade, overflow: "hidden", color: ink, ...press,
  }),
  rule("inspect-head", { alignItems: "center", gap: 7, minHeight: 28 }),
  rule("inspect-icon", { display: "flex", width: 24, height: 24, flexShrink: 0, imageRendering: "pixelated", pointerEvents: "none" }),
  // No sprite is still a frame: a neutral square keeps the header's
  // baseline and its title where every other toast puts them.
  rule("inspect-blank", { width: 24, height: 24, flexShrink: 0, backgroundColor: titleFace, border: edge(titleLine), borderRadius: 2 }),
  rule("inspect-title", { flexGrow: 1, minWidth: 0, fontSize: 15, fontWeight: 700, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }),
  rule("inspect-body", { gap: 3, flexShrink: 0 }),
  rule("inspect-full", { alignSelf: "start", marginTop: 6, fontFamily: "mono", fontSize: 11, color: dim, backgroundColor: "transparent", border: edge(titleLine) }),
  rule("inspect-full", { color: bright, backgroundColor: face }, "hover"),
  // The way back into everything looked at this shift, parked under the
  // stack rather than over it.
  rule("inspect-history-row", {
    alignSelf: "start", fontFamily: "mono", fontSize: 11,
    paddingTop: 4, paddingBottom: 4, paddingLeft: 7, paddingRight: 7,
    color: dim, backgroundColor: alpha(field, 0.75), border: edge(titleLine), borderRadius: 3, textShadow: sunk,
  }),
  rule("inspect-history-row", { color: bright, backgroundColor: titleFace }, "hover"),
  // The toast column and the cards inside an open history window.
  rule("inspect-stack", { minHeight: 0, maxHeight: "100%", flexShrink: 1, overflowY: "auto", gap: 7, alignItems: "start" }),

  // The chat well: no frame, no title, just a darkened corner of the
  // station with the tabs across its top and the say line at its foot.
  // The open state lights its left edge inside the box, so nothing moves.
  rule("floating-chat", {
    flexGrow: 0, flexShrink: 0, paddingTop: 5, paddingBottom: 4, paddingLeft: 8, paddingRight: 8, gap: 0, minWidth: 240,
    backgroundColor: alpha(field, 0.8), border: none, borderRadius: 0, boxShadow: flat,
    overflow: "hidden", textShadow: sunk,
  }),
  rule("chat-open", { backgroundColor: alpha(field, 0.93), boxShadow: insetLine("left", faint) }),
  // A tab is small lettering here, the kit's tab otherwise.
  rule("tab", { fontFamily: "mono", fontSize: 11 }, { within: "floating-chat" }),
  rule("stamp", { flexShrink: 0, fontFamily: "mono", fontSize: 11, color: faint }),
  rule("line", { alignItems: "start", gap: 5, flexWrap: "wrap", lineHeight: 1.5 }),
  rule("chan", { flexShrink: 0, color: amber, fontSize: 11 }),
  rule("who", { flexShrink: 0, color: bright, fontWeight: 700 }),
  rule("who-radio", { color: amber }),
  rule("said", { flexGrow: 1, minWidth: 0, color: ink, whiteSpace: "pre-wrap" }),
  rule("sys", { color: dim, fontStyle: "italic" }),
  rule("composer-label", { flexShrink: 0, fontFamily: "mono", fontSize: 11, color: teal }),
  // The say line's underline is drawn inside its box, so focus recolours
  // it without a border a state turns on.
  rule("composer-entry", {
    height: 28, minHeight: 28, flexGrow: 1, flexShrink: 1, fontSize: 12, color: ink,
    backgroundColor: "transparent", border: none, borderRadius: 0,
    boxShadow: insetLine("bottom", alpha(faint, 0.45)), paddingLeft: 2, paddingRight: 2,
  }),
  rule("composer-entry", { boxShadow: insetLine("bottom", teal), color: bright }, "focus"),

  // The host's own action-bar controls and window grip; the title and
  // body parts live in documents.ts.
  rule("window-grip", { backgroundColor: "transparent" }),
  rule("actions-bar", { alignItems: "end", gap: 4 }),
  rule("actions-row", { minWidth: 0, maxWidth: "100%" }),
  rule("actions-list", { minWidth: 0, maxWidth: "100%", maxHeight: 240, overflowY: "auto" }),
  rule("actions-control", {
    width: "auto", height: 34, minWidth: 34, paddingTop: 0, paddingBottom: 0, paddingLeft: 8, paddingRight: 8,
    alignItems: "center", justifyContent: "center", fontFamily: "mono", fontSize: 11, color: ink,
    backgroundColor: face, border: edge(faceLine), borderRadius: 2,
  }),
  rule("actions-search", { height: 34, minHeight: 34, paddingLeft: 8, paddingRight: 8, fontFamily: "mono", fontSize: 11, color: ink, backgroundColor: field, border: edge(line), borderRadius: 2 }),

  // A file reader's lines: a heading's size follows its level inline.
  rule("reader-line", { whiteSpace: "pre-wrap", flexShrink: 0 }),
  rule("reader-head", { fontWeight: 700 }),
  rule("reader-quote", { paddingLeft: 12 }),
];
