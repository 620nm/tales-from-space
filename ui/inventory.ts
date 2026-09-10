// Hand, carry and equipment groups share the HUD control row. Individual
// equipment cells retain their anatomical positions and native item claims.
import type { Json, UiNode } from "@lunatic/ui";
import { Pane, Stack } from "@lunatic/ui";
import { labelText } from "./labels";
import { hudSlot } from "./slots";
import type { GameplayView, InventoryState } from "./model";
import { openStorage } from "./inventory-storage";
import { inventoryEvent } from "./inventory-event";
import { bind, column, panel, press, row, some, text, type Command } from "./view";
import * as S from "./strings";

export function inventory(view: GameplayView): UiNode | null {
  if (!view.body || !view.state.inventory) return null;
  const current = view.state.inventory;
  return Pane(
    "inventory",
    some(
      Stack("hands", handSquares(current), { gap: 4 }),
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
      style: { minWidth: 148, width: 148 },
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
      event: bind(id, (e) => inventoryEvent(e, { Held: { hand: index } }, item,
        current, () => ({ kind: "hand", index }), current.active === index)),
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
    ? Stack("hands-open", rows, {
        cls: ["hudgroup"], gap: 4,
        style: { minHeight: 28 },
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
      event: bind(id, (e) => inventoryEvent(e, { Equipment: { slot: slot.id } },
        worn?.item, current, (): Command | undefined => {
        if (worn?.contents) {
          openStorage({ slot: slot.id });
          return undefined;
        }
        return current.hands?.[current.active]
          ? { kind: "equip" }
          : { kind: "unequip", slot: slot.id };
      })),
    }, slot.id);
    const position = anatomy[slot.id] ?? [index % 3, Math.floor(index / 3) + 3];
    return [{ ...square, ...(!carry ? { style: { position: "absolute" as const, left: position[0] * 44, top: position[1] * 44 } } : {}) }];
  });
  if (carry) return Stack("carry", ["back", "belt"].flatMap((slot) => squares.filter((square) => square.id === `equipment/${slot}/pick/box`)), {
    dir: "column", gap: 4, cls: ["hudgroup"], style: { width: 40, minWidth: 40 },
  });
  return column(
    "worn-group",
    [...squares, wornToggle()],
    { cls: ["hudgroup"], style: { position: "relative", width: 128, minWidth: 128, height: 128 } },
  );
}

/** The one square in the grid that never moves and never holds an item. */
function wornToggle(): UiNode {
  return panel("worn-toggle/box", some(
    text("worn-toggle/glyph", S.MARK_WORN, ["worn-glyph"]),
    text("worn-toggle/cap", S.WORN, ["worn-cap"]),
    press("worn-toggle", "", () => { wornVisible = !wornVisible; return undefined; }, {
      // The lit edge belongs to the box, which wears `worn-on`; the press
      // is the square over it and draws nothing.
      cls: ["hud-hit"],
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

/** The body's own readouts sit beside the target figure. */
export function targetMeta(view: GameplayView): UiNode | null {
  if (!view.body) return null;
  const lines = readings(view);
  return Stack("target-meta", some(
    lines.length
      ? column("target-status", lines.map((line, index) => Stack(line.key, some(
          index === 0 ? text("target-status/dot", S.MARK_STATUS, ["status-dot"]) : null,
          text(`${line.key}/key`, line.label, ["status-key"]),
          text(`${line.key}/value`, line.value),
        ), { gap: 4, align: "center" })), { cls: ["target-status"] })
      : null,
  ), { dir: "column", gap: 7, align: "center", cls: ["hudgroup"] });
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
