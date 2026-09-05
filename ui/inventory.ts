import type { GameplayView, InventoryState } from "./model";
import {
  button,
  column,
  icon,
  inspect,
  item as itemTarget,
  node,
  pane,
  row,
  text,
  type Command,
} from "./view";
import type { UiNode } from "@lunatic/ui";
let storage: { slot?: string; hand?: number } | undefined;

export function inventory(view: GameplayView): UiNode | null {
  if (!view.body || !view.state.inventory) return null;
  const current = view.state.inventory;
  const hands: UiNode[] = (current.hands ?? []).map((item, index: number) =>
    column(`hand/${index}`, [
      icon(`hand/${index}/icon`, item?.sprite, item?.name),
      itemTarget(
        button(
          `hand/${index}/pick`,
          `${current.active === index ? "● " : ""}${item?.name ?? `Hand ${index + 1}`}`,
          (e) =>
            e.type === "context"
              ? inspect({ Held: { hand: index } })
              : { kind: "hand", index },
        ),
        `held/${index}`,
      ),
      ...(current.held?.[index]
        ? [
            button(`hand/${index}/open`, "Open", () => {
              storage = { hand: index };
              return undefined;
            }),
          ]
        : []),
    ]),
  );
  const equipment: UiNode[] = (view.state.equipment?.slots ?? []).map(
    (slot, index: number) => {
      const state = (current.equipment ?? []).find(
        (equipment) => equipment.slot === index,
      );
      return row(`equipment/${slot.id}`, [
        icon(`equipment/${slot.id}/icon`, state?.item?.sprite),
        itemTarget(
          button(
            `equipment/${slot.id}/pick`,
            `${slot.label}: ${state?.item?.name ?? "empty"}`,
            (e) => {
              if (e.type === "context")
                return inspect({ Equipment: { slot: slot.id } });
              if (state?.contents) {
                storage = { slot: slot.id };
                return undefined;
              }
              return current.hands?.[current.active]
                ? { kind: "equip" }
                : { kind: "unequip", slot: slot.id };
            },
          ),
          `equipment/${slot.id}`,
        ),
      ]);
    },
  );
  const controls = row("item-controls", [
    button("swap", "Swap", { kind: "swap" }),
    button("drop", "Drop", { kind: "drop" }),
    button("use_self", "Use", { kind: "use_self" }),
    button("use_other", "Use on other hand", { kind: "use_other" }),
    button("equip", "Equip", { kind: "equip" }),
    button("throw_mode", view.state.throwing ? "Throwing" : "Throw", {
      kind: "throw_mode",
    }),
    button("open_build", "Build", { kind: "open_build" }),
  ]);
  const identity = view.state.identity?.name ?? "";
  const children = [
    text("identity", identity),
    row("hands", hands),
    row("equipment", equipment),
    controls,
    targetControls(view),
  ];
  children.push(vitalReadouts(view));
  const contents = storagePanel(view, current);
  if (contents) children.push(contents);
  return pane("inventory", children, {
    position: "absolute",
    right: 14,
    bottom: 0,
    width: 450,
    maxHeight: 380,
  });
}

export function shortcut(id: string, view: GameplayView): Command | undefined {
  if (id.startsWith("target/"))
    return { kind: "target_slot", slot: Number(id.slice(7)) };
  if (id === "quick_store") {
    const slot = view.state.equipment?.slots?.find((s) => s.quick_store);
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
}

function targetControls(view: GameplayView): UiNode {
  const zones = (view.state.targets?.zones ?? []).map((zone, index: number) =>
    button(
      `zone/${zone.id}`,
      `${view.state.target?.zone === index ? "● " : ""}${zone.label}`,
      { kind: "zone", zone: zone.id },
    ),
  );
  const selectedZone = view.state.target
    ? view.state.targets?.zones?.[view.state.target.zone]
    : undefined;
  const figure = view.state.targets?.base
    ? [
        node("panel", "target-figure", {
          style: { position: "relative", width: 32, height: 32, flexShrink: 0 },
          children: [
            {
              ...icon("target-base", view.state.targets.base),
              style: {
                position: "absolute",
                left: 0,
                top: 0,
                width: 32,
                height: 32,
              },
            },
            ...(selectedZone?.sprite
              ? [
                  {
                    ...icon("target-overlay", selectedZone.sprite),
                    style: {
                      position: "absolute" as const,
                      left: 0,
                      top: 0,
                      width: 32,
                      height: 32,
                    },
                  },
                ]
              : []),
          ],
        }),
      ]
    : [];
  return row("zones", [...figure, ...zones]);
}

function vitalReadouts(view: GameplayView): UiNode {
  const samples = view.state.vitals?.values ?? [];
  const readouts = view.state.readouts?.slots ?? [];
  return row(
    "vitals",
    samples.map((sample, index: number) =>
      text(
        `vital/${index}`,
        `${readouts[sample.slot]?.label ?? readouts[index]?.label ?? ""}: ${Number.isFinite(sample.value) ? Math.round(sample.value) : ""}${readouts[sample.slot]?.suffix ?? ""}`,
      ),
    ),
  );
}

function storagePanel(
  view: GameplayView,
  current: InventoryState,
): UiNode | null {
  if (!storage) return null;
  const slot = storage.slot;
  const hand = storage.hand;
  const slotIndex = (view.state.equipment?.slots ?? []).findIndex(
    (rosterSlot) => rosterSlot.id === slot,
  );
  const items =
    slot === undefined
      ? current.held?.[hand!]
      : current.equipment?.find((equipment) => equipment.slot === slotIndex)
          ?.contents;
  if (!items) {
    storage = undefined;
    return null;
  }
  return column("storage", [
    row("storage-controls", [
      button("storage-close", "Close container", () => {
        storage = undefined;
        return undefined;
      }),
      button("storage-store", "Store held item", {
        kind: "store",
        dest: slot === undefined ? "OtherHand" : { Equipment: slot },
      }),
      ...(slot === undefined
        ? []
        : [button("storage-off", "Take off", { kind: "unequip", slot })]),
    ]),
    ...items.map((item, index: number) =>
      row(`stored/${index}`, [
        icon(`stored/${index}/icon`, item.sprite),
        itemTarget(
          button(`stored/${index}/take`, item.name, (e) => {
            if (e.type === "context")
              return inspect(
                slot === undefined
                  ? { StoredHeld: { hand: hand!, index } }
                  : { StoredEquipment: { slot, index } },
              );
            return slot === undefined
              ? { kind: "take_held", hand: hand!, index }
              : { kind: "take", slot, index };
          }),
          slot === undefined
            ? `stored-held/${hand}/${index}`
            : `stored-equipment/${slot}/${index}`,
        ),
      ]),
    ),
  ]);
}
