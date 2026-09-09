// Shared computer frameset; native providers own every file operation.
import type { UiNode } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState } from "./document-model";
import { drivePane } from "./files-drive";
import { editorPane } from "./files-editor";
import { socketRows } from "./files-sockets";
import { moduleBody } from "./documents-modules";
import { documentAction } from "./document-action";
import { bodyId, guard } from "./files-buffer";
import * as S from "./strings";
import { column, panel, press, row, text } from "./view";
export { retainOpenFileBuffers, pollContinuation, guard } from "./files-buffer";

export function filePanes(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean): UiNode[] {
  const host = state.stores?.find((store) => store.key === "host");
  const media = state.stores?.find((store) => store.key === "media");
  const children = [
    ...(host ? [drivePane(id, doc, state, host, active)] : []),
    editorPane(id, doc, state, active),
    ...(media ? [drivePane(id, doc, state, media, active)] : []),
  ];
  return [
    column(`${id}/information`, [
      text(`${id}/machine-name`, state.name ?? doc.title, ["workspace-machine-name"]),
      ...(state.contact_store ? [row(`${id}/contact`, (["host", "media"] as const).map((source) =>
        press(`${id}/contact/${source}`, S.tfs(`ui.workspace.contact_${source}`),
          guard(id, documentAction(doc, "toggle", { field: "contact_store", option: source })),
          { submit: bodyId(id), variant: state.contact_store === source ? "selected" : "ghost", disabled: !active }),
      ))] : []),
      ...moduleBody(`${id}/information`, doc, state, active, false),
      ...(state.sockets?.length ? [socketRows(id, doc, state, active)] : []),
    ], { cls: ["workspace-frame", "workspace-information"] }),
    { ...panel(`${id}/panes`, children, { cls: ["workspace-panes"] }), split: {
      key: `computer/${doc.id}/${doc.generation}`,
      panes: [
        ...(host ? [{ key: "host", initialWidth: 184, minWidth: 152 }] : []),
        { key: "editor", minWidth: 280, flexible: true },
        ...(media ? [{ key: "media", initialWidth: 184, minWidth: 152 }] : []),
      ],
    } },
  ];
}
