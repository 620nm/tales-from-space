// The computer screen: the glass a desktop or a programming workspace is
// drawn on, and what the kit's classes become under it. The screen root
// carries `computer-screen` (ui/documents-desktop.ts), so the kit's
// look inside it is scoped with `within` rather than tagged per node.
import type { UiStyleRule } from "@lunatic/ui";
import { kitTheme, rule } from "@lunatic/ui";
import { roles, screenRoles } from "./roles";
import { cover, edge, none } from "./parts";
import { alpha, black, dim, phosphor, screen, surface } from "./tokens";

const SCREEN = "computer-screen";
/** The kit classes the screen draws, restyled by what `screenRoles`
 *  changes about each: the differing props only, scoped under the screen. */
function screenKit(classes: string[]): UiStyleRule[] {
  const base = kitTheme(roles);
  const out: UiStyleRule[] = [];
  kitTheme(screenRoles).forEach((seen, index) => {
    const plain = base[index]!;
    if (!classes.includes(seen.class)) return;
    const props: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(seen.props))
      if (JSON.stringify(value) !== JSON.stringify(plain.props[key as keyof typeof plain.props])) props[key] = value;
    if (Object.keys(props).length)
      out.push(rule(seen.class, props, { state: seen.state, within: SCREEN }));
  });
  return out;
}

export const workspaceRules: UiStyleRule[] = [
  rule(SCREEN, {
    position: "relative", display: "block", width: "100%", height: "100%", minHeight: 0,
    padding: 0, gap: 0, backgroundColor: screen, border: none, borderRadius: 0, overflow: "hidden",
    fontFamily: "mono", color: phosphor,
  }),
  ...screenKit(["btn", "btn-default", "btn-ghost", "list-value", "card", "gauge", "notice", "section-title"]),
  rule("entry", { borderRadius: 0 }, { within: SCREEN }),
  rule("area", { borderRadius: 0 }, { within: SCREEN }),

  rule("desktop-wallpaper", { ...cover, imageRendering: "pixelated", pointerEvents: "none" }),
  rule("computer-workspace", { position: "relative", width: "100%", height: "100%", minWidth: 740, minHeight: 0, padding: 10, gap: 8, overflow: "hidden" }),
  rule("computer-off", { backgroundColor: black, justifyContent: "start" }),
  // A translucent frame over the wallpaper: information, a drive, the reader.
  rule("workspace-frame", { backgroundColor: alpha(surface, 0.8), border: edge(alpha(dim, 0.5)), borderRadius: 0, padding: 8, gap: 6, minHeight: 0 }),
  rule("workspace-information", { flexShrink: 0, gap: 3, maxHeight: 180, overflow: "auto" }),
  rule("workspace-heading", { justifyContent: "space-between", alignItems: "center", gap: 6 }),
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
  rule("workspace-file", { gap: 0, paddingBottom: 4, borderBottom: edge(alpha(dim, 0.25)) }),
  rule("workspace-file-name", { minWidth: 0, flexShrink: 1, whiteSpace: "normal", textAlign: "left" }),
  rule("workspace-read-only", {
    padding: 0, border: none, borderRadius: 0, backgroundColor: "transparent", color: dim,
    fontFamily: "mono", fontSize: 10, textTransform: "uppercase", letterSpacing: 0.5, flexShrink: 0,
  }),
  rule("workspace-editor", { backgroundColor: alpha(surface, 0.9), minHeight: 0, overflow: "hidden", minWidth: 0 }),
  rule("workspace-reader", { flexGrow: 1, minHeight: 0, overflow: "auto", gap: 7 }),
  rule("workspace-editor-area", { flexGrow: 1, minHeight: 0, backgroundColor: alpha(screen, 0.9) }),
];
