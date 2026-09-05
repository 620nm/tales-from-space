import type { UiNode, Json, UiEvent } from "@lunatic/ui";
export type Command = Record<string, Json>;
const actions = new Map<
  string,
  Command | ((event: UiEvent) => Command | undefined)
>();
export function begin(): void {
  actions.clear();
}
export function node(
  type: UiNode["type"],
  id: string,
  extra: Partial<UiNode> = {},
): UiNode {
  return { type, id, ...extra };
}
// One node carries at most 4096 UTF-16 units; over that the host
// quarantines this package, so every label it writes is cut here.
const TEXT_LIMIT = 4096;
function label(value: unknown): string {
  return String(value ?? "").slice(0, TEXT_LIMIT);
}
export function text(id: string, value: unknown): UiNode {
  return node("text", id, { text: label(value) });
}
export function column(
  id: string,
  children: UiNode[],
  style: UiNode["style"] = {},
): UiNode {
  return node("column", id, { children, style: { gap: 5, ...style } });
}
export function row(
  id: string,
  children: UiNode[],
  style: UiNode["style"] = {},
): UiNode {
  return node("row", id, {
    children,
    style: { gap: 5, alignItems: "center", flexWrap: "wrap", ...style },
  });
}
export function pane(
  id: string,
  children: UiNode[],
  style: UiNode["style"] = {},
): UiNode {
  return node("panel", id, {
    children,
    style: {
      gap: 6,
      padding: 10,
      borderRadius: 4,
      backgroundColor: "#111",
      pointerEvents: "auto",
      overflow: "auto",
      ...style,
    },
  });
}
export function button(
  id: string,
  caption: unknown,
  action: Command | ((event: UiEvent) => Command | undefined),
  disabled = false,
): UiNode {
  actions.set(id, action);
  return node("button", id, { text: label(caption), event: id, disabled });
}
export function input(
  id: string,
  value: string,
  callback: (value: string) => Command | undefined,
  multiline = false,
): UiNode {
  actions.set(id, (event) => callback(event.value ?? ""));
  return node(multiline ? "textarea" : "input", id, {
    value,
    event: id,
    ...(id === "chat"
      ? { submitOnly: true, clearOnSubmit: true, blurOnSubmit: true }
      : {}),
  });
}
export function icon(
  id: string,
  sprite: string | null | undefined,
  label = "",
): UiNode {
  return sprite
    ? node("image", id, {
        asset: sprite,
        text: label,
        style: { width: 32, height: 32 },
      })
    : text(id, "");
}
export function event(event: UiEvent): { action?: Json } {
  const action = actions.get(event.id);
  if (typeof action === "function")
    return { action: action(event) as Json | undefined };
  return { action: action };
}
export function inspect(target: Json): Command {
  return { kind: "examine", target };
}

export function item(button: UiNode, token: string): UiNode {
  return { ...button, item: token };
}
