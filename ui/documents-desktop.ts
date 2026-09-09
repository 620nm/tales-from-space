// Laptop scripts supply wallpaper and controls; native providers supply files.
import type { Json, UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, ScriptState } from "./document-model";
import { documentAction } from "./document-action";
import { bodyId } from "./files-buffer";
import { filePanes, guard } from "./files";
import { column, panel, press, row } from "./view";
import { tfs } from "./strings";

interface DesktopData { kind: "desktop"; wallpaper?: string; powered?: boolean; card?: boolean; cartridge?: boolean }
export function isDesktop(data: Json | undefined): data is Json & DesktopData {
  return data !== null && typeof data === "object" && !Array.isArray(data) && data.kind === "desktop";
}
export function programmingWallpaper(data: Json | undefined): string | undefined {
  if (!data || typeof data !== "object" || Array.isArray(data) || data.kind !== "programming") return undefined;
  return data.wallpaper === "wallpaper_moonlake" ? "wallpaper_moonlake" : "wallpaper_bliss";
}
export function desktopPane(id: string, doc: DocumentIdentity, state: Partial<ScriptState>, active: boolean, native?: Partial<ModuleState>): UiNode {
  const data = state.data as Json & DesktopData;
  const wallpaper = data.wallpaper === "wallpaper_moonlake" ? "wallpaper_moonlake" : "wallpaper_bliss";
  const action = (name: string, label: string, node = name): UiNode => press(
    `${id}/${node}`, tfs(label), name === "power" || name === "close"
      ? guard(id, documentAction(doc, name, {})) : documentAction(doc, name, {}),
    { submit: bodyId(id), disabled: !active || !state.actions?.some((offered) => offered.id === name) },
  );
  return computerPane(id, [
    ...(data.powered && native?.stores ? filePanes(id, doc, native, active) : []),
    row(`${id}/controls`, [
      action("power", data.powered ? "ui.desktop.power_off" : "ui.desktop.power_on"),
      ...(data.card ? [action("eject_id", "ui.desktop.eject_id")] : []),
      ...(data.cartridge && !data.powered ? [action("eject_cartridge", "ui.desktop.eject_cartridge")] : []),
      action("close", "ui.desktop.close_lid", "lid"),
    ], { cls: ["desktop-controls", "workspace-frame"] }),
  ], data.powered ? wallpaper : undefined, !data.powered);
}
export function computerPane(id: string, children: UiNode[], wallpaper?: string, off = false): UiNode {
  return Pane(id, [
    ...(wallpaper ? [{ id: `${id}/wallpaper`, type: "image" as const, asset: wallpaper, class: ["desktop-wallpaper"] }] : []),
    column(`${id}/workspace`, children, { cls: ["computer-workspace", ...(off ? ["computer-off"] : [])] }),
  ], { cls: ["computer-screen"], style: { width: 1120, maxWidth: "100%" } });
}
