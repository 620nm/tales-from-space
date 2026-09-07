// Disclosed container paths open next to their source item. Paths are bounded
// by the native inventory projection and every move is revalidated there.
import type { Json, UiNode } from "@lunatic/ui";
import { hudSlot } from "./slots";
import { Pane } from "@lunatic/ui";
import type { GameplayView, InventoryState, ItemView } from "./model";
import { bind, column, inspect, press, row, some, type Box } from "./view";
import * as S from "./strings";

interface Container { slot?: string; hand?: number; path: number[] }
let opened: Container[] = [];
const root = (which: Container): string => which.slot === undefined ? `hand/${which.hand ?? 0}` : `equipment/${which.slot}`;
const key = (which: Container): string => `${root(which)}/${which.path.join("-")}`;
const source = (which: Container): string => which.path.length
  ? `stored/${key(which)}/take`
  : which.slot === undefined ? `hand/${which.hand ?? 0}/pick` : `equipment/${which.slot}/pick`;
const site = (which: Container): Json => which.path.length
  ? which.slot === undefined ? { NestedHeld: { hand: which.hand ?? 0, path: which.path } } : { NestedEquipment: { slot: which.slot, path: which.path } }
  : which.slot === undefined ? { Held: { hand: which.hand ?? 0 } } : { Equipment: { slot: which.slot } };

export function openStorage(which: { slot?: string; hand?: number; path?: number[] }): void {
  const container = { ...which, path: which.path ?? [] };
  if (container.path.length >= 4 || opened.some((held) => key(held) === key(container))) return;
  if (opened.length >= 8) opened = opened.slice(1);
  opened.push(container);
}
export const closeStorage = (): void => { opened = []; };

function close(which: Container): void {
  opened = opened.filter((held) => root(held) !== root(which)
    || !which.path.every((part, index) => held.path[index] === part));
}

function contents(view: GameplayView, current: InventoryState, which: Container): { items: ItemView[]; label: string } | undefined {
  const roster = view.state.equipment?.slots ?? [];
  const slot = roster.findIndex((candidate) => candidate.id === which.slot);
  const equipment = current.equipment?.find((worn) => worn.slot === slot);
  let item = which.slot === undefined ? current.hands?.[which.hand ?? 0] : equipment?.item;
  let items = which.slot === undefined ? current.held?.[which.hand ?? 0] : equipment?.contents;
  for (const index of which.path) { item = items?.[index]; items = item?.contents; }
  if (!items) return undefined;
  return { items, label: item?.name ?? (which.slot === undefined ? S.hand(which.hand ?? 0) : roster[slot]?.label ?? S.STORAGE) };
}

function storedSlot(index: number, item: ItemView, container: Container, current: InventoryState): UiNode {
  const which = { ...container, path: [...container.path, index] };
  const id = source(which);
  return hudSlot(id, {
    sprite: item.sprite, label: S.short(item.name),
    ...(item.fill ? { fill: item.fill } : {}),
    item: which.slot === undefined
      ? `nested-held/${which.hand ?? 0}/${which.path.join("/")}`
      : `nested-equipment/${which.slot}/${which.path.join("/")}`,
    event: bind(id, (e) => {
      if (e.type === "context") return inspect(site(which));
      if (item.contents) { openStorage(which); return undefined; }
      return { kind: "move_item", from: site(which), to: { Held: { hand: current.active } } };
    }),
  });
}

export function storageRegion(view: GameplayView, place: Box = {}): UiNode | null {
  const current = view.state.inventory;
  if (!view.body || !current) { closeStorage(); return null; }
  opened = opened.filter((which) => contents(view, current, which));
  const panels = opened.map((which) => {
    const disclosed = contents(view, current, which)!;
    const id = `storage/${key(which)}`;
    const destination = site(which);
    return {
      ...Pane(id, [
        row(`${id}/controls`, some(
          press(`${id}/store`, S.STORE_HELD, { kind: "move_item", from: { Held: { hand: current.active } }, to: destination }),
          which.path.length
            ? press(`${id}/take`, S.tfs("ui.storage.take_container"), { kind: "move_item", from: destination, to: { Held: { hand: current.active } } })
            : which.slot === undefined ? null : press(`${id}/off`, S.TAKE_OFF, { kind: "unequip", slot: which.slot }),
          press(`${id}/close`, S.CLOSE_MARK, () => { close(which); return undefined; }, { variant: "ghost" }),
        ), { style: { alignItems: "center", gap: 4 } }),
        row(`${id}/items`, disclosed.items.map((item, index) => storedSlot(index, item, which, current)), { style: { gap: 4, flexWrap: "wrap" } }),
      ], { cls: place.cls ?? [], ...(place.style ? { style: place.style } : {}) }),
      window: { key: id, title: S.storageTitle(disclosed.label), width: 350,
        height: Math.min(420, 100 + Math.ceil(disclosed.items.length / 7) * 44), source: source(which) },
    };
  });
  return panels.length ? column("storage-windows", panels, { cls: ["hudgroup"] }) : null;
}
