// Every inventory square resolves the same gesture before navigation.
import type { Json, UiEvent } from "@lunatic/ui";
import type { InventoryState, ItemView } from "./model";
import { fromEvent } from "./gesture";
import { inspect, type Command } from "./view";

export function inventoryEvent(
  event: UiEvent, target: Json, item: ItemView | null | undefined,
  current: InventoryState, navigate: () => Command | undefined,
  activeSlot = false,
): Command | undefined {
  if (event.meta) return undefined;
  const shape = fromEvent(event);
  if (shape && (((item?.gestures ?? 0) >>> shape.rank) & 1) === 1)
    return { kind: "use_item", target, gesture: shape.id, receipt: current.receipt };
  if (event.type === "context" || (event.type === "activate" && event.shift))
    return inspect(target);
  if (event.type !== "activate" || event.shift || event.ctrl || event.alt)
    return undefined;
  if (item && current.hands?.[current.active] && !activeSlot)
    return { kind: "interact_item", target, receipt: current.receipt };
  return navigate();
}
