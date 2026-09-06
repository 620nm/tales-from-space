// Laptop view model: content/items/laptop.luau; engine docs/tgui/documents.md.
import type { Json, UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import type { DocumentIdentity, ScriptState } from "./document-model";
import { documentAction } from "./document-action";
import { panel, press, row } from "./view";
import { tfs } from "./strings";

interface DesktopData {
  kind: "desktop";
  wallpaper?: string;
  powered?: boolean;
  card?: boolean;
  cartridge?: boolean;
}

export function isDesktop(data: Json | undefined): data is Json & DesktopData {
  return data !== null && typeof data === "object" && !Array.isArray(data)
    && data.kind === "desktop";
}

export function desktopPane(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ScriptState>,
  head: UiNode,
  active: boolean,
): UiNode {
  const data = state.data as Json & DesktopData;
  const wallpaper = data.wallpaper === "wallpaper_moonlake"
    ? "wallpaper_moonlake" : "wallpaper_bliss";
  const action = (name: string, label: string): UiNode => press(
    `${id}/${name}`, tfs(label), documentAction(doc, name, {}),
    { disabled: !active || !state.actions?.some((offered) => offered.id === name) },
  );
  return Pane(id, [
    head,
    panel(`${id}/screen`, [
      {
        id: `${id}/wallpaper`, type: "image", asset: wallpaper,
        class: ["desktop-wallpaper"],
        style: { opacity: data.powered ? 1 : 0 },
      },
    ], { cls: ["desktop-screen"] }),
    row(`${id}/controls`, [
      action("power", data.powered ? "ui.desktop.power_off" : "ui.desktop.power_on"),
      ...(data.card ? [action("eject_id", "ui.desktop.eject_id")] : []),
      ...(data.cartridge ? [action("eject_cartridge", "ui.desktop.eject_cartridge")] : []),
      action("close", "ui.desktop.close_lid"),
    ], { cls: ["desktop-controls"] }),
  ], { cls: ["desktop"], style: { width: 662, maxWidth: "100%" } });
}
