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
  | {
      text?: string;
      id?: string;
      args?: Record<string, Json> | null;
      /** Arguments whose VALUE is itself a label id, named by the
       *  engine rather than guessed at (docs/tgui/labels.md §1). */
      arg_ids?: string[] | null;
    };

// One node carries at most 4096 UTF-16 units; over that the host
// quarantines the package, so every word it writes is cut here.
const TEXT_LIMIT = 4096;

/** The names the label declared as ids of their own; anything else is a
 *  word already — an address, a number, content's own name. */
function nested(names: unknown): Set<string> {
  return new Set(
    Array.isArray(names)
      ? names.filter((name): name is string => typeof name === "string")
      : [],
  );
}

/** `lunatic/tfs:module.<id>` with the facts the engine composed for it.
 *  An argument the label named in `arg_ids` is an id in its own right
 *  and is rendered before it is substituted. A key nothing renders
 *  answers with itself, which is on screen and cannot be read as a
 *  dropped row (docs/localization/catalogs.md §4). */
function moduleLabel(
  id: string,
  args?: Record<string, Json> | null,
  argIds?: unknown,
): string {
  if (!args) return tfs(`module.${id}`);
  const ids = nested(argIds);
  const values: Record<string, string> = {};
  for (const [name, value] of Object.entries(args)) {
    if (value === null || value === undefined) continue;
    const word = String(value);
    values[name] = ids.has(name) ? tfs(`module.${word}`) : word;
  }
  return tfs(`module.${id}`, values);
}

export function labelText(label: Label | undefined | Json): string {
  if (label === undefined || label === null) return "";
  if (typeof label === "string") return label.slice(0, TEXT_LIMIT);
  if (typeof label === "number" || typeof label === "boolean")
    return String(label);
  if (typeof label !== "object" || Array.isArray(label)) return "";
  const row = label as {
    text?: unknown;
    id?: unknown;
    args?: unknown;
    arg_ids?: unknown;
  };
  if (typeof row.id === "string")
    return moduleLabel(
      row.id,
      (row.args ?? null) as Record<string, Json> | null,
      row.arg_ids,
    ).slice(0, TEXT_LIMIT);
  return typeof row.text === "string" ? row.text.slice(0, TEXT_LIMIT) : "";
}

/** The catalog id a `Label` NAMES, for a reader that branches on which
 *  word the server sent rather than drawing it. Undefined for a quoted
 *  word, which names nothing (docs/tgui/labels.md). */
export function labelId(label: Label | undefined | Json): string | undefined {
  if (label === null || typeof label !== "object" || Array.isArray(label))
    return undefined;
  const id = (label as { id?: unknown }).id;
  return typeof id === "string" ? id : undefined;
}
