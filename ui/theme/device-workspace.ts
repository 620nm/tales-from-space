// Dense device workspace chrome. Controls use their own compact hierarchy;
// navigation keeps the established tab classes and selected treatment.
import type { UiStyleRule } from "@lunatic/ui";
import { rule } from "@lunatic/ui";
import { edge, none } from "./parts";
import { alpha, bright, dim, field, ink, line, ruleLine, screen, surface, teal } from "./tokens";

export const deviceWorkspaceStyles: UiStyleRule[] = [
  rule("workspace-tabs", {
    width: "100%", minWidth: 0, minHeight: 36, alignItems: "stretch", gap: 0,
    backgroundColor: alpha(screen, 0.96), borderBottom: edge(ruleLine),
  }),
  rule("workspace-tab", {
    minHeight: 28, minWidth: 72, paddingLeft: 11, paddingRight: 11,
    color: dim, backgroundColor: "transparent", border: none,
    borderRadius: 0, fontFamily: "mono", fontSize: 12,
  }),
  rule("workspace-tab-active", {
    color: bright, backgroundColor: alpha(surface, 0.6),
    borderBottom: edge(teal, 2), outline: none, outlineOffset: 0,
  }),
  rule("workspace-lock", { position: "relative", height: 32, flexShrink: 0 }, { within: "workspace-heading" }),
  rule("btn-icon", {
    position: "absolute", left: 0, top: 0, width: 32, height: 32,
    pointerEvents: "none", zIndex: 1,
  }, { within: "workspace-lock" }),
  rule("workspace-link-lock", {
    minWidth: 64, minHeight: 28, paddingLeft: 30, paddingRight: 8,
    whiteSpace: "nowrap",
  }, { within: "workspace-heading" }),
  rule("workspace-program-strip", {
    width: "100%", minWidth: 0, minHeight: 34, alignItems: "center", gap: 8,
    paddingTop: 5, paddingBottom: 5, paddingLeft: 9, paddingRight: 9,
    backgroundColor: alpha(surface, 0.9), borderBottom: edge(line),
  }),
  rule("workspace-program-summary", {
    minWidth: 0, flexGrow: 1, color: dim, fontFamily: "mono", fontSize: 11,
    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("workspace-controls-body", {
    width: "100%", minWidth: 0, minHeight: 0, flexShrink: 0, gap: 8,
  }),
  rule("workspace-control-grid", {
    display: "grid", width: "100%", minWidth: 0, gap: 8, alignItems: "start",
    gridTemplateColumns: { repeat: "auto-fit", min: 400, max: "1fr" },
  }),
  rule("workspace-control-card", {
    width: "100%", minWidth: 0, minHeight: 0, flexShrink: 0, gap: 6, padding: 8,
    backgroundColor: alpha(field, 0.95), border: edge(line), borderRadius: 0,
  }),
  rule("gauge", {
    height: 4, marginTop: 1, marginBottom: 1, backgroundColor: screen,
    border: edge(ruleLine), accentColor: teal,
  }, { within: "workspace-control-card" }),
  rule("workspace-control-header", {
    width: "100%", minWidth: 0, minHeight: 40, alignItems: "center", gap: 8,
    paddingBottom: 6, borderBottom: edge(ruleLine),
  }),
  rule("workspace-control-icon", { width: 24, height: 24, flexShrink: 0 }),
  rule("workspace-control-identity", { minWidth: 0, flexGrow: 1, gap: 1 }),
  rule("workspace-control-name", {
    minWidth: 0, color: ink, fontFamily: "mono", fontSize: 15,
    fontWeight: "bold", lineHeight: 1.15, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("workspace-control-address-row", { minWidth: 0, alignItems: "center", gap: 7 }),
  rule("workspace-control-address", {
    minWidth: 0, flexGrow: 1, color: dim, fontFamily: "mono", fontSize: 11,
    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("workspace-control-status", { flexShrink: 0, fontFamily: "mono", fontSize: 11, whiteSpace: "nowrap" }),
  rule("workspace-control-status-gone", { color: dim }),
  rule("workspace-control-disabled", {
    color: dim, fontSize: 11, paddingTop: 4, paddingBottom: 4,
    borderBottom: edge(ruleLine),
  }),
  rule("workspace-control-notice", { color: dim, fontSize: 11, paddingTop: 3, paddingBottom: 3 }),
  rule("workspace-readout-grid", {
    display: "grid", width: "100%", minWidth: 0, gap: 5,
    gridTemplateColumns: { repeat: "auto-fit", min: 110, max: "1fr" },
  }),
  rule("workspace-readout-tile", {
    minWidth: 0, minHeight: 54, justifyContent: "center", gap: 2, padding: 7,
    backgroundColor: alpha(screen, 0.72), border: edge(ruleLine),
  }),
  rule("workspace-readout-label", {
    minWidth: 0, color: dim, fontFamily: "mono", fontSize: 11,
    lineHeight: 1.3, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("workspace-readout-value", {
    minWidth: 0, color: ink, fontFamily: "mono", fontSize: 18,
    lineHeight: 1.3, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("workspace-control-section", { minWidth: 0, flexShrink: 0, gap: 4, marginTop: 2 }),
  rule("workspace-control-section-title", {
    color: bright, fontFamily: "mono", fontSize: 11, fontWeight: "bold",
    paddingTop: 3, paddingBottom: 3, borderBottom: edge(ruleLine),
  }),
  rule("workspace-control-group-label", {
    color: dim, fontFamily: "mono", fontSize: 11, paddingTop: 3,
  }),
  rule("workspace-control-row", {
    width: "100%", minWidth: 0, minHeight: 40, alignItems: "center", gap: 8,
    paddingTop: 5, paddingBottom: 5, paddingLeft: 7, paddingRight: 7,
    backgroundColor: alpha(surface, 0.42), border: edge(ruleLine), borderRadius: 0,
  }),
  rule("workspace-control-label", {
    minWidth: 0, color: ink, fontSize: 12, lineHeight: 1.3,
    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("workspace-control-label-block", { minWidth: 0, flexGrow: 1, gap: 1 }),
  rule("workspace-control-range", {
    minWidth: 0, color: dim, fontFamily: "mono", fontSize: 11,
    lineHeight: 1.3, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("workspace-control-value", { flexShrink: 0, color: ink, fontFamily: "mono", fontSize: 12 }),
  rule("workspace-control-actions", { flexShrink: 0, alignItems: "center", gap: 4 }),
  rule("workspace-control-action", {
    minWidth: 28, minHeight: 28, fontSize: 11, whiteSpace: "nowrap",
  }),
  rule("workspace-control-step-button", {
    width: 28, minWidth: 28, minHeight: 28, paddingLeft: 2, paddingRight: 2,
    fontSize: 11, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
  }),
  rule("workspace-control-input", { width: 80, minWidth: 80, flexGrow: 0 }),
  rule("workspace-setpoint-row", { minHeight: 44 }),
  rule("workspace-setpoint-controls", { flexShrink: 0, alignItems: "center", gap: 4 }),
  rule("workspace-setpoint-input", { width: 80, minWidth: 80, flexGrow: 0, textAlign: "right" }),
  rule("workspace-control-unit", { flexShrink: 0, color: dim, fontFamily: "mono", fontSize: 11 }),
  rule("workspace-choice-strip", { width: "100%", minWidth: 0, gap: 4, alignItems: "stretch" }),
  rule("workspace-choice-grid", { width: "100%", minWidth: 0, gap: 4 }),
  rule("choice", { minHeight: 32, paddingTop: 4, paddingBottom: 4 }, { within: "workspace-choice-strip" }),
  rule("choice", { minHeight: 32, paddingTop: 4, paddingBottom: 4 }, { within: "workspace-choice-grid" }),
  rule("choice-label", { lineHeight: 1.2 }, { within: "workspace-choice-strip" }),
  rule("choice-label", { lineHeight: 1.2, whiteSpace: "normal", textOverflow: "clip" }, { within: "workspace-choice-grid" }),
  rule("workspace-details-body", { width: "100%", minWidth: 0, minHeight: 0, gap: 6 }),
];
