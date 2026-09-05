// The tray: the hands, the worn roster, the target figure and the
// verbs, over the station's bottom-right corner. Every square is one
// slot; every press is a native inventory claim the server revalidates.
import type { UiNode } from "@lunatic/ui";
import { Pane, Slot } from "@lunatic/ui";
import type { GameplayView, InventoryState } from "./model";
import { bodyTarget } from "./doll";
import { openStorage, storagePanel } from "./inventory-storage";
import { bind, column, inspect, press, row, some, text, type Command } from "./view";
import * as S from "./strings";

export function inventory(view: GameplayView): UiNode | null {
  if (!view.body || !view.state.inventory) return null;
  const current = view.state.inventory;
  const contents = storagePanel(view, current);
  return Pane(
    "inventory",
    some(
      row(
        "tray-head",
        some(
          text("identity", view.state.identity?.name ?? "", ["chipval", "grow"]),
          vitals(view),
        ),
        { style: { alignItems: "center", gap: 8 } },
      ),
      contents,
      row(
        "tray",
        some(bodyTarget(view), handsGroup(current), wornGroup(view, current)),
        { cls: ["tray"], style: { flexWrap: "wrap" } },
      ),
      verbs(view),
    ),
    {
      style: {
        position: "absolute",
        right: 14,
        bottom: 12,
        width: 470,
        maxWidth: "100%",
        maxHeight: "72%",
      },
    },
  );
}

function handsGroup(current: InventoryState): UiNode {
  const hands = current.hands ?? [];
  const squares = hands.map((item, index) => {
    const id = `hand/${index}/pick`;
    return Slot(id, {
      ...(item?.sprite ? { sprite: item.sprite } : {}),
      label: item?.name ?? S.hand(index),
      active: current.active === index,
      empty: !item,
      ...(item?.fill ? { fill: item.fill } : {}),
      item: `held/${index}`,
      event: bind(id, (e) =>
        e.type === "context"
          ? inspect({ Held: { hand: index } })
          : { kind: "hand", index },
      ),
    });
  });
  const openers = hands.flatMap((_item, index) =>
    current.held?.[index]
      ? [
          press(
            `hand/${index}/open`,
            S.OPEN,
            () => {
              openStorage({ hand: index });
              return undefined;
            },
            { variant: "ghost" },
          ),
        ]
      : [],
  );
  return column(
    "hands-group",
    some(
      text("hands-caption", S.HANDS, ["caption"]),
      row("hands", squares, { style: { gap: 4 } }),
      openers.length
        ? row("hands-open", openers, { style: { gap: 4 } })
        : null,
    ),
    { cls: ["trayset"] },
  );
}

function wornGroup(view: GameplayView, current: InventoryState): UiNode | null {
  const roster = view.state.equipment?.slots ?? [];
  if (!roster.length) return null;
  const squares = roster.map((slot, index) => {
    const worn = (current.equipment ?? []).find((row) => row.slot === index);
    const id = `equipment/${slot.id}/pick`;
    return Slot(id, {
      ...(worn?.item?.sprite ? { sprite: worn.item.sprite } : {}),
      label: worn?.item?.name ?? slot.label,
      empty: !worn?.item,
      ...(worn?.item?.fill ? { fill: worn.item.fill } : {}),
      item: `equipment/${slot.id}`,
      event: bind(id, (e) => {
        if (e.type === "context") return inspect({ Equipment: { slot: slot.id } });
        if (worn?.contents) {
          openStorage({ slot: slot.id });
          return undefined;
        }
        return current.hands?.[current.active]
          ? { kind: "equip" }
          : { kind: "unequip", slot: slot.id };
      }),
    });
  });
  return column(
    "worn-group",
    [
      text("worn-caption", S.WORN, ["caption"]),
      row("equipment", squares, { style: { gap: 4, flexWrap: "wrap" } }),
    ],
    { cls: ["trayset"] },
  );
}

function verbs(view: GameplayView): UiNode {
  return row(
    "item-controls",
    [
      press("swap", S.SWAP, { kind: "swap" }),
      press("drop", S.DROP, { kind: "drop" }),
      press("use_self", S.USE, { kind: "use_self" }),
      press("use_other", S.USE_OTHER, { kind: "use_other" }),
      press("equip", S.EQUIP, { kind: "equip" }),
      press(
        "throw_mode",
        view.state.throwing ? S.THROWING : S.THROW,
        { kind: "throw_mode" },
        { variant: view.state.throwing ? "selected" : "default" },
      ),
      press("open_build", S.BUILD, { kind: "open_build" }, {
        variant: "primary",
      }),
    ],
    { style: { gap: 4, flexWrap: "wrap" } },
  );
}

function vitals(view: GameplayView): UiNode | null {
  const samples = view.state.vitals?.values ?? [];
  const roster = view.state.readouts?.slots ?? [];
  const chips = samples.flatMap((sample, index) => {
    const slot = roster[sample.slot] ?? roster[index];
    if (!slot) return [];
    const value = sample.value;
    return [
      row(
        `vital/${index}`,
        [
          text(`vital/${index}/key`, slot.label, ["chipkey"]),
          text(
            `vital/${index}/value`,
            `${Number.isFinite(value) ? Math.round(value as number) : "—"}${slot.suffix ?? ""}`,
            ["chipval"],
          ),
        ],
        { cls: ["chip"] },
      ),
    ];
  });
  return chips.length
    ? row("vitals", chips, { style: { gap: 4, flexWrap: "wrap" } })
    : null;
}

export function shortcut(id: string, view: GameplayView): Command | undefined {
  if (id.startsWith("target/"))
    return { kind: "target_slot", slot: Number(id.slice(7)) };
  if (id === "quick_store") {
    const slot = view.state.equipment?.slots?.find((row) => row.quick_store);
    return slot ? { kind: "store", dest: { Equipment: slot.id } } : undefined;
  }
  if (
    [
      "swap",
      "drop",
      "use_self",
      "use_other",
      "stop_pull",
      "equip",
      "throw_mode",
      "open_build",
    ].includes(id)
  )
    return { kind: id };
  return undefined;
}
