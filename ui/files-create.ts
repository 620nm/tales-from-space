// Making a file on one drive: the press in the drive's foot, and the
// dialog it opens over the workspace with a stem, a type, Create or Cancel.
import type { UiEvent, UiNode } from "@lunatic/ui";
import { Dialog, Stack } from "@lunatic/ui";
import type { DocumentIdentity, StoreRow } from "./document-model";
import { documentAction } from "./document-action";
import { bodyId, closeCreateDialog, createDialog, guard, openCreateDialog } from "./files-buffer";
import { entry, press, select, text } from "./view";
import type { Command } from "./view";
import * as S from "./strings";

const dialogKey = (id: string, side: string): string => `${id}/${side}`;

export function createFilePress(id: string, store: StoreRow, exts: string[], active: boolean): UiNode {
  const side = store.key ?? "host";
  return press(`${id}/drive/${side}/create`, S.tfs("ui.files.create"), () => {
    if (exts[0]) openCreateDialog(dialogKey(id, side), exts[0]);
    return undefined;
  }, { disabled: !active || !exts.length });
}

/** The open dialog of one drive, or nothing while none is. */
export function createFileDialog(id: string, doc: DocumentIdentity, store: StoreRow, exts: string[], active: boolean): UiNode | null {
  const side = store.key ?? "host";
  const key = `${id}/drive/${side}/create`;
  const dialog = createDialog(dialogKey(id, side));
  if (!dialog || !exts.includes(dialog.ext)) return null;
  const stem = `${key}/stem`;
  const ext = `${key}/ext`;
  const create = (event: UiEvent): Command | undefined => {
    const requested = event.values?.stem?.value;
    if (requested === undefined) return undefined;
    const picked = event.values?.ext?.value ?? dialog.ext;
    if (!exts.includes(picked)) return undefined;
    const command = documentAction(doc, "text", { field: "file_create", option: `${side}:${picked}:${store.binding}`, text: requested });
    // A dirty editor parks the command behind its guard; the dialog stays
    // until the guard resolves, so a cancelled discard loses nothing.
    const handler = guard(id, command, undefined, () => closeCreateDialog(dialogKey(id, side)));
    return typeof handler === "function" ? handler(event) : handler;
  };
  const cancel = (): undefined => { closeCreateDialog(dialogKey(id, side)); return undefined; };
  return Dialog(`${key}/dialog`, {
    title: S.tfs("ui.files.create"),
    body: [
      text(`${key}/caption`, S.tfs("ui.files.create_caption"), ["hint"]),
      Stack(`${key}/name`, [
        entry(stem, "", () => undefined, { submitOnly: true, revision: 0 }),
        select(ext, dialog.ext, exts.map((value) => ({ value, text: S.extension(value) })), (value) => {
          if (exts.includes(value)) openCreateDialog(dialogKey(id, side), value);
          return undefined;
        }, { disabled: !active }),
      ], { gap: 4, align: "center" }),
    ],
    actions: [
      press(`${key}/cancel`, S.tfs("ui.files.cancel"), cancel, { variant: "ghost" }),
      press(`${key}/confirm`, S.tfs("ui.files.create_confirm"), create,
        { submit: bodyId(id), submitValues: { stem, ext }, variant: "primary", disabled: !active }),
    ],
    // The scrim is the same press as Cancel: one meaning, registered once.
  }, { dismissEvent: `${key}/cancel`, dismissLabel: S.tfs("ui.files.cancel") });
}
