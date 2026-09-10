import { rule } from "@lunatic/ui";
import { dim, edge, none } from "./theme-tokens";

export const workspaceRules = [
  rule("computer-screen", {
    position: "relative", display: "block", width: "100%", height: "100%", minHeight: 0,
    padding: 0, gap: 0, backgroundColor: "#101b23", border: none, borderRadius: 0, overflow: "hidden",
  }),
  rule("desktop-wallpaper", {
    position: "absolute", top: 0, left: 0, width: "100%", height: "100%", pointerEvents: "none",
  }),
  rule("computer-workspace", {
    position: "relative", width: "100%", height: "100%", minWidth: 740, minHeight: 0,
    padding: 10, gap: 8, overflow: "hidden",
  }),
  rule("computer-off", { backgroundColor: "#000000", justifyContent: "start" }),
  rule("workspace-frame", {
    backgroundColor: "#15262fcc", border: edge("#8da5ae80"), borderRadius: 2,
    padding: 8, gap: 6, minHeight: 0,
  }),
  rule("workspace-information", { flexShrink: 0, gap: 3, maxHeight: 180, overflow: "auto" }),
  rule("workspace-controls", { flexShrink: 0, gap: 4, alignItems: "center" }),
  rule("workspace-power", { fontSize: 14, lineHeight: 1, paddingLeft: 6, paddingRight: 6 }),
  rule("workspace-machine-name", { fontSize: 14, fontWeight: "bold" }),
  rule("workspace-panes", { flexGrow: 1, minHeight: 0, width: "100%", overflow: "hidden" }),
  rule("workspace-drive", { minHeight: 0, overflow: "hidden", minWidth: 0 }),
  rule("workspace-drive-title", { fontSize: 17, fontWeight: "bold" }),
  rule("workspace-stem", { flexGrow: 1, flexShrink: 1, height: 28, minHeight: 28 }),
  rule("workspace-ext", { flexGrow: 0, flexShrink: 0, width: "auto", height: 28, minHeight: 28, fontFamily: "mono" }),
  rule("workspace-create", { flexShrink: 0, gap: 4 }),
  rule("workspace-drive-list", { flexGrow: 1, minHeight: 32, overflow: "auto", gap: 7 }),
  rule("workspace-file", { gap: 0, paddingBottom: 4, borderBottom: edge("#8da5ae40") }),
  rule("workspace-file-icon", { width: 32, height: 32, minWidth: 32, flexShrink: 0, imageRendering: "pixelated" }),
  rule("workspace-file-name", { minWidth: 0, flexShrink: 1, whiteSpace: "normal", textAlign: "left" }),
  rule("workspace-read-only", {
    padding: 0, border: none, borderRadius: 0, backgroundColor: "transparent", color: dim,
    fontFamily: "mono", fontSize: 10, textTransform: "uppercase", letterSpacing: 0.5, flexShrink: 0,
  }),
  rule("workspace-editor", { backgroundColor: "#15262fe6", minHeight: 0, overflow: "hidden", minWidth: 0 }),
  rule("workspace-reader", { flexGrow: 1, minHeight: 0, overflow: "auto", gap: 7 }),
  rule("workspace-editor-area", { flexGrow: 1, minHeight: 0, backgroundColor: "#08131ce6" }),
];
