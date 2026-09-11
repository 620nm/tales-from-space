// One drive of the workspace: its letter over the files on it, the
// store's readings and the presses that make a file under them.
import type { UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { DocumentIdentity, FileRow, ModuleState, StoreRow } from "./document-model";
import { documentAction } from "./document-action";
import { bodyId, guard } from "./files-buffer";
import { createFilePress } from "./files-create";
import { labelText } from "./labels";
import { column, icon, press, row, screen, some, text } from "./view";
import * as S from "./strings";

/** Drive letters per engine store drive: an owner's own store A:, the disk
 *  in its slot B: (engine `docs/tgui/files.md`). */
const LETTER: Record<string, string> = { host: "ui.workspace.drive_a", media: "ui.workspace.drive_b" };
const COPY_TO: Record<string, string> = { host: "ui.files.copy_to_a", media: "ui.files.copy_to_b" };

/** Where a drive's files copy to: the store the opposite pane shows, the
 *  press's id suffix, and its caption. */
export interface CopyTarget { store: StoreRow; suffix: string; label: string }

export function driveLetter(drive?: string): string {
  return LETTER[drive ?? "host"] ?? LETTER.host!;
}

/** The drive a store row is: its `drive`, or its side on a plain panel. */
function driveOf(store: StoreRow): string {
  return store.drive ?? (store.key === "media" ? "media" : "host");
}

/** A plain desktop's copy into its other drive, named by that letter. */
export function plainCopy(store: StoreRow): CopyTarget {
  return { store, suffix: "copy", label: S.tfs(COPY_TO[driveOf(store)] ?? COPY_TO.host!) };
}

export function drivePane(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, store: StoreRow,
  active: boolean, copy?: CopyTarget): UiNode {
  const side = store.key ?? "host";
  const key = `${id}/drive/${side}`;
  const full = store.used >= store.capacity || store.count >= store.count_cap;
  const files = (state.files ?? []).filter((file) => file.store === side);
  return screen(key, {
    toolbar: [
      text(`${key}/letter`, S.tfs(driveLetter(driveOf(store))), ["workspace-drive-title"]),
      text(`${key}/name`, labelText(store.label), ["hint"]),
    ],
    body: files.length ? files.map((file, index) => fileRow(id, doc, `${key}/file/${index}`, file, side, active, copy))
      : [text(`${key}/empty`, S.tfs("ui.workspace.empty"), ["hint"])],
    footer: [Stack(`${key}/foot`, some(
      full ? text(`${key}/full`, S.tfs("ui.workspace.full"), ["workspace-drive-full"]) : null,
      text(`${key}/capacity`, S.storeUse(store.used, store.capacity, store.count, store.count_cap), ["hint"]),
      createFilePress(id, store, state.create?.[side] ?? [], active),
      driveOf(store) === "media" ? press(`${key}/eject`, S.tfs("ui.workspace.eject"),
        guard(id, documentAction(doc, "toggle", { field: "media_eject", option: store.binding }), side),
        { submit: bodyId(id), disabled: !active }) : null,
    ), { dir: "column", gap: 4, cls: ["grow"] })],
  }, { cls: ["workspace-frame"] });
}

/** A file: its icon, name and size on one line, what can be done to it
 *  on the next. Eight nodes and no inline style: two full drives stand
 *  at the tree's node and byte budgets, so the rows wear classes and the
 *  read-only mark is one text in the chip's clothes rather than the
 *  kit's three-node `Chip`. One copy press, into the opposite pane's
 *  drive, and none while that pane shows no drive. */
function fileRow(
  id: string, doc: DocumentIdentity, item: string, file: FileRow, side: string,
  active: boolean, copy?: CopyTarget,
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
      copy ? press(`${item}/${copy.suffix}`, copy.label,
        documentAction(doc, "text", { field: "file_copy", option: `${option}:${copy.store.binding}`, text: file.name }),
        { disabled: !active }) : null,
      file.fixed ? null : press(`${item}/delete`, S.DELETE, guard(id, documentAction(doc, "toggle", { field: "file_delete", option }), side),
        { submit: bodyId(id), variant: "danger", disabled: !active }),
    ), { cls: ["workspace-file-actions"] }),
  ], { cls: ["workspace-file", ...(file.open ? ["workspace-file-selected"] : [])] });
}
