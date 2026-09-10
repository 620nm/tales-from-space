// Every inventory square resolves the same gesture before navigation.
import type { Json, UiEvent } from "@lunatic/ui";
import type { InventoryState, ItemView } from "./model";
import { openStorageSite } from "./inventory-storage";
import { fromEvent } from "./gesture";
import { inspect, type Command } from "./view";

export function inventoryEvent(
  event: UiEvent, target: Json, item: ItemView | null | undefined,
  current: InventoryState, navigate: () => Command | undefined,
  activeSlot = false,
): Command | undefined {
  if (event.meta) return undefined;
  const shape = fromEvent(event);
  const value = target as Record<string, { hand?: number }>;
  const held = value.Held?.hand;
  const container = item?.contents != null || (held !== undefined && current.held?.[held] != null);
  if (shape?.id === "alt_primary" && container) return openStorageSite(target, current.receipt);
  if (shape && (((item?.gestures ?? 0) >>> shape.rank) & 1) === 1)
    return { kind: "use_item", target, gesture: shape.id, receipt: current.receipt };
  if (event.type === "context" || (event.type === "activate" && event.shift))
    return inspect("NestedGround" in value ? { NestedGround: { ...(target as Record<string, Record<string, Json>>).NestedGround, receipt: current.receipt } } : target);
  if (event.type !== "activate" || event.shift || event.ctrl || event.alt)
    return undefined;
  if (item && current.hands?.[current.active] && !activeSlot)
    return { kind: "interact_item", target, receipt: current.receipt };
  return navigate();
}
