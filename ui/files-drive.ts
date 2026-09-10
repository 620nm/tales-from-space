// One drive of the workspace: its letter over the files on it, the
// store's readings and the presses that make a file under them.
import type { UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { DocumentIdentity, FileRow, ModuleState, StoreRow } from "./document-model";
import { documentAction } from "./document-action";
import { bodyId, guard } from "./files-buffer";
import { createFilePress } from "./files-create";
import { labelText } from "./labels";
import { column, entry, icon, press, row, screen, some, text } from "./view";
import * as S from "./strings";

export function drivePane(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, store: StoreRow, active: boolean): UiNode {
  const side = store.key ?? "host";
  const key = `${id}/drive/${side}`;
  const destination = state.stores?.find((other) => other.binding !== store.binding);
  const stem = `${key}/stem`;
  const full = store.used >= store.capacity || store.count >= store.count_cap;
  const files = (state.files ?? []).filter((file) => file.store === side);
  return screen(key, {
    toolbar: [
      text(`${key}/letter`, S.tfs(side === "host" ? "ui.workspace.drive_a" : "ui.workspace.drive_b"), ["workspace-drive-title"]),
      text(`${key}/name`, labelText(store.label), ["hint"]),
    ],
    body: files.length ? files.map((file, index) => fileRow(id, doc, `${key}/file/${index}`, file, side, active, stem, destination))
      : [text(`${key}/empty`, S.tfs("ui.workspace.empty"), ["hint"])],
    footer: [Stack(`${key}/foot`, some(
      full ? text(`${key}/full`, S.tfs("ui.workspace.full"), ["workspace-drive-full"]) : null,
      text(`${key}/capacity`, S.storeUse(store.used, store.capacity, store.count, store.count_cap), ["hint"]),
      text(`${key}/stem-label`, S.tfs("ui.workspace.destination_name"), ["hint"]),
      { ...entry(stem, "", () => undefined, { submitOnly: true, revision: 0 }), label: S.tfs("ui.workspace.destination_name") },
      createFilePress(id, store, state.create?.[side] ?? [], active),
      side === "media" ? press(`${key}/eject`, S.tfs("ui.workspace.eject"),
        guard(id, documentAction(doc, "toggle", { field: "media_eject", option: store.binding }), "media"),
        { submit: bodyId(id), disabled: !active }) : null,
    ), { dir: "column", gap: 4, cls: ["grow"] })],
  }, { cls: ["workspace-frame"] });
}

/** A file: its icon, name and size on one line, what can be done to it
 *  on the next. Eight nodes and no inline style: two full drives stand
 *  at the tree's node and byte budgets, so the rows wear classes and the
 *  read-only mark is one text in the chip's clothes rather than the
 *  kit's three-node `Chip`. */
function fileRow(
  id: string, doc: DocumentIdentity, item: string, file: FileRow, side: string,
  active: boolean, stem: string, destination: StoreRow | undefined,
): UiNode {
  const option = `${side}:${file.uid}:${file.binding}`;
  return column(item, [
    row(`${item}/head`, some(
      icon(`${item}/icon`, `file_${file.ext}`),
      press(`${item}/open`, S.fileName(file.name, file.ext), guard(id, documentAction(doc, "toggle", { field: "file_open", option })),
        { variant: file.open ? "selected" : "ghost", disabled: !active, submit: bodyId(id), cls: ["workspace-file-name"] }),
      text(`${item}/size`, S.bytes(file.size), ["fsize"]),
    ), { cls: ["workspace-file-head"] }),
    row(`${item}/actions`, some(
      file.fixed ? text(`${item}/read-only`, S.tfs("ui.files.read_only"), ["chip", "chip-key"]) : null,
      destination ? press(`${item}/copy`, S.COPY, (e) => {
        const requested = e.values?.stem?.value;
        if (requested === undefined) return undefined;
        return documentAction(doc, "text", {
          field: "file_copy", option: `${option}:${destination.binding}`, text: requested || file.name,
        });
      }, { submitValues: { stem }, disabled: !active }) : null,
      file.fixed ? null : press(`${item}/delete`, S.DELETE, guard(id, documentAction(doc, "toggle", { field: "file_delete", option }), side),
        { submit: bodyId(id), variant: "danger", disabled: !active }),
    ), { cls: ["workspace-file-actions"] }),
  ], { cls: ["workspace-file", ...(file.open ? ["workspace-file-selected"] : [])] });
}
