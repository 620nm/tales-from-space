// The server's words. A document field is either a `Label` naming a
// catalog id with its arguments or one quoting content's own word
// (docs/tgui/labels.md); one reader for both, so a row reads the same
// whichever author wrote it.
import type { Json } from "@lunatic/ui";
import { tfs } from "./strings";

export type Label =
  | string
  | number
  | boolean
  | null
  | { text?: string; id?: string; args?: Record<string, Json> | null };

// One node carries at most 4096 UTF-16 units; over that the host
// quarantines the package, so every word it writes is cut here.
const TEXT_LIMIT = 4096;

/** `lunatic/tfs:module.<id>` with the facts the engine composed for it.
 *  A key nothing renders answers with itself, which is on screen and
 *  cannot be read as a dropped row (docs/localization/catalogs.md §4). */
function moduleLabel(id: string, args?: Record<string, Json> | null): string {
  if (!args) return tfs(`module.${id}`);
  const values: Record<string, string> = {};
  for (const [name, value] of Object.entries(args))
    if (value !== null && value !== undefined) values[name] = String(value);
  return tfs(`module.${id}`, values);
}

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
