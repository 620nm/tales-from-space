// Shared computer frameset; native providers own every file operation.
import type { UiNode } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState } from "./document-model";
import { drivePane } from "./files-drive";
import { editorPane } from "./files-editor";
import { socketRows } from "./files-sockets";
import { moduleBody } from "./documents-modules";
import { column, nodeCount, panel, row, some, text } from "./view";

/** The protocol's per-tree node budget (docs/pack-ui/components.md) and the
 *  share kept for the editor's own rows (~32), the screen wrappers and slack. */
const TREE_NODES = 2048;
const TREE_RESERVE = 128;
export { retainOpenFileBuffers, pollContinuation, guard } from "./files-buffer";

export function filePanes(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean, controls: UiNode[] = []): UiNode[] {
  const host = state.stores?.find((store) => store.key === "host");
  const media = state.stores?.find((store) => store.key === "media");
  const information = column(`${id}/information`, [
    row(`${id}/heading`, [
      text(`${id}/machine-name`, state.name ?? doc.title, ["workspace-machine-name"]),
      row(`${id}/machine-controls`, controls, { cls: ["workspace-controls"] }),
    ], { cls: ["workspace-heading"] }),
    ...moduleBody(`${id}/information`, doc, state, active, false),
    ...(state.sockets?.length ? [socketRows(id, doc, state, active)] : []),
  ], { cls: ["workspace-frame", "workspace-information"] });
  const drives = {
    host: host ? drivePane(id, doc, state, host, active) : undefined,
    media: media ? drivePane(id, doc, state, media, active) : undefined,
  };
  // The reader takes what the tree has left: two full drives alone can
  // approach the budget, and one node over faults the whole desktop.
  const spent = nodeCount(some(information, drives.host ?? null, drives.media ?? null));
  const children = some(
    drives.host ?? null,
    editorPane(id, doc, state, active, TREE_NODES - TREE_RESERVE - spent),
    drives.media ?? null,
  );
  return [
    information,
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
