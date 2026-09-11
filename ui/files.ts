// Shared computer frameset; native providers own every file operation.
// What it answers is the parts of the workspace screen: the heading and
// readings across the top, the drives and the reader side by side in the
// body, and any create-file dialog over the lot. A contact workspace draws
// two sides — the held tool's and the target's — each switching between
// its own A: and B: (engine `docs/tgui/files.md`).
import type { ScreenParts, UiNode } from "@lunatic/ui";
import { Scroll, Stack } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, StoreRow } from "./document-model";
import { driveLetter, drivePane } from "./files-drive";
import { editorGuard, editorPane } from "./files-editor";
import { createFileDialog } from "./files-create";
import { socketRows } from "./files-sockets";
import { moduleBody } from "./documents-modules";
import { tfs } from "./strings";
import { column, icon, nodeCount, panel, press, some, text } from "./view";

/** The protocol's per-tree node budget (docs/pack-ui/components.md) and the
 *  share kept for the editor's own rows (~32), the screen wrappers and slack. */
const TREE_NODES = 2048;
const TREE_RESERVE = 128;
export { retainOpenFileBuffers, pollContinuation, guard } from "./files-buffer";

/** The held tool a contact workspace is worked through: its bar's identity. */
export interface Identity { sprite?: string; name?: string }

/** Which drive each contact side shows, per document; never sent. */
const shown = new Map<string, string>();

interface Side { key: string; node: UiNode }

/** The workspace's own bar: the machine, or on a contact the tool in hand. */
export function workspaceHeading(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, status: string,
  controls: UiNode[] = [], tool?: Identity): UiNode {
  const device = state.name ?? doc.title;
  return Stack(`${id}/heading`, some(
    icon(`${id}/machine-icon`, tool?.sprite ?? state.owner_sprite ?? doc.owner_sprite, tool?.name ?? device),
    text(`${id}/machine-name`, tool?.name ?? device, ["workspace-machine-name", "grow"]),
    text(`${id}/machine-status`, status, ["hint"]),
    controls.length ? Stack(`${id}/machine-controls`, controls, { gap: 4, align: "center" }) : null,
  ), { align: "center", gap: 6, cls: ["workspace-frame"], style: { width: "100%" } });
}

export function filePanes(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean,
  controls: UiNode[] = [], tool?: Identity): ScreenParts {
  const stores = state.stores ?? [];
  const device = state.name ?? doc.title;
  const heading = workspaceHeading(id, doc, state,
    tool ? tfs("ui.workspace.connected", { device }) : tfs("ui.workspace.ready"), controls, tool);
  const readings = [
    ...moduleBody(`${id}/information`, doc, state, active, false),
    ...(state.sockets?.length ? [socketRows(id, doc, state, active)] : []),
  ];
  const information = readings.length
    ? Scroll(`${id}/information`, readings, { cls: ["workspace-frame"], style: { width: "100%", maxHeight: 180 } })
    : null;
  const [left, right] = tool
    ? [contactSide(id, doc, state, "tool", tool.name ?? "", device, active),
      contactSide(id, doc, state, "target", tool.name ?? "", device, active)]
    : [plainSide(id, doc, state, "host", active), plainSide(id, doc, state, "media", active)];
  // The reader takes what the tree has left: two full drives alone can
  // approach the budget, and one node over faults the whole desktop.
  const spent = nodeCount(some(heading, information, left?.node ?? null, right?.node ?? null));
  const children = some(
    left?.node ?? null,
    editorPane(id, doc, state, active, TREE_NODES - TREE_RESERVE - spent),
    right?.node ?? null,
  );
  const confirmation = editorGuard(id, doc, state, active);
  return {
    toolbar: some(heading, information),
    // The panes stand as tall as the body and no narrower than they can
    // be read at; the body scrolls sideways past that.
    body: [{ ...panel(`${id}/panes`, children, { style: { width: "100%", height: "100%", minWidth: 740 } }), split: {
      key: `computer/${doc.id}/${doc.generation}`,
      // A contact side's copy presses name a drive on the far side too,
      // so its panes start wider than a plain desktop's.
      panes: [
        ...(left ? [{ key: left.key, initialWidth: tool ? 224 : 184, minWidth: 152 }] : []),
        { key: "editor", minWidth: 280, flexible: true },
        ...(right ? [{ key: right.key, initialWidth: tool ? 224 : 184, minWidth: 152 }] : []),
      ],
    } }],
    overlay: confirmation ? [confirmation] : stores.map((store) =>
      createFileDialog(id, doc, store, state.create?.[store.key ?? "host"] ?? [], active))
      .filter((node): node is UiNode => node !== null),
  };
}

function plainSide(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, key: string, active: boolean): Side | null {
  const store = state.stores?.find((row) => row.key === key);
  return store ? { key, node: drivePane(id, doc, state, store, active) } : null;
}

/** One owner's side of a contact: an A:/B: switch over the drive it shows.
 *  B: stands wherever the owner has a slot, loaded or not. */
function contactSide(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, owner: "tool" | "target",
  toolName: string, device: string, active: boolean): Side | null {
  const mine = (state.stores ?? []).filter((store) => store.owner === owner);
  const slot = owner === "tool" ? state.tool_media_slot : state.media_slot;
  const drives = ["host", ...(slot || mine.some((store) => store.drive === "media") ? ["media"] : [])];
  if (!mine.length) return null;
  const memory = `${doc.id}/${doc.generation}/${owner}`;
  const selected = drives.includes(shown.get(memory) ?? "") ? shown.get(memory)! : "host";
  const key = `${id}/side/${owner}`;
  const switcher = Stack(`${key}/drives`, drives.map((drive) => press(
    `${key}/show/${owner === "tool" ? "tool_" : ""}${drive}`, tfs(driveLetter(drive)),
    () => { shown.set(memory, drive); return undefined; },
    { variant: drive === selected ? "selected" : "ghost" },
  )), { gap: 4, align: "center", cls: ["workspace-frame"] });
  const store = mine.find((row) => row.drive === selected);
  const names: Record<string, string> = { tool: toolName, target: device };
  const copyLabel = (destination: StoreRow): string => destination.owner === owner
    ? tfs(destination.drive === "media" ? "ui.files.copy_to_b" : "ui.files.copy_to_a")
    : tfs("ui.files.copy_to_other", { drive: tfs(driveLetter(destination.drive)), name: names[destination.owner ?? ""] ?? "" });
  return { key: owner, node: column(key, [
    switcher,
    store ? drivePane(id, doc, state, store, active, copyLabel)
      : text(`${key}/no-disk`, tfs("ui.workspace.no_disk"), ["hint", "workspace-frame"]),
  ], { style: { height: "100%" } }) };
}
