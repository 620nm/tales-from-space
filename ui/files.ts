// The files presentation: store readings full width, then the listing
// and the editor side by side. Submitted text is retained here until a
// server revision acknowledges it (docs/pack-ui/sdk.md).
import type { UiNode } from "@lunatic/ui";
import { LabeledList, Notice } from "@lunatic/ui";
import type {
  DocumentIdentity,
  ModuleState,
  OpenFile,
  PanelDocument,
} from "./document-model";
import { documentAction } from "./document-action";
import { column, entry, panel, press, row, some, text } from "./view";
import * as S from "./strings";

interface Buffer {
  key: number;
  text: string;
  revision: number;
  dirty: boolean;
  pending?: string;
}
const buffers = new Map<string, Buffer>();
let nextEditor = 0;

export function filePanes(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
): UiNode[] {
  const stores = state.stores ?? [];
  const out: UiNode[] = [];
  if (stores.length)
    out.push(
      LabeledList(
        `${id}/stores`,
        stores.map((store) => ({
          label: store.label,
          value: S.storeUse(
            store.used ?? 0,
            store.capacity ?? 0,
            store.count ?? 0,
            store.count_cap ?? 0,
          ),
        })),
      ),
    );
  if (state.media_slot === "loaded")
    out.push(
      row(
        `${id}/media`,
        [
          text(`${id}/media/label`, S.MEDIA, ["grow", "list-label"]),
          press(
            `${id}/eject`,
            S.EJECT,
            documentAction(doc, "toggle", { field: "media_eject" }),
            { disabled: !active },
          ),
        ],
        { cls: ["list-row"] },
      ),
    );
  else if (state.media_slot === "empty")
    out.push(
      LabeledList(`${id}/media`, [
        { label: S.MEDIA, value: S.MEDIA_EMPTY, tone: "idle" },
      ]),
    );
  out.push(
    panel(
      `${id}/panes`,
      [listPane(id, doc, state, active), editorPane(id, doc, state, active)],
      {
        cls: ["panes"],
        style: {
          display: "grid",
          gridTemplateColumns: [{ min: 150, max: 210 }, "1fr"],
        },
      },
    ),
  );
  return out;
}

/** The listing: one press per entry, then what a new one may be. */
function listPane(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
): UiNode {
  const many = (state.stores ?? []).length > 1;
  const rows = (state.files ?? []).map((file, index) => {
    const key = `${id}/file/${index}`;
    const option = `${file.store}:${file.uid}`;
    return row(
      key,
      some(
        press(
          `${key}/open`,
          S.fileName(file.name, file.ext),
          documentAction(doc, "toggle", { field: "file_open", option }),
          {
            cls: file.open ? ["fname", "fopen"] : ["fname"],
            variant: file.open ? "selected" : "ghost",
            disabled: !active,
          },
        ),
        text(`${key}/size`, S.bytes(file.size ?? 0), ["fsize"]),
        many
          ? press(
              `${key}/copy`,
              S.COPY,
              documentAction(doc, "toggle", { field: "file_copy", option }),
              { variant: "ghost", disabled: !active },
            )
          : null,
        press(
          `${key}/delete`,
          S.DELETE,
          documentAction(doc, "toggle", { field: "file_delete", option }),
          { variant: "ghost", disabled: !active },
        ),
      ),
      { cls: ["filerow"] },
    );
  });
  const create = (state.create ?? []).map((ext, index) =>
    press(
      `${id}/create/${index}`,
      S.newFile(ext),
      documentAction(doc, "toggle", { field: "file_create", option: ext }),
      { disabled: !active },
    ),
  );
  return column(
    `${id}/list`,
    [
      ...rows,
      ...(create.length
        ? [row(`${id}/create`, create, { style: { gap: 4, flexWrap: "wrap" } })]
        : []),
    ],
    { cls: ["card"] },
  );
}

/** The whole-body editor for whichever entry is open. */
function editorPane(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
): UiNode {
  const open = state.open;
  if (!open)
    return column(`${id}/editor`, [text(`${id}/editor/none`, S.NO_FILE_OPEN, ["hint"])], {
      cls: ["card"],
    });
  const option = `${open.store}:${open.uid}`;
  const current = editorBuffer(`${id}/${option}`, open);
  const bodyId = `${id}/editor/body/${current.key}`;
  const conflict = current.revision !== open.revision;
  return column(
    `${id}/editor`,
    some(
      text(
        `${id}/editor/title`,
        `${S.fileName(open.name, open.ext)}${current.dirty ? ` · ${S.MODIFIED}` : ""}`,
        ["mstate"],
      ),
      conflict
        ? Notice(`${id}/editor/conflict`, S.CONFLICT, { tone: "off" })
        : null,
      row(
        `${id}/editor/rename`,
        [
          entry(`${id}/editor/name`, open.name, () => undefined, {
            submitOnly: true,
          }),
          press(
            `${id}/editor/rename-button`,
            S.RENAME,
            (e) =>
              documentAction(doc, "text", {
                field: "file_rename",
                option,
                text: e.value ?? open.name,
              }),
            { submit: `${id}/editor/name`, disabled: !active },
          ),
        ],
        { style: { gap: 4, alignItems: "center" } },
      ),
      entry(bodyId, current.text, () => undefined, {
        multiline: true,
        submitOnly: true,
        revision: current.revision,
      }),
      row(
        `${id}/editor/buttons`,
        [
          press(
            `${id}/editor/save`,
            S.SAVE,
            (e) => {
              current.text = e.value ?? current.text;
              current.revision = e.revision ?? current.revision;
              current.dirty = true;
              current.pending = current.text;
              return documentAction(doc, "text", {
                field: "file_save",
                option,
                text: current.text,
                revision: current.revision,
              });
            },
            { submit: bodyId, variant: "primary", disabled: conflict },
          ),
          press(`${id}/editor/revert`, S.REVERT, () => {
            buffers.delete(`${id}/${option}`);
            return undefined;
          }),
        ],
        { style: { gap: 4 } },
      ),
    ),
    { cls: ["card"] },
  );
}

// Keep submitted edits until a matching server revision acknowledges the save.
function editorBuffer(key: string, open: OpenFile): Buffer {
  let buffer = buffers.get(key);
  if (
    buffer?.pending !== undefined &&
    open.revision !== buffer.revision &&
    open.body === buffer.pending
  ) {
    buffer.dirty = false;
    buffer.pending = undefined;
  }
  if (!buffer) {
    buffer = {
      key: nextEditor++,
      text: open.body,
      revision: open.revision,
      dirty: false,
    };
    buffers.set(key, buffer);
  }
  if (!buffer.dirty) {
    buffer.text = open.body;
    buffer.revision = open.revision;
  }
  return buffer;
}

// A closed document must release its submitted draft, including when none remain.
export function retainOpenFileBuffers(documents: PanelDocument[]): void {
  const openKeys = new Set<string>();
  for (const doc of documents) {
    // Only a store document holds a buffer; anything else — including a
    // document with no state at all — simply has none to retain.
    const state = (doc.state ?? {}) as Partial<ModuleState>;
    const open = state.open;
    if (state.stores && open) {
      openKeys.add(`doc/${doc.id}/${doc.generation}/${open.store}:${open.uid}`);
    }
  }
  for (const key of buffers.keys()) {
    if (!openKeys.has(key)) buffers.delete(key);
  }
}
