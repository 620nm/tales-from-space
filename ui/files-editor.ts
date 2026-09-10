import type { UiNode } from "@lunatic/ui";
import { Notice, Stack } from "@lunatic/ui";
import type { DocumentIdentity, EditorState, ModuleState } from "./document-model";
import { documentAction } from "./document-action";
import { column, entry, press, row, some, text } from "./view";
import * as S from "./strings";
import { fileReader } from "./files-reader";
import { editorBuffer, fileOption, editBuffer, saveBuffer, guard, discardGuard, cancelGuard } from "./files-buffer";
const SOURCE_EXTS = new Set(["disl"]);
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
    return column(`${id}/editor`, [text(`${id}/editor/none`, S.NO_FILE_OPEN, ["hint"])], {
      cls: ["workspace-frame", "workspace-editor"],
    });
  const option = fileOption(open);
  const current = editorBuffer(id, doc, state);
  if (!current) return column(`${id}/editor`, []);
  const bodyId = `${id}/editor/body/${current.key}`;
  const conflict = current.revision !== open.revision;
  const editor = editorOf(state.editor);
  const readOnly = editor?.read_only === true;
  const markdown = open.ext === "md";
  const showSource = !markdown || current.sourceView === true;
  const submitBody = showSource ? bodyId : undefined;
  const reader = fileReader(`${id}/reader/content`, open.ext, current.text, readerNodes);
  return { ...column(
    `${id}/editor`,
    some(
      Stack(`${id}/editor/heading`, some(
        text(`${id}/editor/title`, S.fileTitle(open.name, open.ext, current.dirty), ["mstate"]),
        readOnly ? text(`${id}/editor/read-only`, S.tfs("ui.files.read_only"), ["workspace-read-only"]) : null,
      ), { align: "center", gap: 8, wrap: true }),
      conflict
        ? Notice(`${id}/editor/conflict`, S.CONFLICT, { tone: "off" })
        : null,
      !readOnly ? Stack(
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
            { submit: `${id}/editor/name`, disabled: !active || editor?.read_only },
          ),
        ],
        { gap: 4, align: "center" },
      ) : null,
      markdown ? row(`${id}/editor/mode`, [
        press(`${id}/editor/view`, S.tfs("ui.files.view"), (e) => {
          if (e.value !== undefined) editBuffer(current, e.value, e.revision);
          current.sourceView = false;
          return undefined;
        }, { submit: submitBody, variant: !showSource ? "selected" : "ghost" }),
        press(`${id}/editor/edit`, S.tfs(readOnly ? "ui.files.source" : "ui.files.edit"), () => {
          current.sourceView = true;
          return undefined;
        }, { variant: showSource ? "selected" : "ghost" }),
      ]) : null,
      reader && (!markdown || !showSource)
        ? column(`${id}/reader`, reader, { cls: ["workspace-reader"] })
        : null,
      // Typing checks as it goes: a debounced change ships the whole
      // draft, and the engine's markers answer on the next push.
      showSource ? entry(
        bodyId,
        current.text,
        (value, e) => {
          editBuffer(current, value, e.revision);
          return documentAction(doc, "text", {
            field: "file_change",
            option,
            text: value,
            revision: current.revision,
          });
        },
        {
          multiline: true,
          cls: ["workspace-editor-area"],
          debounceMs: 400,
          revision: current.revision,
          ...(editor
            ? {
                disabled: !active || editor.read_only,
                ...(SOURCE_EXTS.has(open.ext) ? { language: "luau" as const } : {}),
              }
            : {}),
        },
      ) : null,
      editor && showSource
        ? Stack(
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
            { gap: 8, align: "center", wrap: true },
          )
        : null,
      current.guard && !readOnly ? column(`${id}/editor/guard`, [
        text(`${id}/editor/guard/message`, S.tfs("ui.files.dirty_guard")),
        row(`${id}/editor/guard/actions`, [
          press(`${id}/editor/guard/save`, S.SAVE, (e) => saveBuffer(current, e, true),
            { submit: submitBody, disabled: !active || conflict || editor?.read_only }),
          press(`${id}/editor/guard/discard`, S.tfs("ui.files.discard"), () => discardGuard(current)),
          press(`${id}/editor/guard/cancel`, S.tfs("ui.files.cancel"), () => { cancelGuard(current); return undefined; }),
        ]),
      ]) : null,
      !readOnly ? Stack(
        `${id}/editor/buttons`,
        [
          press(
            `${id}/editor/save`,
            S.SAVE,
            (e) => saveBuffer(current, e),
            { submit: submitBody, variant: "primary", disabled: !active || conflict || editor?.read_only },
          ),
          press(`${id}/editor/revert`, S.REVERT, guard(id, documentAction(doc, "toggle", {
            field: "file_revert", option,
          })), { submit: submitBody, disabled: !active }),
        ],
        { gap: 4 },
      ) : null,
    ),
    { cls: ["workspace-editor"] },
  ), ...(!readOnly ? { primarySave: `${id}/editor/save` } : {}) };
}

