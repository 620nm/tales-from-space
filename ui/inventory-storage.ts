// Disclosed container paths open next to their source item. Paths are bounded
// by the native inventory projection and every move is revalidated there.
import type { Json, UiNode } from "@lunatic/ui";
import { hudSlot } from "./slots";
import type { GameplayView, InventoryState, ItemView } from "./model";
import { bind, column, press, row, screen, some, text, type Command, type Box } from "./view";
import { inventoryEvent } from "./inventory-event";
import * as S from "./strings";

interface Container { slot?: string; hand?: number; target?: number; pos?: { x: number; y: number }; path: number[] }
let opened: Container[] = [];
const root = (which: Container): string => which.target !== undefined ? `ground/${which.target}` : which.slot === undefined ? `hand/${which.hand ?? 0}` : `equipment/${which.slot}`;
const key = (which: Container): string => `${root(which)}/${which.path.join("-")}`;
const source = (which: Container): string => which.target !== undefined && !which.path.length ? `ground/${which.target}` : which.path.length
  ? `stored/${key(which)}/take`
  : which.slot === undefined ? `hand/${which.hand ?? 0}/pick` : `equipment/${which.slot}/pick`;
const site = (which: Container): Json => which.target !== undefined
  ? { NestedGround: { target: which.target, pos: which.pos!, path: which.path } }
  : which.path.length
  ? which.slot === undefined ? { NestedHeld: { hand: which.hand ?? 0, path: which.path } } : { NestedEquipment: { slot: which.slot, path: which.path } }
  : which.slot === undefined ? { Held: { hand: which.hand ?? 0 } } : { Equipment: { slot: which.slot } };

export function openStorage(which: Omit<Container, "path"> & { path?: number[] }): void {
  const container = { ...which, path: which.path ?? [] };
  if (container.path.length >= 4 || opened.some((held) => key(held) === key(container))) return;
  if (opened.length >= 8) opened = opened.slice(1);
  opened.push(container);
}
export function openStorageSite(target: Json, receipt: number | null): Command {
  const value = target as Record<string, { hand?: number; slot?: string; target?: number; pos?: { x: number; y: number }; path?: number[]; index?: number }>;
  const held = value.Held ?? value.NestedHeld ?? value.StoredHeld;
  const worn = value.Equipment ?? value.NestedEquipment ?? value.StoredEquipment;
  const ground = value.NestedGround;
  const selected = held ?? worn ?? ground;
  if (selected) openStorage({ ...selected, path: selected.path ?? (selected.index === undefined ? [] : [selected.index]) });
  return { kind: "open_storage", target, receipt };
}
export const closeStorage = (): void => { opened = []; };

function close(which: Container): void {
  opened = opened.filter((held) => root(held) !== root(which)
    || !which.path.every((part, index) => held.path[index] === part));
}

// A container that declares how much it takes says so in its header.
// Nothing demands the field: a projection without one gets no count.
const capacityOf = (item: ItemView | null | undefined): number | undefined => {
  const declared = (item as { capacity?: unknown } | null | undefined)?.capacity;
  return typeof declared === "number" && declared > 0 ? declared : undefined;
};

function contents(view: GameplayView, current: InventoryState, which: Container): { items: ItemView[]; label: string; cap?: number } | undefined {
  const ground = current.open_ground?.find((root) => root.target === which.target);
  const roster = view.state.equipment?.slots ?? [];
  const slot = roster.findIndex((candidate) => candidate.id === which.slot);
  const equipment = current.equipment?.find((worn) => worn.slot === slot);
  let item = which.target !== undefined ? ground?.item : which.slot === undefined ? current.hands?.[which.hand ?? 0] : equipment?.item;
  let items = which.target !== undefined ? ground?.contents : which.slot === undefined ? current.held?.[which.hand ?? 0] : equipment?.contents;
  for (const index of which.path) { item = items?.[index]; items = item?.contents; }
  if (!items) return undefined;
  const cap = capacityOf(item);
  return {
    items,
    label: item?.name ?? (which.slot === undefined ? S.hand(which.hand ?? 0) : roster[slot]?.label ?? S.STORAGE),
    ...(cap === undefined ? {} : { cap }),
  };
}

function storedSlot(index: number, item: ItemView, container: Container, current: InventoryState): UiNode {
  const which = { ...container, path: [...container.path, index] };
  const id = source(which);
  return hudSlot(id, {
    sprite: item.sprite, label: S.short(item.name),
    ...(item.fill ? { fill: item.fill } : {}),
    item: which.target !== undefined ? `nested-ground/${which.target}/${which.path.join("/")}` : which.slot === undefined
      ? `nested-held/${which.hand ?? 0}/${which.path.join("/")}`
      : `nested-equipment/${which.slot}/${which.path.join("/")}`,
    event: bind(id, (e) => inventoryEvent(e, site(which), item, current, () => {
      if (item.contents) return openStorageSite(site(which), current.receipt);
      return { kind: "move_item", from: site(which), to: { Held: { hand: current.active } }, receipt: current.receipt };
    })),
  });
}

export function storageRegion(view: GameplayView, place: Box = {}): UiNode | null {
  const current = view.state.inventory;
  if (!view.body || !current) { closeStorage(); return null; }
  opened = opened.filter((which) => contents(view, current, which));
  const groundRoots = (current.open_ground ?? []).map((root) => ({ target: root.target, pos: root.pos, path: [] as number[] }));
  for (const root of groundRoots) if (!opened.some((which) => key(which) === key(root))) opened.push(root);
  const panels = opened.map((which) => {
    const disclosed = contents(view, current, which)!;
    const id = `storage/${key(which)}`;
    const destination = site(which);
    const takeSource = which.target !== undefined && !which.path.length
      ? { Ground: { target: which.target, pos: which.pos! } } : destination;
    // The tray closes from the host's title bar; only the meaning is
    // registered here, under the id the descriptor names.
    bind(`${id}/close`, () => { close(which); return { kind: "close_storage", target: destination, receipt: current.receipt }; });
    return {
      ...screen(id, {
        toolbar: some(
          press(`${id}/store`, S.STORE_HELD, { kind: "move_item", from: { Held: { hand: current.active } }, to: destination, receipt: current.receipt }, { variant: "ghost" }),
          which.path.length || which.target !== undefined
            ? press(`${id}/take`, S.tfs("ui.storage.take_container"), { kind: "move_item", from: takeSource, to: { Held: { hand: current.active } }, receipt: current.receipt }, { variant: "ghost" })
            : which.slot === undefined ? null : press(`${id}/off`, S.TAKE_OFF, { kind: "unequip", slot: which.slot }, { variant: "ghost" }),
          disclosed.cap === undefined
            ? null
            : text(`${id}/fill`, S.storageFill(disclosed.items.length, disclosed.cap), ["storage-count"]),
        ),
        body: disclosed.items.length ? [row(`${id}/items`, disclosed.items.map((item, index) => storedSlot(index, item, which, current)), { cls: ["storage-grid"] })] : [text(`${id}/empty`, S.tfs("ui.storage.empty"), ["hint"])],
      }, { cls: ["pane", "storage-window", ...(place.cls ?? [])], ...(place.style ? { style: place.style } : {}) }),
      window: { key: id, title: S.storageTitle(disclosed.label), width: 320,
        height: Math.min(420, 100 + Math.max(1, Math.ceil(disclosed.items.length / 7)) * 48),
        source: source(which), close: `${id}/close` },
    };
  });
  return panels.length ? column("storage-windows", panels, { cls: ["hudgroup"] }) : null;
}
