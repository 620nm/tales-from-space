import type { UiStyleRule } from "@lunatic/ui";
import { defineStyles, rule } from "@lunatic/ui";
import { alpha, amber, bright, dim, face, faceLine, field, faint, ink, line, ruleLine, teal } from "./tokens";
import { edge, press } from "./parts";
import { kitRules } from "./kit";

/** Ordinary player contact surface; it never shares the staff shell classes. */
export const contactRules: UiStyleRule[] = [
  rule("contact-entry-card", {
    width: "100%", minWidth: 0, gap: 4, padding: 6,
    backgroundColor: alpha(face, 0.84), border: edge(faceLine),
  }),
  rule("contact-entry-head", { minWidth: 0, alignItems: "center" }),
  rule("contact-entry-button", { flexShrink: 0, minHeight: 28, ...press }),
  rule("contact-title", { minWidth: 0, flexGrow: 1, color: bright, fontFamily: "mono", fontSize: 13, fontWeight: "bold" }),
  rule("contact-notice", { color: amber, fontSize: 11, fontWeight: "bold" }),
  rule("contact-muted", { color: dim, fontSize: 11 }),
  rule("contact-unread", { color: amber, fontSize: 11, fontWeight: "bold" }),
  rule("contact-window", {
    width: "100%", minWidth: 0, height: 360, minHeight: 220, maxHeight: "100%", flexGrow: 0,
    backgroundColor: alpha(field, 0.96), border: edge(line), overflow: "hidden",
  }),
  rule("contact-window", { pointerEvents: "auto" }),
  rule("contact-window-body", { width: "100%", minWidth: 0, gap: 8, alignItems: "stretch" }),
  rule("contact-list", { width: "100%", minWidth: 0, gap: 4 }),
  rule("contact-section-title", { color: bright, fontFamily: "mono", fontSize: 12, fontWeight: "bold" }),
  rule("contact-conversation", { width: "100%", minWidth: 0, minHeight: 30, textAlign: "left", justifyContent: "start", whiteSpace: "normal", ...press }),
  rule("contact-load", { width: "100%", flexShrink: 0, minHeight: 28, ...press }),
  rule("contact-history", { width: "100%", minWidth: 0, gap: 4 }),
  rule("contact-history-heading", { flexShrink: 0, minWidth: 0, alignItems: "start" }),
  rule("contact-message", { gap: 3, padding: 5, backgroundColor: alpha(face, 0.65), border: edge(faceLine) }),
  rule("contact-message-incoming", { borderLeft: edge(teal) }),
  rule("contact-message-outgoing", { borderLeft: edge(amber) }),
  rule("contact-message-head", { minWidth: 0, justifyContent: "space-between" }),
  rule("contact-message-sender", { minWidth: 0, flexGrow: 1, color: bright, fontSize: 11, fontWeight: "bold", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }),
  rule("contact-message-time", { flexShrink: 0, color: faint, fontFamily: "mono", fontSize: 10 }),
  rule("contact-message-staff", { color: ink, fontSize: 12, lineHeight: 1.35, userSelect: "text" }),
  rule("contact-message-own", { color: teal, fontSize: 12, lineHeight: 1.35, userSelect: "text" }),
  rule("contact-sender", { gap: 2, padding: 5, backgroundColor: alpha(face, 0.45), border: edge(ruleLine) }),
  rule("contact-staff-name", { color: bright, fontSize: 12, fontWeight: "bold" }),
  rule("contact-own-name", { color: teal, fontSize: 12, fontWeight: "bold" }),
  rule("contact-sender-kind", { color: dim, fontSize: 10 }),
  rule("contact-composer", { minWidth: 0, gap: 5, alignItems: "center" }),
  rule("contact-entry", { minWidth: 0, flexGrow: 1, ...press }),
  rule("contact-denial", { padding: 5, color: amber, backgroundColor: alpha(amber, 0.1), border: edge(alpha(amber, 0.55)), fontSize: 11 }),
];

export default defineStyles([...kitRules, ...contactRules] as UiStyleRule[]);
