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
import {
  Button, Dropdown, Screen,
  type ButtonOpts, type ScreenParts, type ScrollAxis,
} from "@lunatic/ui";
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

export interface ScreenOpts extends Box {
  /** Which way the body yields: down unless the panes in it scroll down themselves. */
  axis?: ScrollAxis;
}

/** A window's whole body on the kit's `Screen`: bars that never shrink
 *  around the one `Scroll`, at `<id>/body`, which `axis` turns sideways
 *  when the body holds screens of its own (docs/pack-ui/components.md).
 *  Answered as a `panel`, the one type a window descriptor may sit on;
 *  a panel and a column lay out alike (docs/pack-ui/box-model.md). */
export function screen(id: string, parts: ScreenParts, opts: ScreenOpts = {}): UiNode {
  const node: UiNode = {
    ...Screen(id, parts, { ...(opts.cls ? { cls: opts.cls } : {}), ...(opts.style ? { style: opts.style } : {}) }),
    type: "panel",
  };
  const across = opts.axis === "x" ? "scroll-x" : opts.axis === "both" ? "scroll-xy" : undefined;
  if (!across) return node;
  return { ...node, children: node.children?.map((child) =>
    child.id === `${id}/body` ? { ...child, class: [...(child.class ?? []), across] } : child) };
}

export function text(
  id: string,
  value: unknown,
  cls?: string[],
  style?: StyleProps,
): UiNode {
  return {
    id,
    type: "text",
    text: labelText(value as Json),
    ...(cls?.length ? { class: cls } : {}),
    ...(style ? { style: style as Record<string, StyleValue> } : {}),
  };
}

/** A press, bound to what it means. The caller's id lands on the button.
 *  `label` is the name a press is READ by where its caption is a glyph
 *  or empty; it belongs to the button itself, so it is not offered
 *  beside `icon`, which wraps the press in a row of its own. */
export function press(
  id: string,
  caption: unknown,
  action: Handler,
  opts: Omit<ButtonOpts, "event"> & { label?: string } = {},
): UiNode {
  const { label, ...rest } = opts;
  const node = Button(id, labelText(caption as Json), {
    ...rest,
    event: bind(id, action),
  });
  return label && node.type === "button" ? { ...node, label } : node;
}

export interface FieldOpts extends Box {
  multiline?: boolean;
  submitOnly?: boolean;
  clearOnSubmit?: boolean;
  blurOnSubmit?: boolean;
  debounceMs?: number;
  revision?: number;
  disabled?: boolean;
  language?: "luau";
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
    ...(opts.debounceMs === undefined ? {} : { debounceMs: opts.debounceMs }),
    ...(opts.disabled ? { disabled: true } : {}),
    ...(opts.revision === undefined ? {} : { revision: opts.revision }),
    ...(opts.language === undefined ? {} : { language: opts.language }),
  };
}

export interface Choice {
  value: string;
  text: unknown;
}

/** A closed list of choices; a change answers with the chosen value,
 *  and a press naming this id in `submitValues` carries it too. */
export function select(
  id: string,
  value: string,
  choices: Choice[],
  callback: (value: string, e: UiEvent) => Command | undefined,
  opts: Box & { disabled?: boolean } = {},
): UiNode {
  return Dropdown(id, value, choices.map((choice) => ({ value: choice.value, text: labelText(choice.text as Json) })), {
    event: bind(id, (e) => callback(e.value ?? "", e)),
    ...(opts.cls ? { cls: opts.cls } : {}),
    ...(opts.style ? { style: opts.style } : {}),
    ...(opts.disabled ? { disabled: true } : {}),
  });
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

/** Nodes in a subtree, against the protocol's per-tree budget. */
export const nodeCount = (nodes: UiNode[]): number =>
  nodes.reduce((sum, node) => sum + 1 + nodeCount(node.children ?? []), 0);

export const some = (...nodes: (UiNode | null | false)[]): UiNode[] =>
  nodes.filter((node): node is UiNode => !!node);
