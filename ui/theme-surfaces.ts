// The HUD's floating surfaces: the inspection toasts down the left
// edge, the chat well, and the host's own window and action-bar parts.
// Appended after the shared chrome in `theme.ts`, so each of these wins
// for the classes it names. The hover card lives in `theme-overlay.ts`.
import type { UiStyleRule } from "@lunatic/ui";
import { rule } from "@lunatic/ui";
import {
  amber, amberLine, dim, edge, face, faceLine, faint, field, flat, ink, line,
  none, press, rule_line, shade,
} from "./theme-tokens";

const sunk = [{ x: 0, y: 1, blur: 2, color: "#000000" }];

export const surfaceRules: UiStyleRule[] = [
  // An inspection toast: a fixed-width card with a lit left edge, a
  // clamped body, and a press that opens the rest of it.
  rule("inspect-toast", {
    width: 320, minWidth: 0, maxWidth: "100%", gap: 5,
    paddingTop: 9, paddingBottom: 10, paddingLeft: 10, paddingRight: 10,
    backgroundColor: "#102025e6",
    border: edge("#75938666"), borderLeft: edge("#90b9a1", 2),
    borderRadius: 3, boxShadow: shade, overflow: "hidden",
    color: "#d2dfd6", ...press,
  }),
  rule("inspect-head", { alignItems: "center", gap: 7, minHeight: 24 }),
  rule("inspect-icon", { width: 24, height: 24, flexShrink: 0, imageRendering: "pixelated", pointerEvents: "none" }),
  // No sprite is still a frame: a neutral square keeps the header's
  // baseline and its title where every other toast puts them.
  rule("inspect-blank", {
    width: 24, height: 24, flexShrink: 0,
    backgroundColor: "#1a2b2f", border: edge("#425b55"), borderRadius: 2,
  }),
  rule("inspect-title", {
    flexGrow: 1, minWidth: 0, fontSize: 12, fontWeight: 700,
    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("inspect-body", { gap: 3, maxHeight: 60, overflow: "hidden" }),
  rule("inspect-full", {
    alignSelf: "start", marginTop: 6,
    fontFamily: "mono", fontSize: 10,
    color: "#bbd0c3", backgroundColor: "transparent", border: edge("#3f5b54"),
  }),
  rule("inspect-full", { color: "#eef5e8", backgroundColor: "#28403b" }, "hover"),
  // The way back into everything looked at this shift, parked under the
  // stack rather than over it.
  rule("inspect-history-row", {
    alignSelf: "start", fontFamily: "mono", fontSize: 10,
    paddingTop: 4, paddingBottom: 4, paddingLeft: 7, paddingRight: 7,
    color: "#afc6b8", backgroundColor: "#102025bd",
    border: edge("#3f5b54"), borderRadius: 3, textShadow: sunk,
  }),
  rule("inspect-history-row", { color: "#eef5e8", backgroundColor: "#1c343a" }, "hover"),

  // The chat well: no frame, no title, just a darkened corner of the
  // station with the tabs across its top and the say line at its foot.
  rule("floating-chat", {
    padding: 0, gap: 0, minWidth: 240,
    backgroundColor: "#111c22c8",
    border: none, borderRadius: 0, boxShadow: flat, overflow: "hidden",
    textShadow: sunk,
  }),
  rule("chat-open", { backgroundColor: "#111c22ee", borderLeft: edge("#75887b") }),
  rule("chat-tabs", {
    alignItems: "center", gap: 12, flexShrink: 0,
    paddingTop: 5, paddingBottom: 6, paddingLeft: 8, paddingRight: 8,
  }),
  rule("chat-tab", {
    padding: 0, paddingBottom: 3, minWidth: 0,
    fontFamily: "mono", fontSize: 9, color: "#9fb2ae",
    backgroundColor: "transparent", border: none,
    borderBottom: edge("transparent"), borderRadius: 0,
  }),
  rule("chat-tab", { color: "#e6eadd", backgroundColor: "transparent" }, "hover"),
  rule("chat-tab-on", { color: "#e6eadd", borderBottom: edge(amber) }),
  rule("chat-log", {
    flexGrow: 1, minHeight: 0, overflowY: "auto", gap: 2,
    paddingLeft: 8, paddingRight: 8,
  }),
  rule("stamp", { flexShrink: 0, fontFamily: "mono", fontSize: 9, color: faint }),
  rule("log", { gap: 2, overflowY: "auto" }),
  rule("line", { alignItems: "start", gap: 5, flexWrap: "wrap", lineHeight: 1.5 }),
  rule("chan", { flexShrink: 0, color: "#e0c18a", fontSize: 11 }),
  rule("who", { flexShrink: 0, color: "#e0e3d5", fontWeight: 700 }),
  rule("who-radio", { color: "#e0c18a" }),
  rule("said", { flexGrow: 1, minWidth: 0, color: ink, whiteSpace: "pre-wrap" }),
  rule("sys", { color: "#a9b5b8", fontStyle: "italic" }),
  rule("composer", {
    alignItems: "center", gap: 6, flexShrink: 0,
    marginTop: 4, paddingLeft: 8, paddingRight: 8, paddingBottom: 4,
  }),
  rule("composer-label", { flexShrink: 0, fontFamily: "mono", fontSize: 9, color: "#9ac5b4" }),
  rule("composer-entry", {
    fontSize: 10, color: "#dbe9dc",
    backgroundColor: "transparent", border: none,
    borderBottom: edge("#63807770"), borderRadius: 0,
    paddingLeft: 2, paddingRight: 2,
  }),
  rule("composer-entry", { border: none, borderBottom: edge("#8ac1ab"), color: "#ffffff" }, "focus"),

  // The host's own window grip and action-bar controls; the title and
  // body rules live in theme-hud-doc.ts. The renderer names these
  // classes; a pack only says what they look like.
  rule("window-grip", { backgroundColor: "transparent" }),
  rule("actions-bar", { alignItems: "end", gap: 4 }),
  rule("actions-control", {
    width: "auto", height: 34, minWidth: 34, paddingTop: 0, paddingBottom: 0, paddingLeft: 8, paddingRight: 8,
    alignItems: "center", justifyContent: "center",
    fontFamily: "mono", fontSize: 11, color: ink,
    backgroundColor: face, border: edge(faceLine), borderRadius: 2,
  }),
  rule("actions-search", {
    height: 34, minHeight: 34,
    paddingLeft: 8, paddingRight: 8,
    fontFamily: "mono", fontSize: 11, color: ink,
    backgroundColor: field, border: edge(line), borderRadius: 2,
  }),

  // The frame every inventory cell wears; the cells themselves are
  // theme-hud.ts's.
  rule("slot-frame", {
    position: "absolute", left: 0, top: 0, width: "100%", height: "100%",
    imageRendering: "pixelated", pointerEvents: "none",
  }),
  rule("desktop-screen", {
    display: "block", position: "relative", width: "100%", height: 0,
    paddingTop: "56%", backgroundColor: "#000000", overflow: "hidden",
    border: edge(rule_line),
  }),
  rule("desktop-wallpaper", {
    position: "absolute", left: 0, top: 0, width: "100%", height: "100%",
    imageRendering: "pixelated",
  }),
  rule("desktop-controls", { gap: 6, flexWrap: "wrap" }),
];
