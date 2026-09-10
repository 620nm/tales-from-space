// File reader and source views; the workspace owns the unsaved-work dialog.
import type { UiNode } from "@lunatic/ui";
import { Chip, Dialog, Notice, Stack, Tabs } from "@lunatic/ui";
import type { DocumentIdentity, EditorState, ModuleState } from "./document-model";
import { documentAction } from "./document-action";
import { bind, column, entry, press, screen, some, text } from "./view";
import * as S from "./strings";
import { fileReader } from "./files-reader";
import { editorBuffer, fileOption, editBuffer, saveBuffer, guard, discardGuard, cancelGuard, type FileBuffer } from "./files-buffer";
const SOURCE_EXTS = new Set(["disl"]);
const FRAME = ["workspace-frame", "workspace-editor"];
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

export function editorPane(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  active: boolean,
  readerNodes?: number,
): UiNode {
  const open = state.open;
  if (!open)
    return screen(`${id}/editor`, { body: [text(`${id}/editor/none`, S.NO_FILE_OPEN, ["hint"])] }, { cls: FRAME });
  const option = fileOption(open);
  const current = editorBuffer(id, doc, state);
  if (!current) return screen(`${id}/editor`, { body: [] }, { cls: FRAME });
  const bodyId = `${id}/editor/body/${current.key}`;
  const conflict = current.revision !== open.revision;
  const editor = editorOf(state.editor);
  const readOnly = editor?.read_only === true;
  const reader = fileReader(`${id}/reader/content`, open.ext, current.text, readerNodes);
  if (!reader) current.sourceView = true;
  const showSource = current.sourceView === true;
  current.sourceVisible = showSource;
  const submitBody = showSource ? bodyId : undefined;
  const locked = !active || conflict || editor?.read_only;
  const status = editor && showSource ? Stack(`${id}/editor/status`, [
    ...(editor.markers.length
      ? editor.markers.slice(0, 8).map((m, i) => text(`${id}/editor/marker/${i}`, S.marker(m.line, m.message), ["marker"]))
      : [text(`${id}/editor/clear`, S.MARKERS_CLEAR, ["hint"])]),
    text(`${id}/editor/budget`, S.byteBudget(editor.byte_budget), ["fsize"]),
  ], { gap: 8, align: "center", wrap: true, cls: ["grow"] }) : null;
  const buttons = readOnly ? null : Stack(`${id}/editor/buttons`, [
    press(`${id}/editor/save`, S.SAVE, (e) => saveBuffer(current, e), { submit: submitBody, variant: "primary", disabled: locked }),
    press(`${id}/editor/revert`, S.REVERT, guard(id, documentAction(doc, "toggle", { field: "file_revert", option })),
      { submit: submitBody, disabled: !active }),
  ], { gap: 4, cls: ["at-end"] });
  const foot = some(status, buttons);
  const pane = screen(`${id}/editor`, {
    toolbar: some(
      text(`${id}/editor/title`, S.fileTitle(open.name, open.ext, current.dirty), ["titlebar-title"]),
      readOnly ? Chip(`${id}/editor/read-only`, S.tfs("ui.files.read_only"), "") : null,
      conflict ? Notice(`${id}/editor/conflict`, S.CONFLICT, { tone: "off" }) : null,
      readOnly ? null : Stack(`${id}/editor/rename`, [
        { ...entry(`${id}/editor/name`, open.name, () => undefined, { submitOnly: true }), label: S.tfs("ui.files.filename") },
        press(`${id}/editor/rename-button`, S.RENAME,
          (e) => documentAction(doc, "text", { field: "file_rename", option, text: e.value ?? open.name }),
          { submit: `${id}/editor/name`, disabled: !active || editor?.read_only }),
      ], { gap: 4, align: "center", style: { width: "100%" } }),
      reader ? modeTabs(id, current, readOnly, showSource, submitBody) : null,
    ),
    body: showSource
      ? [sourceArea(id, doc, bodyId, current, option, active, editor, open.ext)]
      : [column(`${id}/reader`, reader ?? [])],
    ...(foot.length ? { footer: foot } : {}),
  }, { cls: FRAME });
  return { ...pane, ...(!readOnly ? { primarySave: `${id}/editor/save` } : {}) };
}

/** View or Edit (View or Source when read-only). The View tab submits
 *  the source so an unflushed draft survives the switch; the kit's tab
 *  carries no `submit`, so it is set on the press the tab made. */
function modeTabs(id: string, current: FileBuffer, readOnly: boolean, showSource: boolean, submitBody: string | undefined): UiNode {
  // The events keep their old names: `<id>/editor/view` and `/edit`.
  const view = bind(`${id}/editor/view`, (e) => {
    if (e.value !== undefined) editBuffer(current, e.value, e.revision);
    current.sourceView = false; current.sourceVisible = false;
    return undefined;
  });
  const edit = bind(`${id}/editor/edit`, () => { current.sourceView = true; current.sourceVisible = true; return undefined; });
  const tabs = Tabs(`${id}/editor/mode`, [
    { key: "view", label: S.tfs("ui.files.view"), selected: !showSource, event: view },
    { key: "edit", label: S.tfs(readOnly ? "ui.files.source" : "ui.files.edit"), selected: showSource, event: edit },
  ], { style: { width: "100%" } });
  if (!submitBody) return tabs;
  return { ...tabs, children: tabs.children?.map((tab) => tab.event === view ? { ...tab, submit: submitBody } : tab) };
}

/** Typing checks as it goes: a debounced change ships the whole draft,
 *  and the engine's markers answer on the next push. */
function sourceArea(
  id: string, doc: DocumentIdentity, bodyId: string, current: FileBuffer, option: string,
  active: boolean, editor: EditorState | undefined, ext: string,
): UiNode {
  return { ...entry(bodyId, current.text, (value, e) => {
    editBuffer(current, value, e.revision);
    return documentAction(doc, "text", { field: "file_change", option, text: value, revision: current.revision });
  }, {
    multiline: true,
    cls: ["workspace-editor-area"],
    debounceMs: 400,
    revision: current.revision,
    ...(editor ? {
      disabled: !active || editor.read_only,
      ...(SOURCE_EXTS.has(ext) ? { language: "luau" as const } : {}),
    } : {}),
  }), label: S.tfs("ui.files.contents") };
}

/** The workspace's sole modal while a draft guards a pending operation. */
export function editorGuard(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean): UiNode | null {
  const current = editorBuffer(id, doc, state);
  if (!current?.guard) return null;
  const submitBody = current.sourceVisible ? `${id}/editor/body/${current.key}` : undefined;
  const locked = !active || current.revision !== current.open.revision || state.editor?.read_only || !!current.pending;
  const key = `${id}/editor/guard`;
  return Dialog(key, {
    title: S.tfs("ui.files.dirty_guard"),
    body: [text(`${key}/detail`, current.revision !== current.open.revision ? S.CONFLICT
      : S.tfs(current.pending ? "ui.files.saving_guard" : "ui.files.dirty_guard_detail"))],
    actions: [
      press(`${key}/cancel`, S.tfs("ui.files.cancel"), () => { cancelGuard(current); return undefined; }, { variant: "ghost" }),
      press(`${key}/discard`, S.tfs("ui.files.discard"), () => discardGuard(current), { variant: "danger", disabled: !!current.pending }),
      press(`${key}/save`, S.SAVE, (e) => saveBuffer(current, e, true), { submit: submitBody, variant: "primary", disabled: locked }),
    ],
  }, { initialFocus: `${key}/cancel`, dismissEvent: `${key}/cancel`, dismissLabel: S.tfs("ui.files.cancel") });
}
