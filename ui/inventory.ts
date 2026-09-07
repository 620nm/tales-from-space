// Independent hand, carry and anatomical equipment regions. Every press
// is a native inventory claim the server revalidates.
import type { UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import { hudSlot } from "./slots";
import type { GameplayView, InventoryState } from "./model";
import { openStorage } from "./inventory-storage";
import { bind, column, inspect, press, row, some, text, type Command } from "./view";
import * as S from "./strings";

export function inventory(view: GameplayView): UiNode | null {
  if (!view.body || !view.state.inventory) return null;
  const current = view.state.inventory;
  return Pane(
    "inventory",
    some(
      handsGroup(current),
      row("hand-controls", [
        press("swap", S.SWAP, { kind: "swap" }),
        press("drop", S.DROP, { kind: "drop" }),
        press("use_self", S.USE, { kind: "use_self" }),
      ], { cls: ["hand-controls"], style: { gap: 3 } }),
    ),
    {
      cls: ["hudgroup", "hand-cluster"],
      style: { position: "absolute", left: 0, marginLeft: -62, bottom: 17, minWidth: 124, width: 124 },
    },
  );
}

function handsGroup(current: InventoryState): UiNode {
  const hands = current.hands ?? [];
  const squares = hands.map((item, index) => {
    const id = `hand/${index}/pick`;
    return hudSlot(id, {
      ...(item?.sprite ? { sprite: item.sprite } : {}),
      label: S.short(item?.name ?? S.hand(index)),
      active: current.active === index,
      empty: !item,
      ...(item?.fill ? { fill: item.fill } : {}),
      item: `held/${index}`,
      event: bind(id, (e) => {
        const mask = item?.gestures ?? 0;
        const gesture = e.type === "context" && !e.alt && !e.ctrl && !e.shift
          ? ((mask & 1) ? "secondary" : undefined)
          : e.type === "activate" && e.ctrl && e.shift && !e.alt
            ? ((mask & 4) ? "ctrl_shift" : undefined)
            : e.type === "activate" && e.alt && !e.ctrl && !e.shift
              ? ((mask & 2) ? "alt" : undefined) : undefined;
        if (gesture && !e.meta) return { kind: "use_item", target: { Held: { hand: index } }, gesture };
        return e.type === "context"
          ? inspect({ Held: { hand: index } })
          : { kind: "hand", index };
      }),
    }, "hand", "hand-slot");
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

let wornVisible = true;
const anatomy: Record<string, [number, number]> = {
  ears: [0, 0], head: [1, 0], lamp: [1, 0], mask: [2, 0],
  gloves: [0, 1], uniform: [1, 1], suit: [2, 1],
  shoes: [1, 2], id: [2, 2],
};

export function wornGroup(view: GameplayView, carry = false): UiNode | null {
  const current = view.state.inventory;
  if (!view.body || !current) return null;
  const roster = view.state.equipment?.slots ?? [];
  if (!roster.length) return null;
  const squares = roster.flatMap((slot, index) => {
    if ((slot.id === "back" || slot.id === "belt") !== carry) return [];
    if (!carry && !wornVisible) return [];
    const worn = (current.equipment ?? []).find((row) => row.slot === index);
    const id = `equipment/${slot.id}/pick`;
    const square = hudSlot(id, {
      ...(worn?.item?.sprite ? { sprite: worn.item.sprite } : {}),
      label: S.short(worn?.item?.name ?? slot.label),
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
    }, slot.id);
    const position = anatomy[slot.id] ?? [index % 3, Math.floor(index / 3) + 3];
    return [{ ...square, ...(!carry ? { style: { position: "absolute" as const, left: position[0] * 44, top: position[1] * 44 } } : {}) }];
  });
  if (carry) return column("carry", ["back", "belt"].flatMap((slot) => squares.filter((square) => square.id === `equipment/${slot}/pick/box`)), {
    cls: ["hudgroup"], style: { position: "absolute", right: 70, width: 40, minWidth: 40, bottom: 40, gap: 4 },
  });
  return column(
    "worn-group",
    [
      ...squares,
      press("worn-toggle", S.WORN, () => { wornVisible = !wornVisible; return undefined; }, {
        cls: ["worn-toggle"], variant: wornVisible ? "selected" : "default",
        style: { position: "absolute", left: 0, bottom: 0, width: 40, minWidth: 40, height: 40 },
      }),
    ],
    { cls: ["hudgroup"], style: { position: "absolute", right: 124, bottom: 40, width: 128, minWidth: 128, height: 128 } },
  );
}

export function vitals(view: GameplayView): UiNode | null {
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
