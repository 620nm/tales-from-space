// The create-file dialog of one drive: a stem, a type, Create or Cancel.
import type { UiEvent, UiNode } from "@lunatic/ui";
import type { DocumentIdentity, StoreRow } from "./document-model";
import { documentAction } from "./document-action";
import { bodyId, closeCreateDialog, createDialog, guard, openCreateDialog } from "./files-buffer";
import { column, entry, press, row, select, text } from "./view";
import type { Command } from "./view";
import * as S from "./strings";

export function createFile(id: string, doc: DocumentIdentity, store: StoreRow, exts: string[], active: boolean): UiNode {
  const side = store.key ?? "host";
  const key = `${id}/drive/${side}`;
  const dialogKey = `${id}/${side}`;
  const dialog = createDialog(dialogKey);
  if (!dialog || !exts.includes(dialog.ext))
    return press(`${key}/create`, S.tfs("ui.files.create"), () => {
      if (exts[0]) openCreateDialog(dialogKey, exts[0]);
      return undefined;
    }, { disabled: !active || !exts.length });
  const stem = `${key}/create/stem`;
  const ext = `${key}/create/ext`;
  const create = (event: UiEvent): Command | undefined => {
    const requested = event.values?.stem?.value;
    if (requested === undefined) return undefined;
    const picked = event.values?.ext?.value ?? dialog.ext;
    if (!exts.includes(picked)) return undefined;
    const command = documentAction(doc, "text", { field: "file_create", option: `${side}:${picked}:${store.binding}`, text: requested });
    // A dirty editor parks the command behind its guard; the dialog stays
    // until the guard resolves, so a cancelled discard loses nothing.
    const handler = guard(id, command, undefined, () => closeCreateDialog(dialogKey));
    return typeof handler === "function" ? handler(event) : handler;
  };
  return column(`${key}/create`, [
    text(`${key}/create/caption`, S.tfs("ui.files.create_caption"), ["hint"]),
    row(`${key}/create/name`, [
      entry(stem, "", () => undefined, { submitOnly: true, revision: 0, cls: ["workspace-stem"] }),
      select(ext, dialog.ext, exts.map((value) => ({ value, text: S.extension(value) })), (value) => {
        if (exts.includes(value)) openCreateDialog(dialogKey, value);
        return undefined;
      }, { cls: ["workspace-ext"], disabled: !active }),
    ], { style: { gap: 4, alignItems: "center" } }),
    row(`${key}/create/actions`, [
      press(`${key}/create/confirm`, S.tfs("ui.files.create_confirm"), create,
        { submit: bodyId(id), submitValues: { stem, ext }, variant: "primary", disabled: !active }),
      press(`${key}/create/cancel`, S.tfs("ui.files.cancel"), () => { closeCreateDialog(dialogKey); return undefined; }),
    ], { style: { gap: 4 } }),
  ], { cls: ["workspace-create"] });
}
