// Shared computer frameset; native providers own every file operation.
// What it answers is the parts of the workspace screen: the heading and
// its Details across the top, the drives and the reader side by side in
// the body, and any dialog over the lot. A contact workspace draws two
// sides — the target's on the left, the held tool's on the right — each
// switching between its own A: and B: (engine `docs/tgui/files.md`).
import type { ScreenParts, UiNode } from "@lunatic/ui";
import { Scroll, Stack } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, StoreRow } from "./document-model";
import { driveLetter, drivePane, plainCopy, type CopyTarget } from "./files-drive";
import { editorGuard, editorPane } from "./files-editor";
import { createFileDialog } from "./files-create";
import { programSlotRows } from "./files-programs";
import { moduleBody } from "./documents-modules";
import { linkMeta, refusalDialog } from "./documents-device";
import { tfs } from "./strings";
import { column, icon, nodeCount, panel, press, some, text } from "./view";

/** The protocol's per-tree node budget (docs/pack-ui/components.md) and the
 *  share kept for the editor's own rows (~32), the screen wrappers and slack. */
const TREE_NODES = 2048;
const TREE_RESERVE = 128;
export { retainOpenFileBuffers, pollContinuation, guard } from "./files-buffer";

/** The held tool a contact workspace is worked through: the window's title. */
export interface Identity { sprite?: string; name?: string }

type Owner = "tool" | "target";

/** Which drive each contact side shows, per document; never sent. */
const shown = new Map<string, string>();
/** The documents whose device details are open; never sent. */
const expanded = new Set<string>();

interface Side { key: string; node: UiNode }

/** One contact owner's drives and the one its side shows. B: stands
 *  wherever the owner has a slot, loaded or not. */
interface Shown { owner: Owner; drives: string[]; selected: string; store?: StoreRow }

/** The workspace's own bar: the device, its link, a Details press over
 *  its panel rows where it has any, and the machine's controls. */
export function workspaceHeading(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, status: string,
  controls: UiNode[] = [], details: UiNode | null = null): UiNode {
  const device = state.name ?? doc.title;
  return Stack(`${id}/heading`, some(
    icon(`${id}/machine-icon`, state.owner_sprite ?? doc.owner_sprite, device),
    text(`${id}/machine-name`, device, ["workspace-machine-name", ...(state.link ? [] : ["grow"])]),
    linkMeta(id, state, ["workspace-machine-link", "grow"]),
    text(`${id}/machine-status`, status, ["hint"]),
    details,
    controls.length ? Stack(`${id}/machine-controls`, controls, { gap: 4, align: "center" }) : null,
  ), { align: "center", gap: 6, cls: ["workspace-frame"], style: { width: "100%" } });
}

export function filePanes(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean,
  controls: UiNode[] = [], tool?: Identity): ScreenParts {
  const stores = state.stores ?? [];
  const device = state.name ?? doc.title;
  const readings = [
    ...moduleBody(`${id}/information`, doc, state, active, false),
    ...(state.program_slots?.length ? [programSlotRows(id, doc, state, active)] : []),
  ];
  const memory = `${doc.id}/${doc.generation}`;
  const open = expanded.has(memory);
  const details = readings.length ? press(`${id}/details`,
    tfs(open ? "ui.workspace.details_hide" : "ui.workspace.details_show"), () => {
      if (open) expanded.delete(memory); else expanded.add(memory);
      return undefined;
    }, { variant: "ghost", cls: ["workspace-details"] }) : null;
  const heading = workspaceHeading(id, doc, state,
    tool ? tfs("ui.workspace.connected", { tool: tool.name ?? "" }) : tfs("ui.workspace.ready"), controls, details);
  const information = open && readings.length
    ? Scroll(`${id}/information`, readings, { cls: ["workspace-frame"], style: { width: "100%", maxHeight: 180 } })
    : null;
  const [left, right] = tool ? contactSides(id, doc, state, tool.name ?? "", device, active) : plainSides(id, doc, state, active);
  // The reader takes what the tree has left: two full drives alone can
  // approach the budget, and one node over faults the whole desktop.
  const spent = nodeCount(some(heading, information, left?.node ?? null, right?.node ?? null));
  const children = some(
    left?.node ?? null,
    editorPane(id, doc, state, active, TREE_NODES - TREE_RESERVE - spent),
    right?.node ?? null,
  );
  const refusal = refusalDialog(id, doc, state);
  const confirmation = editorGuard(id, doc, state, active);
  return {
    toolbar: some(heading, information),
    // The panes stand as tall as the body and no narrower than they can
    // be read at; the body scrolls sideways past that.
    body: [{ ...panel(`${id}/panes`, children, { style: { width: "100%", height: "100%", minWidth: 740 } }), split: {
      key: `computer/${doc.id}/${doc.generation}`,
      // A contact side's copy press names the far side's drive and
      // owner, so its panes start wider than a plain desktop's.
      panes: [
        ...(left ? [{ key: left.key, initialWidth: tool ? 224 : 184, minWidth: 152 }] : []),
        { key: "editor", minWidth: 280, flexible: true },
        ...(right ? [{ key: right.key, initialWidth: tool ? 224 : 184, minWidth: 152 }] : []),
      ],
    } }],
    overlay: refusal ? [refusal] : confirmation ? [confirmation] : stores.map((store) =>
      createFileDialog(id, doc, store, state.create?.[store.key ?? "host"] ?? [], active))
      .filter((node): node is UiNode => node !== null),
  };
}

/** A plain desktop: its own store on the left, the disk on the right,
 *  each file copying across to the other. */
function plainSides(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean): (Side | null)[] {
  const host = state.stores?.find((row) => row.key === "host");
  const media = state.stores?.find((row) => row.key === "media");
  const side = (store: StoreRow | undefined, other: StoreRow | undefined): Side | null => store
    ? { key: store.key ?? "host", node: drivePane(id, doc, state, store, active, other ? plainCopy(other) : undefined) }
    : null;
  return [side(host, media), side(media, host)];
}

/** A contact: the target's side, then the tool's. Both shown drives are
 *  settled first, because each file copies into the one across from it. */
function contactSides(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, toolName: string,
  device: string, active: boolean): (Side | null)[] {
  const target = shownDrive(doc, state, "target");
  const tool = shownDrive(doc, state, "tool");
  const names: Record<Owner, string> = { tool: toolName, target: device };
  const copyTo = (other: Shown | null): CopyTarget | undefined => other?.store ? {
    store: other.store, suffix: `copy-${other.store.key}`,
    label: tfs("ui.files.copy_to_other", { drive: tfs(driveLetter(other.store.drive)), name: names[other.owner] }),
  } : undefined;
  return [
    target ? contactSide(id, doc, state, target, copyTo(tool), active) : null,
    tool ? contactSide(id, doc, state, tool, copyTo(target), active) : null,
  ];
}

function shownDrive(doc: DocumentIdentity, state: Partial<ModuleState>, owner: Owner): Shown | null {
  const mine = (state.stores ?? []).filter((store) => store.owner === owner);
  if (!mine.length) return null;
  const slot = owner === "tool" ? state.tool_media_slot : state.media_slot;
  const drives = ["host", ...(slot || mine.some((store) => store.drive === "media") ? ["media"] : [])];
  const remembered = shown.get(`${doc.id}/${doc.generation}/${owner}`) ?? "";
  const selected = drives.includes(remembered) ? remembered : "host";
  return { owner, drives, selected, store: mine.find((row) => row.drive === selected) };
}

/** One owner's side of a contact: an A:/B: switch over the drive it shows. */
function contactSide(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, side: Shown,
  copy: CopyTarget | undefined, active: boolean): Side {
  const { owner, drives, selected, store } = side;
  const key = `${id}/side/${owner}`;
  const switcher = Stack(`${key}/drives`, drives.map((drive) => press(
    `${key}/show/${owner === "tool" ? "tool_" : ""}${drive}`, tfs(driveLetter(drive)),
    () => { shown.set(`${doc.id}/${doc.generation}/${owner}`, drive); return undefined; },
    { variant: drive === selected ? "selected" : "ghost" },
  )), { gap: 4, align: "center", cls: ["workspace-frame"] });
  return { key: owner, node: column(key, [
    switcher,
    store ? drivePane(id, doc, state, store, active, copy)
      : text(`${key}/no-disk`, tfs("ui.workspace.no_disk"), ["hint", "workspace-frame"]),
  ], { style: { height: "100%" } }) };
}
