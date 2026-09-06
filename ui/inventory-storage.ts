// What an opened container holds. Which one is open is this package's
// own state — no server round trip decides whether a bag is showing —
// and every gesture out of it is a native inventory claim. It is a HUD
// region of its own, above the hands rather than at the item, as tg
// places storage (HUD_GROUP_STORAGE, code/__DEFINES/hud.dm:37;
// screen_start_x/y, code/datums/storage/storage.dm:117-120).
import type { UiNode } from "@lunatic/ui";
import { Slot } from "@lunatic/ui";
import type { GameplayView, InventoryState, ItemView } from "./model";
import { bind, column, inspect, press, row, some, text, type Box } from "./view";
import * as S from "./strings";

let opened: { slot?: string; hand?: number } | undefined;

export const openStorage = (which: { slot?: string; hand?: number }): void => {
  opened = which;
};
export const closeStorage = (): void => {
  opened = undefined;
};

function storedSlot(
  index: number,
  item: ItemView,
  slot: string | undefined,
  hand: number,
): UiNode {
  const id = `stored/${index}/take`;
  return Slot(id, {
    sprite: item.sprite,
    label: S.short(item.name),
    ...(item.fill ? { fill: item.fill } : {}),
    item:
      slot === undefined
        ? `stored-held/${hand}/${index}`
        : `stored-equipment/${slot}/${index}`,
    event: bind(id, (e) => {
      if (e.type === "context")
        return inspect(
          slot === undefined
            ? { StoredHeld: { hand, index } }
            : { StoredEquipment: { slot, index } },
        );
      return slot === undefined
        ? { kind: "take_held", hand, index }
        : { kind: "take", slot, index };
    }),
  });
}

/** The open container where a body has one open, placed by the caller. */
export function storageRegion(
  view: GameplayView,
  place: Box = {},
): UiNode | null {
  const current = view.state.inventory;
  if (!view.body || !current) return null;
  return storagePanel(view, current, place);
}

/** The open container, or nothing where what was open has gone. */
function storagePanel(
  view: GameplayView,
  current: InventoryState,
  place: Box,
): UiNode | null {
  if (!opened) return null;
  const slot = opened.slot;
  const hand = opened.hand ?? 0;
  const roster = view.state.equipment?.slots ?? [];
  const slotIndex = roster.findIndex((rosterSlot) => rosterSlot.id === slot);
  const items =
    slot === undefined
      ? current.held?.[hand]
      : current.equipment?.find((worn) => worn.slot === slotIndex)?.contents;
  if (!items) {
    opened = undefined;
    return null;
  }
  const label =
    slot === undefined ? S.hand(hand) : (roster[slotIndex]?.label ?? S.STORAGE);
  return column(
    "storage",
    [
      row(
        "storage-controls",
        some(
          text("storage-title", S.storageTitle(label), ["caption", "grow"]),
          press("storage-store", S.STORE_HELD, {
            kind: "store",
            dest: slot === undefined ? "OtherHand" : { Equipment: slot },
          }),
          slot === undefined
            ? null
            : press("storage-off", S.TAKE_OFF, { kind: "unequip", slot }),
          press(
            "storage-close",
            S.CLOSE_MARK,
            () => {
              opened = undefined;
              return undefined;
            },
            { variant: "ghost" },
          ),
        ),
        { style: { alignItems: "center", gap: 4 } },
      ),
      row(
        "storage-items",
        items.map((item, index) => storedSlot(index, item, slot, hand)),
        { style: { gap: 4, flexWrap: "wrap" } },
      ),
    ],
    {
      cls: ["hudgroup", ...(place.cls ?? [])],
      ...(place.style ? { style: place.style } : {}),
    },
  );
}
