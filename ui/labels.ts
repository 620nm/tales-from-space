// The server's words. A document field is either a plain string (what
// the server sends today) or a `Label` naming a catalog id with its
// arguments (CONTRACT §I2); one reader for both, so the catalog landing
// changes nothing above here.
import type { Json } from "@lunatic/ui";
import { moduleLabel } from "./strings";

export type Label =
  | string
  | number
  | boolean
  | null
  | { text?: string; id?: string; args?: Record<string, Json> | null };

// One node carries at most 4096 UTF-16 units; over that the host
// quarantines the package, so every word it writes is cut here.
const TEXT_LIMIT = 4096;

export function labelText(label: Label | undefined | Json): string {
  if (label === undefined || label === null) return "";
  if (typeof label === "string") return label.slice(0, TEXT_LIMIT);
  if (typeof label === "number" || typeof label === "boolean")
    return String(label);
  if (typeof label !== "object" || Array.isArray(label)) return "";
  const row = label as { text?: unknown; id?: unknown; args?: unknown };
  if (typeof row.id === "string")
    return moduleLabel(
      row.id,
      (row.args ?? null) as Record<string, Json> | null,
    ).slice(0, TEXT_LIMIT);
  return typeof row.text === "string" ? row.text.slice(0, TEXT_LIMIT) : "";
}
