// Node plumbing: the id-to-command table every press is registered in,
// and the thin wrappers the screens build with. Presentation belongs to
// the kit and `theme.ts`; nothing here spells a colour or a size.
import type {
  Json,
  StyleProps,
  StyleValue,
  UiEvent,
  UiNode,
} from "@lunatic/ui";
import { Button, type ButtonOpts } from "@lunatic/ui";
import { labelText } from "./labels";

export type Command = Record<string, Json>;
export type Handler = Command | ((event: UiEvent) => Command | undefined);
export interface Box {
  cls?: string[];
  style?: StyleProps;
}

const actions = new Map<string, Handler>();

export function begin(): void {
  actions.clear();
}

/** Register what a logical event id means, and answer with that id. */
export function bind(id: string, action: Handler): string {
  actions.set(id, action);
  return id;
}

export function event(e: UiEvent): { action?: Json } {
  const action = actions.get(e.id);
  if (typeof action === "function")
    return { action: action(e) as Json | undefined };
  return { action };
}

function box(
  type: "panel" | "row" | "column",
  id: string,
  children: UiNode[],
  opts: Box,
): UiNode {
  return {
    id,
    type,
    ...(opts.cls?.length ? { class: opts.cls } : {}),
    ...(opts.style ? { style: opts.style as Record<string, StyleValue> } : {}),
    ...(children.length ? { children } : {}),
  };
}

export const panel = (id: string, children: UiNode[], opts: Box = {}): UiNode =>
  box("panel", id, children, opts);
export const column = (id: string, children: UiNode[], opts: Box = {}): UiNode =>
  box("column", id, children, opts);
export const row = (id: string, children: UiNode[], opts: Box = {}): UiNode =>
  box("row", id, children, opts);

export function text(id: string, value: unknown, cls?: string[]): UiNode {
  return {
    id,
    type: "text",
    text: labelText(value as Json),
    ...(cls?.length ? { class: cls } : {}),
  };
}

/** A press, bound to what it means. The caller's id lands on the button. */
export function press(
  id: string,
  caption: unknown,
  action: Handler,
  opts: Omit<ButtonOpts, "event"> = {},
): UiNode {
  return Button(id, labelText(caption as Json), {
    ...opts,
    event: bind(id, action),
  });
}

export interface FieldOpts extends Box {
  multiline?: boolean;
  submitOnly?: boolean;
  clearOnSubmit?: boolean;
  blurOnSubmit?: boolean;
  revision?: number;
}

export function entry(
  id: string,
  value: string,
  callback: (value: string, e: UiEvent) => Command | undefined,
  opts: FieldOpts = {},
): UiNode {
  bind(id, (e) => callback(e.value ?? "", e));
  return {
    id,
    type: opts.multiline ? "textarea" : "input",
    value,
    event: id,
    class: [opts.multiline ? "area" : "entry", ...(opts.cls ?? [])],
    ...(opts.style ? { style: opts.style as Record<string, StyleValue> } : {}),
    ...(opts.submitOnly ? { submitOnly: true } : {}),
    ...(opts.clearOnSubmit ? { clearOnSubmit: true } : {}),
    ...(opts.blurOnSubmit ? { blurOnSubmit: true } : {}),
    ...(opts.revision === undefined ? {} : { revision: opts.revision }),
  };
}

export function icon(
  id: string,
  sprite: string | null | undefined,
  label = "",
  cls: string[] = [],
): UiNode | null {
  return sprite
    ? { id, type: "image", asset: sprite, text: label, class: ["icon", ...cls] }
    : null;
}

export const inspect = (target: Json): Command => ({
  kind: "examine",
  target,
});

/** Hang a drag token off a press the native inventory validates. */
export const withItem = (node: UiNode, token: string): UiNode => ({
  ...node,
  item: token,
});

export const some = (...nodes: (UiNode | null | false)[]): UiNode[] =>
  nodes.filter((node): node is UiNode => !!node);
