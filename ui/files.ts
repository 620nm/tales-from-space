// The files presentation: store readings full width, then the listing
// and the editor side by side. Submitted text is retained here until a
// server revision acknowledges it (docs/pack-ui/sdk.md).
import type { UiNode } from "@lunatic/ui";
import { LabeledList, Notice } from "@lunatic/ui";
import type {
  DocumentIdentity,
  EditorState,
  ModuleState,
  OpenFile,
  PanelDocument,
  SocketRowState,
} from "./document-model";
import { documentAction } from "./document-action";
import { labelId, labelText } from "./labels";
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

// Program-text extensions from this pack's own roster
// (content/filetypes.luau): a source entry is edited as Luau.
const SOURCE_EXTS = new Set(["disl"]);

/** The engine's editing surface, or undefined the moment a field is off. */
function editorOf(raw: ModuleState["editor"]): EditorState | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const e = raw as Partial<EditorState>;
  if (
    typeof e.body !== "string" ||
    typeof e.read_only !== "boolean" ||
    typeof e.byte_budget !== "number" ||
    !Number.isFinite(e.byte_budget) ||
    !Array.isArray(e.markers) ||
    e.markers.some(
      (m) =>
        !m ||
        typeof m !== "object" ||
        typeof m.message !== "string" ||
        (m.line !== undefined && typeof m.line !== "number"),
    ) ||
    typeof e.revision !== "number" ||
    typeof e.bound !== "boolean"
  )
    return undefined;
  return e as EditorState;
}

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
          label: labelText(store.label),
          value: S.storeUse(
            store.used ?? 0,
            store.capacity ?? 0,
            store.count ?? 0,
            store.count_cap ?? 0,
          ),
        })),
      ),
    );
  // The slot arrives as a `Label` naming which state it is in, never as
  // a bare word (docs/tgui/labels.md).
  const slot = labelId(state.media_slot);
  if (slot === "files.media.loaded")
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
  else if (slot === "files.media.empty")
    out.push(
      LabeledList(`${id}/media`, [
        { label: S.MEDIA, value: labelText(state.media_slot), tone: "idle" },
      ]),
    );
  if (state.sockets?.length) out.push(socketRows(id, doc, state, active));
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
  // A create names the side it lands on (`<side>:<ext>`), never
  // inferred (docs/files/scriptable-machine.md §2); the button says
  // which store it is, in the store's own words.
  const create = Object.entries(state.create ?? {}).flatMap(([side, exts]) => {
    const store = (state.stores ?? []).find((row) => row.key === side);
    const where = store ? labelText(store.label) : side;
    return exts.map((ext, index) =>
      press(
        `${id}/create/${side}/${index}`,
        S.newFileOn(ext, where),
        documentAction(doc, "toggle", {
          field: "file_create",
          option: `${side}:${ext}`,
        }),
        { disabled: !active },
      ),
    );
  });
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

/** The socket rows: what each declared socket runs, its counters, and
 *  the load/unload presses (engine settings/sockets.rs sends the rows;
 *  this draws them). A load candidate is a source file on the HOST
 *  store — media never runs (docs/files/scriptable-machine.md §1). */
function socketRows(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
): UiNode {
  const loadable = (state.files ?? []).filter(
    (file) => file.store === "host" && SOURCE_EXTS.has(file.ext),
  );
  const rows = (state.sockets ?? []).map((socket: SocketRowState, index) => {
    const key = `${id}/socket/${index}`;
    return column(
      key,
      some(
        row(
          `${key}/head`,
          some(
            text(`${key}/id`, socket.id, ["grow", "list-label"]),
            text(`${key}/state`, labelText(socket.state), ["hint"]),
            socket.file ? text(`${key}/file`, socket.file, ["fname"]) : null,
            text(
              `${key}/stats`,
              S.socketStats(socket.runs ?? 0, socket.faults ?? 0),
              ["fsize"],
            ),
            socket.uid !== null && socket.uid !== undefined
              ? press(
                  `${key}/unload`,
                  S.UNLOAD,
                  documentAction(doc, "toggle", {
                    field: "socket_unload",
                    option: socket.id,
                  }),
                  { variant: "ghost", disabled: !active },
                )
              : null,
          ),
          { cls: ["list-row"] },
        ),
        loadable.length
          ? row(
              `${key}/load`,
              loadable.map((file, i) =>
                press(
                  `${key}/load/${i}`,
                  S.socketLoad(S.fileName(file.name, file.ext)),
                  documentAction(doc, "toggle", {
                    field: "socket_load",
                    option: `${socket.id}:${file.uid}`,
                  }),
                  { variant: "ghost", disabled: !active },
                ),
              ),
              { style: { gap: 4, flexWrap: "wrap" } },
            )
          : null,
      ),
    );
  });
  return column(`${id}/sockets`, rows, { cls: ["card"] });
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
  const editor = editorOf(state.editor);
  return column(
    `${id}/editor`,
    some(
      text(
        `${id}/editor/title`,
        S.fileTitle(open.name, open.ext, current.dirty),
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
        ...(editor
          ? {
              disabled: editor.read_only,
              ...(SOURCE_EXTS.has(open.ext) ? { language: "luau" as const } : {}),
            }
          : {}),
      }),
      editor
        ? row(
            `${id}/editor/status`,
            [
              ...(editor.markers.length
                ? editor.markers
                    .slice(0, 8)
                    .map((m, i) =>
                      text(
                        `${id}/editor/marker/${i}`,
                        S.marker(m.line, m.message),
                        ["marker"],
                      ),
                    )
                : [text(`${id}/editor/clear`, S.MARKERS_CLEAR, ["hint"])]),
              text(`${id}/editor/budget`, S.byteBudget(editor.byte_budget), [
                "fsize",
              ]),
            ],
            { style: { gap: 8, alignItems: "baseline", flexWrap: "wrap" } },
          )
        : null,
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
            { submit: bodyId, variant: "primary", disabled: conflict || editor?.read_only },
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
