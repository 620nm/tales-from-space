// Device workspace pages and local navigation; native providers own every
// operation. Files keeps contact drives beside the reader. Details owns
// connection management; Controls owns reached panels (docs/LAPTOP.md).
import type { ScreenParts, ScrollAxis, UiNode } from "@lunatic/ui";
import { Stack, Tabs } from "@lunatic/ui";
import type { ControlPanel, DocumentIdentity, ModuleState, StoreRow } from "./document-model";
import { driveLetter, drivePane, plainCopy, type CopyTarget } from "./files-drive";
import { editorGuard, editorPane } from "./files-editor";
import { createFileDialog } from "./files-create";
import { programSlotRows, programSummary } from "./files-programs";
import { moduleBody } from "./documents-modules";
import { controlWorkspace } from "./documents-controls";
import { linkMeta, refusalDialog } from "./documents-device";
import { labelText } from "./labels";
import { tfs } from "./strings";
import { bodyId, localGuard, retainOpenFileBuffers, pollContinuation, guard } from "./files-buffer";
import { bind, column, icon, nodeCount, panel, press, some, text } from "./view";

/** The protocol's per-tree node budget (docs/pack-ui/components.md) and the
 *  share kept for the editor's own rows (~32), the screen wrappers and slack. */
const TREE_NODES = 2048;
const TREE_RESERVE = 128;
export { retainOpenFileBuffers, pollContinuation, guard } from "./files-buffer";

/** The held tool a contact workspace is worked through: the window's title. */
export interface Identity { sprite?: string; name?: string }
export interface WorkspaceParts extends ScreenParts { bodyAxis?: ScrollAxis }

type Owner = "tool" | "target";

/** Which drive each contact side shows, keyed `<doc>/<generation>/<owner>`;
 *  never sent. */
const shown = new Map<string, string>();
/** The documents (`<doc>/<generation>`) whose device details are open. */
const expanded = new Set<string>();
/** The selected workspace page for each live document identity. */
type WorkspacePage = "controls" | "programs" | "files";
const selected = new Map<string, WorkspacePage>();

/** Forget drive and Details choices for documents no longer open. */
export function retainWorkspaces(open: DocumentIdentity[]): void {
  const live = new Set(open.map((doc) => `${doc.id}/${doc.generation}`));
  for (const key of expanded) if (!live.has(key)) expanded.delete(key);
  for (const key of selected.keys()) if (!live.has(key)) selected.delete(key);
  for (const key of shown.keys()) if (!live.has(key.slice(0, key.lastIndexOf("/")))) shown.delete(key);
}

interface Side { key: string; node: UiNode }

/** One contact owner's drives and the one its side shows. B: stands
 *  wherever the owner has a slot, loaded or not. */
interface Shown { owner: Owner; drives: string[]; selected: string; store?: StoreRow }

/** The workspace's own bar: the device, its link, a Details press over
 *  its panel rows where it has any, and the machine's controls. */
export function workspaceHeading(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, status: string | undefined,
  controls: UiNode[] = [], details: UiNode | null = null): UiNode {
  const device = state.name ?? doc.title;
  return Stack(`${id}/heading`, some(
    icon(`${id}/machine-icon`, state.owner_sprite ?? doc.owner_sprite, device),
    text(`${id}/machine-name`, device, ["workspace-machine-name", ...(state.link ? [] : ["grow"])]),
    linkMeta(id, state, ["workspace-machine-link"], ["workspace-machine-state"], true),
    status ? text(`${id}/machine-status`, status, ["hint"]) : null,
    details,
    controls.length ? Stack(`${id}/machine-controls`, controls, { gap: 4, align: "center" }) : null,
  ), { align: "center", gap: 6, cls: ["workspace-frame", "workspace-heading"], style: { width: "100%" } });
}

export function filePanes(id: string, doc: DocumentIdentity, state: Partial<ModuleState>, active: boolean,
  controls: UiNode[] = [], tool?: Identity): WorkspaceParts {
  const stores = state.stores ?? [];
  const device = state.name ?? doc.title;
  const memory = `${doc.id}/${doc.generation}`;
  const hasControls = state.control_panels !== undefined;
  const hasPrograms = state.program_slots !== undefined;
  const remembered = selected.get(memory);
  const page: WorkspacePage = remembered === "controls" && hasControls
    ? "controls"
    : remembered === "programs" && hasPrograms
      ? "programs"
      : remembered === "files" || !hasControls
        ? "files"
        : "controls";
  selected.set(memory, page);
  const open = expanded.has(memory);

  // Details is the device's own management view. The root arrays are copied
  // explicitly without reached control panels; those belong to Controls.
  const detailsState = ownState(state);
  const readings = moduleBody(`${id}/information`, doc, detailsState, active, false, false);
  const details = readings.length ? press(`${id}/details`,
    tfs(open ? "ui.workspace.details_hide" : "ui.workspace.details_show"), localGuard(id, () => {
      if (open) expanded.delete(memory); else expanded.add(memory);
    }), {
      variant: "ghost",
      cls: ["workspace-details"],
    }) : null;
  const heading = workspaceHeading(id, doc, state,
    tool ? tfs("ui.workspace.connected") : state.link ? undefined : tfs("ui.workspace.ready"), controls, details);
  const tabs = workspaceTabs(id, doc, state, page, hasControls, hasPrograms);
  const summary = hasPrograms
    ? programSummary(id, doc, state, active, localGuard(id, () => {
        selected.set(memory, "programs");
        expanded.delete(memory);
    }))
    : null;
  let toolbar = some(heading, tabs, summary);
  let body: UiNode[];
  if (open) {
    body = [panel(`${id}/details-body`, readings, {
      cls: ["workspace-details-body"],
      style: { width: "100%" },
    })];
  } else if (page === "controls") {
    body = [panel(`${id}/controls-body`, controlWorkspace(id, doc, state, active), {
      cls: ["workspace-controls-body"], style: { width: "100%" },
    })];
  } else if (page === "programs") {
    body = [panel(`${id}/programs-body`, [programSlotRows(id, doc, state, active)], {
      cls: ["workspace-frame"], style: { width: "100%" },
    })];
  } else {
    const [left, right] = tool ? contactSides(id, doc, state, tool.name ?? "", device, active) : plainSides(id, doc, state, active);
    // The reader takes what the tree has left: two full drives alone can
    // approach the budget, and one node over faults the whole desktop.
    const spent = nodeCount(some(heading, tabs, summary, left?.node ?? null, right?.node ?? null));
    const editor = editorPane(id, doc, state, active, TREE_NODES - TREE_RESERVE - spent);
    const children = some(
      left?.node ?? null,
      editor,
      right?.node ?? null,
    );
    body = [{ ...panel(`${id}/panes`, children, { style: { width: "100%", height: "100%", minWidth: 740 } }), split: {
      key: `computer/${doc.id}/${doc.generation}`,
      // A contact side's copy press names the far side's drive and
      // owner, so its panes start wider than a plain desktop's.
      panes: [
        ...(left ? [{ key: left.key, initialWidth: tool ? 224 : 184, minWidth: 152 }] : []),
        { key: "editor", minWidth: 280, flexible: true },
        ...(right ? [{ key: right.key, initialWidth: tool ? 224 : 184, minWidth: 152 }] : []),
      ],
    } }];
    toolbar = attachSourceSubmit(toolbar, id, bodyId(id));
  }
  const refusal = refusalDialog(id, doc, state);
  const confirmation = editorGuard(id, doc, state, active);
  return {
    bodyAxis: !open && page === "files" ? "x" : "y",
    toolbar,
    body,
    ...(state.notice ? { footer: [text(`${id}/notice`, labelText(state.notice), ["mod-foot"])] } : {}),
    overlay: refusal ? [refusal] : confirmation ? [confirmation] : stores.map((store) =>
      createFileDialog(id, doc, store, state.create?.[store.key ?? "host"] ?? [], active))
      .filter((node): node is UiNode => node !== null),
  };
}

type WorkspaceState = Partial<ModuleState> & { control_panels?: ControlPanel[] };

function ownState(state: Partial<ModuleState>): WorkspaceState {
  // A details renderer may support nested panels, but Details is always the
  // device's own management view and must never draw them a second time.
  return { ...state, control_panels: undefined };
}

function workspaceTabs(
  id: string,
  doc: DocumentIdentity,
  state: Partial<ModuleState>,
  page: WorkspacePage,
  hasControls: boolean,
  hasPrograms: boolean,
): UiNode {
  const memory = `${doc.id}/${doc.generation}`;
  const options = [
    ...(hasControls ? [{ key: "controls", label: tfs("ui.workspace.controls") }] : []),
    ...(hasPrograms ? [{ key: "programs", label: tfs("ui.workspace.programs", { count: state.program_slots?.length ?? 0 }) }] : []),
    { key: "files", label: tfs("ui.workspace.files", { count: storageCount(state) }) },
  ];
  const tabs = Tabs(`${id}/workspace-tabs`, options.map((tab) => {
    const eventId = `${id}/workspace/${tab.key}`;
    return {
      ...tab,
      selected: tab.key === page,
      event: bind(eventId, tab.key === page && !expanded.has(memory) ? () => undefined : localGuard(id, () => {
        selected.set(memory, tab.key as WorkspacePage);
        expanded.delete(memory);
      })),
    };
  }), { cls: ["workspace-tabs"] });
  return {
    ...tabs,
    children: tabs.children?.map((child, index) => {
      const key = options[index]?.key ?? "files";
      const isSelected = key === page;
      return {
        ...child,
        id: `${id}/workspace/${key}`,
        class: [...(child.class ?? []), "workspace-tab", ...(isSelected ? ["workspace-tab-active"] : [])],
      };
    }),
  };
}

/** Add a Files source submit only after its editor has mounted this tree. */
function attachSourceSubmit(nodes: UiNode[], id: string, submitBody: string | undefined): UiNode[] {
  if (!submitBody) return nodes;
  return nodes.map((node) => attachSourceSubmitNode(node, id, submitBody));
}

function attachSourceSubmitNode(node: UiNode, id: string, submitBody: string): UiNode {
  const workspaceTab = node.id?.startsWith(`${id}/workspace/`) && node.id !== `${id}/workspace/files`;
  const programOpen = node.id?.startsWith(`${id}/program-summary/`) && node.id.endsWith("/open");
  const target = node.id === `${id}/details` || workspaceTab || programOpen;
  const children = node.children?.map((child) => attachSourceSubmitNode(child, id, submitBody));
  return {
    ...node,
    ...(target ? { submit: submitBody } : {}),
    ...(children ? { children } : {}),
  };
}

function storageCount(state: Partial<ModuleState>): number {
  const stores = state.stores ?? [];
  if (stores.length) return stores.reduce((total, store) => total + Math.max(0, store.count), 0);
  return state.files?.length ?? 0;
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
