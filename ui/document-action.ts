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
