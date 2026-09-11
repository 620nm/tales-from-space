// Laptop scripts supply wallpaper and power; native providers supply files.
import type { Json, ScreenParts, UiNode } from "@lunatic/ui";
import { Pane, Stack } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, ScriptState } from "./document-model";
import { documentAction } from "./document-action";
import { bodyId } from "./files-buffer";
import { filePanes, guard, workspaceHeading, type Identity } from "./files";
import { refusalDialog } from "./documents-device";
import { icon, press, screen, some, text } from "./view";
import { tfs } from "./strings";

interface DesktopData { kind: "desktop"; wallpaper?: string; powered?: boolean; card?: boolean; cartridge?: boolean }
export function isDesktop(data: Json | undefined): data is Json & DesktopData {
  return data !== null && typeof data === "object" && !Array.isArray(data) && data.kind === "desktop";
}
function programming(data: Json | undefined): Record<string, Json> | undefined {
  return data && typeof data === "object" && !Array.isArray(data) && data.kind === "programming" ? data : undefined;
}
export function programmingWallpaper(data: Json | undefined): string | undefined {
  const view = programming(data);
  if (!view) return undefined;
  return view.wallpaper === "wallpaper_moonlake" ? "wallpaper_moonlake" : "wallpaper_bliss";
}
/** The laptop a contact is worked through, as its script names it: the
 *  window's title wears it while the workspace bar names the target. */
export function programmingTool(data: Json | undefined): Identity | undefined {
  const view = programming(data);
  if (!view) return undefined;
  const tool = view.tool;
  if (!tool || typeof tool !== "object" || Array.isArray(tool)) return {};
  return {
    sprite: typeof tool.sprite === "string" ? tool.sprite : undefined,
    name: typeof tool.name === "string" ? tool.name : undefined,
  };
}
/** A contact over a shut lock: the engine composes only the link rows
 *  (`contact_locked`); Unlock is its lock row's own press, so access is
 *  checked natively, success widens this same document and a refusal
 *  comes back as its `refusal` modal. */
export function lockParts(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean): ScreenParts {
  const lock = state.toggles?.find((row) => row.field === "link_lock");
  const refusal = refusalDialog(id, doc, state);
  return {
    toolbar: [workspaceHeading(id, doc, state, tfs("ui.workspace.locked"))],
    body: [Stack(`${id}/lock`, some(
      text(`${id}/lock/hint`, tfs("ui.workspace.locked_hint"), ["workspace-offline"]),
      lock ? press(`${id}/toggle/link_lock/switch`, tfs("ui.workspace.unlock"),
        documentAction(doc, "toggle", { field: "link_lock" }), { disabled: !active }) : null,
    ), { dir: "column", gap: 8, align: "center", cls: ["workspace-frame"] })],
    ...(refusal ? { overlay: [refusal] } : {}),
  };
}
export function desktopPane(id: string, doc: DocumentIdentity, state: Partial<ScriptState>, active: boolean, native?: Partial<ModuleState>): UiNode {
  const data = state.data as Json & DesktopData;
  const wallpaper = data.wallpaper === "wallpaper_moonlake" ? "wallpaper_moonlake" : "wallpaper_bliss";
  // The power glyph is the kit's icon press, named by what it does.
  const action = (name: string, label: string, glyph?: string): UiNode => press(
    `${id}/${name}`, glyph ?? tfs(label), name === "power"
      ? guard(id, documentAction(doc, name, {})) : documentAction(doc, name, {}),
    { submit: bodyId(id), disabled: !active || !state.actions?.some((offered) => offered.id === name),
      ...(glyph ? { label: tfs(label), cls: ["btn-glyph"] } : {}) },
  );
  const controls = [
    ...(data.card ? [action("eject_id", "ui.desktop.eject_id")] : []),
    ...(data.cartridge && !data.powered ? [action("eject_cartridge", "ui.desktop.eject_cartridge")] : []),
    action("power", data.powered ? "ui.desktop.power_off" : "ui.desktop.power_on", POWER_GLYPH),
  ];
  const parts: ScreenParts = data.powered && native?.stores
    ? filePanes(id, doc, native, active, controls)
    : { toolbar: [Stack(`${id}/heading`, some(
      icon(`${id}/machine-icon`, native?.owner_sprite ?? doc.owner_sprite, doc.title),
      text(`${id}/machine-name`, native?.name ?? doc.title, ["workspace-machine-name", "grow"]),
      Stack(`${id}/machine-controls`, controls, { gap: 4, align: "center" }),
    ), { gap: 8, align: "center", cls: ["workspace-frame"], style: { width: "100%" } })],
      body: [text(`${id}/offline`, tfs("ui.workspace.offline"), ["workspace-offline"])] };
  return computerPane(id, parts, data.powered ? wallpaper : undefined, !data.powered);
}
const POWER_GLYPH = "⏻";
/** The glass: the wallpaper beneath, and the workspace screen over it,
 *  which scrolls sideways when a window is narrower than its panes. */
export function computerPane(id: string, parts: ScreenParts, wallpaper?: string, off = false): UiNode {
  return Pane(id, [
    ...(wallpaper ? [{ id: `${id}/wallpaper`, type: "image" as const, asset: wallpaper, class: ["desktop-wallpaper"] }] : []),
    screen(`${id}/workspace`, parts, { cls: ["computer-workspace", ...(off ? ["computer-off"] : [])], axis: "x" }),
  ], { cls: ["computer-screen"], style: { width: 1120, maxWidth: "100%" } });
}
