// What a device document says about itself beside its rows: the node's
// own address and link state (engine `link`), and the refusal its reader
// was last shown (engine `refusal`; engine `docs/tgui/documents.md`).
import type { UiNode } from "@lunatic/ui";
import { Dialog } from "@lunatic/ui";
import type { DocumentIdentity, ModuleState } from "./document-model";
import { labelText } from "./labels";
import { press, text } from "./view";
import { tfs } from "./strings";

/** The refusal serial each document's reader has dismissed; never sent. */
const dismissed = new Map<string, number>();

/** `MAC · Online` beside a device's name, where the document has a link. */
export function linkMeta(id: string, state: Partial<ModuleState>, cls: string[]): UiNode | null {
  const link = state.link;
  if (!link) return null;
  return text(`${id}/link`, tfs("ui.device.link", {
    address: link.address,
    state: tfs(link.online ? "ui.device.online" : "ui.device.offline"),
  }), cls);
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
