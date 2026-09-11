// What a device document says about itself beside its rows: the node's
// own address and link state (engine `link`), and the refusal its reader
// was last shown (engine `refusal`; engine `docs/tgui/documents.md`).
import type { UiNode } from "@lunatic/ui";
import { Dialog, Stack } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState } from "./document-model";
import { labelText } from "./labels";
import { press, text } from "./view";
import { tfs } from "./strings";

/** The refusal serial each document's reader has dismissed; never sent. */
const dismissed = new Map<string, number>();

/** Forget dismissals for documents no longer open. */
export function retainRefusals(open: DocumentIdentity[]): void {
  const live = new Set(open.map((doc) => `${doc.id}/${doc.generation}`));
  for (const key of dismissed.keys()) if (!live.has(key)) dismissed.delete(key);
}

/** A device's address and link state beside its name: the state is the
 *  diagnosis as the engine names it, toned by whether it is online. */
export function linkMeta(id: string, state: Partial<ModuleState>, addressCls: string[], stateCls: string[],
  grow = false): UiNode | null {
  const link = state.link;
  if (!link) return null;
  return Stack(`${id}/link`, [
    text(`${id}/link/address`, link.address, addressCls),
    text(`${id}/link/state`, link.state, [...stateCls, link.online ? "tone-on" : "tone-off"]),
  ], { gap: 6, align: "center", ...(grow ? { cls: ["grow"] } : {}) });
}

/** The modal a refused press raises for its own reader, until OK. */
export function refusalDialog(id: string, doc: DocumentIdentity, state: Partial<ModuleState>): UiNode | null {
  const refusal = state.refusal;
  const memory = `${doc.id}/${doc.generation}`;
  if (!refusal || dismissed.get(memory) === refusal.serial) return null;
  const key = `${id}/refusal`;
  const ok = (): undefined => {
    dismissed.set(memory, refusal.serial);
    return undefined;
  };
  return Dialog(key, {
    title: tfs("ui.document.refused"),
    body: [text(`${key}/text`, labelText(refusal.text))],
    actions: [press(`${key}/ok`, tfs("ui.document.ok"), ok, { variant: "primary" })],
  }, { initialFocus: `${key}/ok`, dismissEvent: `${key}/ok`, dismissLabel: tfs("ui.document.ok") });
}
