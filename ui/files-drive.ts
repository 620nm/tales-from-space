import type { UiNode } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, StoreRow } from "./document-model";
import { documentAction } from "./document-action";
import { bodyId, guard } from "./files-buffer";
import { labelText } from "./labels";
import { column, entry, icon, press, row, some, text } from "./view";
import * as S from "./strings";

export function drivePane(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, store: StoreRow, active: boolean): UiNode {
  const side = store.key ?? "host";
  const key = `${id}/drive/${side}`;
  const destination = state.stores?.find((other) => other.binding !== store.binding);
  const stem = `${key}/stem`;
  const files = (state.files ?? []).filter((file) => file.store === side);
  return column(key, [
    text(`${key}/letter`, S.tfs(side === "host" ? "ui.workspace.drive_a" : "ui.workspace.drive_b"), ["workspace-drive-title"]),
    text(`${key}/name`, labelText(store.label), ["list-label"]),
    column(`${key}/list`, files.map((file, index) => {
      const item = `${key}/file/${index}`;
      const option = `${side}:${file.uid}:${file.binding}`;
      return column(item, [
        row(`${item}/head`, some(
          icon(`${item}/icon`, `file_${file.ext}`, "", ["workspace-file-icon"]),
          press(`${item}/open`, S.fileName(file.name, file.ext), guard(id, documentAction(doc, "toggle", { field: "file_open", option })),
            { variant: file.open ? "selected" : "ghost", disabled: !active, submit: bodyId(id), cls: ["workspace-file-name"] }),
        )),
        row(`${item}/actions`, some(
          text(`${item}/size`, S.bytes(file.size), ["fsize"]),
          destination ? press(`${item}/copy`, S.COPY, (e) => {
            const requested = e.values?.stem?.value;
            if (requested === undefined) return undefined;
            return documentAction(doc, "text", {
              field: "file_copy", option: `${option}:${destination.binding}`, text: requested || file.name,
            });
          }, { submitValues: { stem }, variant: "ghost", disabled: !active }) : null,
          press(`${item}/delete`, S.DELETE, guard(id, documentAction(doc, "toggle", { field: "file_delete", option }), side),
            { submit: bodyId(id), variant: "ghost", disabled: !active || file.fixed }),
        ), { style: { flexWrap: "wrap", gap: 3 } }),
      ], { cls: ["workspace-file"] });
    }), { cls: ["workspace-drive-list"] }),
    text(`${key}/capacity`, S.storeUse(store.used, store.capacity, store.count, store.count_cap), ["hint"]),
    text(`${key}/stem-label`, S.tfs("ui.workspace.destination_name"), ["hint"]),
    entry(stem, "", () => undefined, { submitOnly: true, revision: 0, cls: ["workspace-stem"] }),
    row(`${key}/new`, (state.create?.[side] ?? []).map((ext) => press(`${key}/new/${ext}`, S.tfs("ui.files.new", { ext }),
      (event) => {
        const requested = event.values?.stem?.value;
        if (requested === undefined) return undefined;
        const handler = guard(id, documentAction(doc, "text", { field: "file_create", option: `${side}:${ext}:${store.binding}`, text: requested }));
        return typeof handler === "function" ? handler(event) : handler;
      }, { submit: bodyId(id), submitValues: { stem }, disabled: !active })), { style: { gap: 4, flexWrap: "wrap" } }),
    ...(side === "media" && !state.contact_store ? [press(`${key}/eject`, S.tfs("ui.workspace.eject"),
      guard(id, documentAction(doc, "toggle", { field: "media_eject", option: store.binding }), "media"),
      { submit: bodyId(id), disabled: !active })] : []),
  ], { cls: ["workspace-frame", "workspace-drive"] });
}
