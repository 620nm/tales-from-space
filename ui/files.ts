// Shared computer frameset; native providers own every file operation.
// What it answers is the parts of the workspace screen: the machine's
// heading and readings across the top, the drives and the reader side
// by side in the body, and any create-file dialog over the lot.
import type { ScreenParts, UiNode } from "@lunatic/ui";
import { Scroll, Stack } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState } from "./document-model";
import { drivePane } from "./files-drive";
import { editorGuard, editorPane } from "./files-editor";
import { createFileDialog } from "./files-create";
import { socketRows } from "./files-sockets";
import { moduleBody } from "./documents-modules";
import { tfs } from "./strings";
import { icon, nodeCount, panel, some, text } from "./view";

/** The protocol's per-tree node budget (docs/pack-ui/components.md) and the
 *  share kept for the editor's own rows (~32), the screen wrappers and slack. */
const TREE_NODES = 2048;
const TREE_RESERVE = 128;
export { retainOpenFileBuffers, pollContinuation, guard } from "./files-buffer";

export function filePanes(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean, controls: UiNode[] = []): ScreenParts {
  const host = state.stores?.find((store) => store.key === "host");
  const media = state.stores?.find((store) => store.key === "media");
  const contact = state.stores?.find((store) => store.key === "contact");
  const heading = Stack(`${id}/heading`, some(
    icon(`${id}/machine-icon`, state.owner_sprite ?? doc.owner_sprite, state.name ?? doc.title),
    text(`${id}/machine-name`, state.name ?? doc.title, ["workspace-machine-name", "grow"]),
    text(`${id}/machine-status`, tfs("ui.workspace.ready"), ["hint"]),
    Stack(`${id}/machine-controls`, controls, { gap: 4, align: "center" }),
  ), { align: "center", gap: 6, cls: ["workspace-frame"], style: { width: "100%" } });
  const readings = [
    ...moduleBody(`${id}/information`, doc, state, active, false),
    ...(state.sockets?.length ? [socketRows(id, doc, state, active)] : []),
  ];
  const information = readings.length
    ? Scroll(`${id}/information`, readings, { cls: ["workspace-frame"], style: { width: "100%", maxHeight: 180 } })
    : null;
  const drives = {
    host: host ? drivePane(id, doc, state, host, active) : undefined,
    media: media ? drivePane(id, doc, state, media, active) : undefined,
    contact: contact ? drivePane(id, doc, state, contact, active) : undefined,
  };
  // The reader takes what the tree has left: two full drives alone can
  // approach the budget, and one node over faults the whole desktop.
  const spent = nodeCount(some(heading, information, drives.host ?? null, drives.media ?? null, drives.contact ?? null));
  const children = some(
    drives.host ?? null,
    editorPane(id, doc, state, active, TREE_NODES - TREE_RESERVE - spent),
    drives.media ?? null,
    drives.contact ?? null,
  );
  const confirmation = editorGuard(id, doc, state, active);
  return {
    toolbar: some(heading, information),
    // The panes stand as tall as the body and no narrower than they can
    // be read at; the body scrolls sideways past that.
    body: [{ ...panel(`${id}/panes`, children, { style: { width: "100%", height: "100%", minWidth: 740 } }), split: {
      key: `computer/${doc.id}/${doc.generation}`,
      panes: [
        ...(host ? [{ key: "host", initialWidth: 184, minWidth: 152 }] : []),
        { key: "editor", minWidth: 280, flexible: true },
        ...(media ? [{ key: "media", initialWidth: 184, minWidth: 152 }] : []),
        ...(contact ? [{ key: "contact", initialWidth: 184, minWidth: 152 }] : []),
      ],
    } }],
    overlay: confirmation ? [confirmation] : some(
      host ? createFileDialog(id, doc, host, state.create?.host ?? [], active) : null,
      media ? createFileDialog(id, doc, media, state.create?.media ?? [], active) : null,
      contact ? createFileDialog(id, doc, contact, state.create?.contact ?? [], active) : null,
    ),
  };
}
