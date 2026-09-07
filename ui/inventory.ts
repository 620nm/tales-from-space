// Independent hand, carry and anatomical equipment regions. Every press
// is a native inventory claim the server revalidates. Nothing in the
// cluster moves as items, trays or the worn grid come and go: the rows
// that appear are absolute, so the hands stay under the cursor.
import type { Json, UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import { labelText } from "./labels";
import { hudSlot } from "./slots";
import type { GameplayView, InventoryState } from "./model";
import { openStorage } from "./inventory-storage";
import { fromEvent } from "./gesture";
import { bind, column, inspect, panel, press, row, some, text, type Command } from "./view";
import * as S from "./strings";

export function inventory(view: GameplayView): UiNode | null {
  if (!view.body || !view.state.inventory) return null;
  const current = view.state.inventory;
  return Pane(
    "inventory",
    some(
      row("hands", handSquares(current), { style: { gap: 4 } }),
      row("hand-controls", [
        glyphControl("swap", S.MARK_SWAP, S.SWAP, { kind: "swap" }),
        glyphControl("drop", S.MARK_DROP, S.DROP, { kind: "drop" }),
        glyphControl("throw_mode", S.MARK_THROW,
          view.state.throwing ? S.THROWING : S.THROW, { kind: "throw_mode" },
          view.state.throwing === true),
      ], { cls: ["hand-actions"] }),
      openers(current),
    ),
    {
      cls: ["hudgroup", "hand-cluster"],
      style: { position: "absolute", left: 0, marginLeft: -62, bottom: 17, minWidth: 124, width: 124 },
    },
  );
}

/** A glyph over its word, with the press stretched across both. */
function glyphControl(id: string, glyph: unknown, caption: unknown, action: Command, on = false): UiNode {
  return panel(`${id}/box`, some(
    text(`${id}/glyph`, glyph, ["hud-glyph"]),
    text(`${id}/cap`, caption, ["hud-cap"]),
    // The press is a bare hit box over a glyph and a word, so the word
    // is what it is read out as.
    press(id, "", action, { cls: ["hud-hit"], label: labelText(caption as Json) }),
  ), { cls: on ? ["hand-action", "hand-action-on"] : ["hand-action"] });
}

function handSquares(current: InventoryState): UiNode[] {
  const hands = current.hands ?? [];
  return hands.map((item, index) => {
    const id = `hand/${index}/pick`;
    return hudSlot(id, {
      ...(item?.sprite ? { sprite: item.sprite } : {}),
      label: S.hand(index),
      active: current.active === index,
      empty: !item,
      ...(item?.fill ? { fill: item.fill } : {}),
      item: `held/${index}`,
      event: bind(id, (e) => {
        const target = { Held: { hand: index } };
        // The press names a gesture; the item's mask says whether it
        // declared that one. The reserved bits are never in a mask, so
        // Shift still examines and a bare click still takes the hand.
        const shape = fromEvent(e);
        const mask = item?.gestures ?? 0;
        if (shape && !e.meta && ((mask >>> shape.rank) & 1) === 1)
          return { kind: "use_item", target, gesture: shape.id };
        return e.type === "context" || (e.type === "activate" && e.shift)
          ? inspect(target)
          : { kind: "hand", index };
      }),
    }, "hand", "hand-slot");
  });
}

/** The presses that open a held container, floated clear of the cells. */
function openers(current: InventoryState): UiNode | null {
  const rows = (current.hands ?? []).flatMap((_item, index) =>
    current.held?.[index]
      ? [press(`hand/${index}/open`, S.OPEN, () => { openStorage({ hand: index }); return undefined; },
          { variant: "ghost" })]
      : [],
  );
  return rows.length
    ? row("hands-open", rows, {
        cls: ["hudgroup"],
        style: { position: "absolute", left: 0, bottom: 89, gap: 4 },
      })
    : null;
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
      label: S.short(slot.label),
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
    [...squares, wornToggle()],
    { cls: ["hudgroup"], style: { position: "absolute", right: 124, bottom: 40, width: 128, minWidth: 128, height: 128 } },
  );
}

/** The one square in the grid that never moves and never holds an item. */
function wornToggle(): UiNode {
  return panel("worn-toggle/box", some(
    text("worn-toggle/glyph", S.MARK_WORN, ["worn-glyph"]),
    text("worn-toggle/cap", S.WORN, ["worn-cap"]),
    press("worn-toggle", "", () => { wornVisible = !wornVisible; return undefined; }, {
      cls: wornVisible
        ? ["hud-hit", "worn-hit", "worn-hit-on"]
        : ["hud-hit", "worn-hit"],
      label: S.WORN,
    }),
  ), {
    cls: wornVisible ? ["worn-toggle", "worn-on"] : ["worn-toggle"],
    style: { position: "absolute", left: 0, bottom: 0 },
  });
}

interface Reading { key: string; label: string; value: string }

/** The readouts this body is sending, in the roster's own words. */
function readings(view: GameplayView): Reading[] {
  const samples = view.state.vitals?.values ?? [];
  const roster = view.state.readouts?.slots ?? [];
  return samples.flatMap((sample, index) => {
    const slot = roster[sample.slot] ?? roster[index];
    if (!slot) return [];
    const value = sample.value;
    return [{
      key: `vital/${index}`,
      label: slot.label,
      value: `${Number.isFinite(value) ? Math.round(value as number) : S.NO_READING}${slot.suffix ?? ""}`,
    }];
  });
}

/**
 * What stands beside the target figure: a slot held empty for the intent
 * pill this HUD has yet to grow, and the body's own readouts, one per row.
 */
export function targetMeta(view: GameplayView): UiNode | null {
  if (!view.body) return null;
  const lines = readings(view);
  return column("target-meta", some(
    panel("target-reserve", [], { cls: ["target-reserve"] }),
    lines.length
      ? column("target-status", lines.map((line, index) => row(line.key, some(
          index === 0 ? text("target-status/dot", S.MARK_STATUS, ["status-dot"]) : null,
          text(`${line.key}/key`, line.label, ["status-key"]),
          text(`${line.key}/value`, line.value),
        ), { cls: ["status-row"] })), { cls: ["target-status"] })
      : null,
  ), { cls: ["hudgroup", "target-meta"] });
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
