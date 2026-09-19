import type { UiEvent } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, OpenFile, PanelDocument } from "./document-model";
import { documentAction } from "./document-action";
import type { Command, Handler } from "./view";

export interface FileBuffer {
  key: number;
  text: string;
  revision: number;
  dirty: boolean;
  sourceView?: boolean;
  sourceVisible?: boolean;
  pending?: SaveReceipt;
  /** A cancelled native save whose acknowledgement can still reconcile the draft. */
  cancelledSave?: SaveReceipt;
  continuation?: Command;
  /** A local workspace change waiting behind the same dirty guard. */
  guardLocal?: () => void;
  continuationLocal?: () => void;
  confirmedLocal?: () => void;
  confirmed?: Command;
  guard?: Command;
  released?: () => void;
  doc: DocumentIdentity;
  open: OpenFile;
  bindings: string;
}
interface SaveReceipt { text: string; revision: number; request: string; binding: string; uid: number }
const buffers = new Map<string, FileBuffer>();
let nextEditor = 0;
let nextSave = 0;
export const fileOption = (open: OpenFile): string => `${open.store}:${open.uid}:${open.binding}`;
const scope = (doc: DocumentIdentity): string => `doc/${doc.id}/${doc.generation}`;
const bindings = (state: Partial<ModuleState>): string =>
  (state.stores ?? []).map((store) => store.binding).sort().join("/");

/** Buffers belong to one disclosed document, open file and store instance. */
export function editorBuffer(id: string, doc: DocumentIdentity, state: Partial<ModuleState>): FileBuffer | undefined {
  const open = state.open;
  if (!open || !open.binding || !(state.stores ?? []).some((s) => s.binding === open.binding)) {
    buffers.delete(id);
    return undefined;
  }
  let buffer = buffers.get(id);
  if (buffer && fileOption(buffer.open) !== fileOption(open)) buffer = undefined;
  if (!buffer) {
    buffer = { key: nextEditor++, text: open.body, revision: open.revision,
      dirty: false, doc, open, bindings: bindings(state) };
    buffers.set(id, buffer);
  }
  if (buffer.bindings !== bindings(state)) {
    buffer.continuation = undefined;
    buffer.continuationLocal = undefined;
    buffer.guard = undefined;
    buffer.guardLocal = undefined;
    buffer.confirmed = undefined;
    buffer.confirmedLocal = undefined;
    buffer.bindings = bindings(state);
  }
  const ack = state.save_ack;
  const matchesNative = (receipt: SaveReceipt | undefined): boolean => !!receipt &&
    receipt.binding === open.binding && receipt.uid === open.uid &&
    open.revision === receipt.revision + 1 && open.body === receipt.text;
  const matches = (receipt: SaveReceipt | undefined): boolean => !!receipt &&
    ack?.request === receipt.request && ack.binding === receipt.binding && ack.uid === receipt.uid &&
    matchesNative(receipt) && ack.revision === open.revision;
  if (buffer.pending && matches(buffer.pending)) {
    if (buffer.text === buffer.pending.text) {
      buffer.dirty = false;
      buffer.confirmed = buffer.continuation;
      buffer.confirmedLocal = buffer.continuationLocal;
      if (buffer.confirmed || buffer.confirmedLocal) {
        buffer.released?.();
        buffer.released = undefined;
        buffer.guard = undefined;
        buffer.guardLocal = undefined;
      }
    }
    buffer.pending = undefined;
    buffer.continuation = undefined;
    buffer.continuationLocal = undefined;
  }
  if (buffer.pending && buffer.pending.revision !== open.revision) {
    buffer.pending = undefined;
    buffer.continuation = undefined;
    buffer.continuationLocal = undefined;
    buffer.confirmed = undefined;
    buffer.confirmedLocal = undefined;
  }
  // A cancelled save has no continuation to release. Its request may be
  // hidden by a newer cancelled retry, so the accepted native snapshot is
  // the only receipt available for this bounded reconciliation marker.
  if (buffer.cancelledSave && matchesNative(buffer.cancelledSave)) {
    if (buffer.text === buffer.cancelledSave.text) buffer.dirty = false;
    buffer.cancelledSave = undefined;
  }
  if (buffer.cancelledSave && buffer.cancelledSave.revision !== open.revision) {
    buffer.cancelledSave = undefined;
  }
  if (!buffer.dirty) { buffer.text = open.body; buffer.revision = open.revision; }
  buffer.open = open;
  return buffer;
}

/** Read the retained buffer without remounting its provider state. */
export function currentBuffer(id: string): FileBuffer | undefined {
  return buffers.get(id);
}

export function bodyId(id: string): string | undefined {
  const current = buffers.get(id);
  return current && current.sourceVisible
    ? `${id}/editor/body/${current.key}` : undefined;
}

export function editBuffer(current: FileBuffer, value: string, revision?: number): void {
  current.text = value;
  current.revision = revision ?? current.revision;
  current.dirty = value !== current.open.body;
  if (current.pending?.text !== value) {
    current.pending = undefined;
    current.continuation = undefined;
    current.continuationLocal = undefined;
    current.confirmed = undefined;
    current.confirmedLocal = undefined;
  }
}

export function saveBuffer(current: FileBuffer, event: UiEvent, continueGuard = false): Command {
  editBuffer(current, event.value ?? current.text, event.revision);
  current.pending = { text: current.text, revision: current.revision, request: `${current.key}/${nextSave++}`,
    binding: current.open.binding, uid: current.open.uid };
  current.continuation = continueGuard ? current.guard : undefined;
  current.continuationLocal = continueGuard ? current.guardLocal : undefined;
  if (!continueGuard) { current.guard = undefined; current.guardLocal = undefined; }
  if (!continueGuard) current.released = undefined;
  return documentAction(current.doc, "text", { field: "file_save", option: fileOption(current.open),
    text: current.text, revision: current.revision, request: current.pending.request });
}

/** Callers submit bodyId(id) so even an unflushed editor draft is guarded. */
/** `released` runs once the command actually leaves: at once, or when
 *  the guard is discarded or saved through; never on a cancel. */
export function guard(id: string, command: Command, affectedSide?: string, released?: () => void): Handler {
  return (event) => {
    const current = buffers.get(id);
    if (!current || (affectedSide && current.open.store !== affectedSide)) { released?.(); return command; }
    if (event.value !== undefined) editBuffer(current, event.value, event.revision);
    if (!current.dirty && !current.pending) { released?.(); return command; }
    current.guard = command;
    current.guardLocal = undefined;
    current.released = released;
    current.continuation = undefined;
    current.continuationLocal = undefined;
    current.confirmed = undefined;
    current.confirmedLocal = undefined;
    return undefined;
  };
}

export function discardGuard(current: FileBuffer): Command | undefined {
  const command = current.guard;
  const local = current.guardLocal;
  if (!command && !local) return undefined;
  current.guard = undefined;
  current.guardLocal = undefined;
  current.continuation = undefined;
  current.continuationLocal = undefined;
  current.confirmed = undefined;
  current.confirmedLocal = undefined;
  current.released?.();
  current.released = undefined;
  local?.();
  buffers.delete(scope(current.doc));
  return command;
}
export function cancelGuard(current: FileBuffer): void {
  if (current.pending) current.cancelledSave = current.pending;
  current.guard = undefined; current.guardLocal = undefined;
  current.continuation = undefined; current.continuationLocal = undefined;
  current.pending = undefined;
  current.confirmed = undefined; current.confirmedLocal = undefined;
  current.released = undefined;
}

/** Guard a local workspace transition without ever returning a sim command. */
export function localGuard(id: string, continuation: () => void): Handler {
  return (event) => {
    const current = buffers.get(id);
    if (!current) { continuation(); return undefined; }
    if (event.value !== undefined) editBuffer(current, event.value, event.revision);
    // The editor is leaving the tree. Future native actions must not submit
    // an input node that the selected workspace no longer mounts.
    current.sourceVisible = false;
    if (!current.dirty && !current.pending) {
      continuation();
      return undefined;
    }
    current.guard = undefined;
    current.guardLocal = continuation;
    current.continuation = undefined;
    current.continuationLocal = undefined;
    current.confirmed = undefined;
    current.confirmedLocal = undefined;
    return undefined;
  };
}
export function discardBuffer(id: string): void { buffers.delete(id); }

/** One Create owner per workspace; naming state survives guard replacement. */
interface CreateDraft { ext: string; stem: string }
const createDialogs = new Map<string, CreateDraft>();
export const createDialog = (key: string): CreateDraft | undefined => createDialogs.get(key);
export function openCreateDialog(key: string, ext: string): void {
  const stem = createDialogs.get(key)?.stem ?? "";
  const workspace = key.slice(0, key.lastIndexOf("/"));
  for (const other of createDialogs.keys()) if (other.startsWith(`${workspace}/`)) createDialogs.delete(other);
  createDialogs.set(key, { ext, stem });
}
export function closeCreateDialog(key: string): void { createDialogs.delete(key); }

export function retainOpenFileBuffers(documents: PanelDocument[]): void {
  const visible = new Set<string>();
  for (const doc of documents) {
    const id = scope(doc);
    visible.add(id);
    editorBuffer(id, doc, (doc.state ?? {}) as Partial<ModuleState>);
  }
  for (const id of buffers.keys()) if (!visible.has(id)) buffers.delete(id);
  for (const key of createDialogs.keys()) if (![...visible].some((id) => key.startsWith(`${id}/`))) createDialogs.delete(key);
}

/** The host polls after authoritative updates; revoked scopes never continue. */
export function pollContinuation(documents: PanelDocument[]): Command | undefined {
  retainOpenFileBuffers(documents);
  for (const current of buffers.values()) {
    if (current.confirmedLocal) {
      const continuation = current.confirmedLocal;
      current.confirmedLocal = undefined;
      continuation();
    }
    if (!current.confirmed) continue;
    const command = current.confirmed;
    current.confirmed = undefined;
    return command;
  }
  return undefined;
}
