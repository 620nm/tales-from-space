// The computer screen: the glass a desktop or a programming workspace is
// drawn on, and what the kit's classes become under it. The glass
// carries `computer-screen` (ui/documents-desktop.ts), so the kit's
// look inside it is scoped with `within` rather than tagged per node.
// The workspace is a kit Screen scrolling sideways, its panes Screens
// of their own: nothing here declares an overflow.
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
    fontFamily: "mono", fontSize: 13, color: phosphor,
  }),
  ...screenKit([
    "btn", "btn-default", "btn-ghost", "list-value", "card", "gauge", "notice", "section-title",
    "chip", "dialog", "dropdown", "tab", "tab-on",
  ]),
  rule("entry", { borderRadius: 0 }, { within: SCREEN }),
  rule("area", { borderRadius: 0 }, { within: SCREEN }),
  rule("scroll", { gap: 6 }, { within: SCREEN }),

  rule("desktop-wallpaper", { ...cover, imageRendering: "pixelated", pointerEvents: "none" }),
  rule("computer-workspace", { padding: 8, gap: 6 }),
  rule("computer-off", { backgroundColor: black }),
  // A translucent frame over the wallpaper: the heading, a drive, the reader.
  rule("workspace-frame", { backgroundColor: alpha(surface, 0.92), border: edge(alpha(dim, 0.65)), borderRadius: 0, padding: 8, gap: 6 }),
  rule("workspace-machine-name", { fontSize: 15, fontWeight: "bold" }),
  rule("workspace-drive-title", { fontSize: 15, fontWeight: "bold" }),
  // A file's two lines wear classes rather than an inline style: two
  // full drives stand at the tree's byte budget (ui/files-drive.ts).
  rule("workspace-file", { flexShrink: 0, gap: 2, paddingBottom: 4, borderBottom: edge(alpha(dim, 0.25)) }),
  rule("workspace-file-selected", { borderLeft: edge(phosphor, 3), paddingLeft: 4, backgroundColor: alpha(phosphor, 0.08) }),
  rule("workspace-drive-full", { fontSize: 11, fontWeight: "bold", borderBottom: edge(phosphor) }),
  rule("workspace-offline", { padding: 16, fontSize: 13, color: dim }),
  rule("workspace-file-head", { alignItems: "center", gap: 4 }),
  rule("workspace-file-name", { flexGrow: 1, minWidth: 0, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", textAlign: "left" }),
  // Wraps rather than squeezing: a contact file offers a copy per far drive.
  rule("workspace-file-actions", { justifyContent: "end", alignItems: "center", gap: 3, flexWrap: "wrap" }),
  rule("workspace-editor", { backgroundColor: alpha(surface, 0.9) }),
  rule("workspace-editor-area", { flexGrow: 1, backgroundColor: alpha(screen, 0.9) }),
];
