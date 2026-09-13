import type { Json } from "@lunatic/ui";
import type { DocumentIdentity } from "./document-model";
import type { Command } from "./view";

export function documentAction(
  doc: DocumentIdentity,
  act: string,
  payload: Json,
): Command {
  return {
    kind: "document",
    document: doc.id,
    generation: doc.generation,
    act,
    payload,
  };
}

/** Script documents accept one bounded string value, including button acts. */
export const scriptAction = (
  doc: DocumentIdentity,
  act: string,
  value = "",
): Command => documentAction(doc, act, { value });
