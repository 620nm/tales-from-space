import type { UiEvent } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState, OpenFile, PanelDocument } from "./document-model";
import { documentAction } from "./document-action";
import type { Command, Handler } from "./view";

export interface FileBuffer {
  key: number;
  text: string;
  revision: number;
  dirty: boolean;
  pending?: { text: string; revision: number; request: string };
  continuation?: Command;
  confirmed?: Command;
  guard?: Command;
  doc: DocumentIdentity;
  open: OpenFile;
  bindings: string;
}
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
    buffer.guard = undefined;
    buffer.confirmed = undefined;
    buffer.bindings = bindings(state);
  }
  const ack = state.save_ack;
  if (buffer.pending && ack?.request === buffer.pending.request &&
      ack.binding === open.binding && ack.uid === open.uid &&
      ack.revision === buffer.pending.revision + 1 && open.revision === ack.revision &&
      open.body === buffer.pending.text) {
    if (buffer.text === buffer.pending.text) {
      buffer.dirty = false;
      buffer.confirmed = buffer.continuation;
    }
    buffer.pending = undefined;
    buffer.continuation = undefined;
  }
  if (!buffer.dirty) { buffer.text = open.body; buffer.revision = open.revision; }
  buffer.open = open;
  return buffer;
}

export function bodyId(id: string): string | undefined {
  const current = buffers.get(id);
  return current ? `${id}/editor/body/${current.key}` : undefined;
}

export function editBuffer(current: FileBuffer, value: string, revision?: number): void {
  current.text = value;
  current.revision = revision ?? current.revision;
  current.dirty = value !== current.open.body;
  if (current.pending?.text !== value) {
    current.pending = undefined;
    current.continuation = undefined;
    current.confirmed = undefined;
  }
}

export function saveBuffer(current: FileBuffer, event: UiEvent, continueGuard = false): Command {
  editBuffer(current, event.value ?? current.text, event.revision);
  current.pending = { text: current.text, revision: current.revision, request: `${current.key}/${nextSave++}` };
  current.continuation = continueGuard ? current.guard : undefined;
  current.guard = undefined;
  return documentAction(current.doc, "text", { field: "file_save", option: fileOption(current.open),
    text: current.text, revision: current.revision, request: current.pending.request });
}

/** Callers submit bodyId(id) so even an unflushed editor draft is guarded. */
export function guard(id: string, command: Command, affectedSide?: string): Handler {
  return (event) => {
    const current = buffers.get(id);
    if (!current || (affectedSide && current.open.store !== affectedSide)) return command;
    if (event.value !== undefined) editBuffer(current, event.value, event.revision);
    if (!current.dirty && !current.pending) return command;
    current.guard = command;
    current.continuation = undefined;
    current.confirmed = undefined;
    return undefined;
  };
}

export function discardGuard(current: FileBuffer): Command | undefined {
  const command = current.guard;
  buffers.delete(scope(current.doc));
  return command;
}
export function cancelGuard(current: FileBuffer): void { current.guard = undefined; }
export function discardBuffer(id: string): void { buffers.delete(id); }

export function retainOpenFileBuffers(documents: PanelDocument[]): void {
  const visible = new Set<string>();
  for (const doc of documents) {
    const id = scope(doc);
    visible.add(id);
    editorBuffer(id, doc, (doc.state ?? {}) as Partial<ModuleState>);
  }
  for (const id of buffers.keys()) if (!visible.has(id)) buffers.delete(id);
}

/** The host polls after authoritative updates; revoked scopes never continue. */
export function pollContinuation(documents: PanelDocument[]): Command | undefined {
  retainOpenFileBuffers(documents);
  for (const current of buffers.values()) {
    if (!current.confirmed) continue;
    const command = current.confirmed;
    current.confirmed = undefined;
    return command;
  }
  return undefined;
}
