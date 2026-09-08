// The two surfaces that follow the cursor: the card reading what is
// under it, and the menu over what stands on a tile. Their own package,
// in the `overlay` slot, so a hover never re-renders the HUD — the slot
// claims `state.hover` and `state.context` and the host wakes this guest
// for nothing else (docs/pack-ui/sdk.md, "Slots").
import type { GuestUi, UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import type { GameplayView } from "../model";
import { begin, event, icon, press, row, some, text } from "../view";
import { hintText } from "../labels";
import { gesture, modifierCount, order } from "../gesture";
import * as S from "../strings";

/** What the cursor is over, with the verbs it answers to. */
function hoverCard(hover: NonNullable<GameplayView["state"]["hover"]>): UiNode {
  const rows = [...hover.hints];
  if (hover.primary_fallback === undefined && hover.appearance
      && !rows.some((hint) => hint.gesture === "primary"))
    rows.unshift({ gesture: "primary", label: S.tfs("ui.look.interact") });
  if (hover.primary_fallback && !rows.some((hint) => hint.gesture === "primary"))
    rows.unshift({ gesture: "primary", label: S.tfs(hover.primary_fallback === "store"
      ? "ui.look.store_held" : "ui.look.use_held") });
  // Examine is Shift+LMB and takes the place its own rank names, between
  // the bare group and the shift group. The rows arrive ranked, so this
  // is one insertion and never a sort.
  const examine = { gesture: "shift_primary", label: S.tfs("ui.look.examine") };
  const at = rows.findIndex((hint) => order(hint.gesture) > order(examine.gesture));
  rows.splice(at < 0 ? rows.length : at, 0, examine);
  const implement = hover.implement;
  const usesImplement = (name: string) => name !== examine.gesture
    && !!implement?.sprite && implement.gestures.includes(name);
  // Every description shares one rail, including rows without an item.
  // The item adds 32px, an 8px plus and two 4px gaps to its input glyphs.
  const wide = rows.some((hint) => modifierCount(hint.gesture) > 1);
  const width = Math.max(58, ...rows.map((hint) => {
    const modifiers = modifierCount(hint.gesture);
    const keys = modifiers > 1 ? 84 : modifiers === 1 ? 58 : hint.gesture === "self" ? 34 : 14;
    return keys + (usesImplement(hint.gesture) ? 48 : 0);
  }));
  const rail = { gridTemplateColumns: [width, "1fr"] };
  // The header's image and every hint's key cell are both the first
  // child of a full-width row inside one padding, so their left edges
  // are the same edge: the card reads as one column, not two.
  return {
    ...Pane("hover", [
      row("hover/title", [
        {
          id: "hover/preview",
          type: "image",
          // A slot's item comes with a sprite and no composed look, so
          // it is drawn the way every other icon is: one named asset.
          ...(hover.appearance
            ? { appearance: hover.appearance }
            : hover.sprite
              ? { asset: hover.sprite }
              : {}),
          class: ["hover-preview"],
        },
        text("hover/name", hover.name, ["hover-title"]),
      ], { cls: ["hover-head"] }),
      ...rows.map((hint, index) => {
        const keys = gesture(`hover/key/${index}`, hint.gesture, wide);
        if (usesImplement(hint.gesture) && implement) {
          keys.children = [...(keys.children ?? []),
            text(`hover/plus/${index}`, "+", ["hover-combination-plus"]),
            icon(`hover/implement/${index}`, implement.sprite, implement.name, ["hover-implement"])!,
          ];
        }
        return row(`hover/hint/${index}`, [
          keys,
          text(`hover/label/${index}`, hintText(hint.label), ["hover-description"]),
        ], { cls: ["hover-row"], style: rail });
      }),
    ], { cls: ["hover-card"] }),
    anchor: "@cursor",
  };
}

/** Everything standing where the right-click landed. */
function contextMenu(
  targets: NonNullable<GameplayView["state"]["context"]>,
): UiNode {
  return {
    // The menu opens where the right-click landed. `@context` is the
    // host's own point for that click: the package names it and is never
    // told a coordinate, and the host puts the menu's top-left there,
    // keeps its presses live and clamps it into the slot. The point
    // stands only while this projection does, so the close press still
    // ends the menu (docs/pack-ui/sdk.md, "Spatial overlays").
    anchor: "@context",
    ...Pane("context", [
      row("context-title", [
        text("context-heading", S.TILE_TITLE, ["titlebar-title", "grow"]),
        press("context-close", S.CLOSE_MARK, { kind: "dismiss", panel: "context" }, {
          variant: "ghost",
        }),
      ], { cls: ["titlebar"] }),
      ...targets.map((target, index) => row(
        `context/${index}`,
        some(
          icon(`context/${index}/icon`, target?.sprite),
          press(
            `context/${index}/use`,
            target?.name ?? "",
            { kind: "context", target: target?.target ?? null },
            { variant: "ghost", cls: ["fname"] },
          ),
        ),
        { cls: ["filerow"] },
      )),
    ], { style: { width: 300, maxHeight: "60%" } }),
  };
}

const ui: GuestUi = {
  render(raw) {
    const view = raw as unknown as GameplayView;
    begin();
    const state = view.state ?? {};
    return Pane("overlay", some(
      state.hover ? hoverCard(state.hover) : null,
      state.context ? contextMenu(state.context) : null,
    ), { cls: ["overlay"] });
  },
  onEvent: event,
};
export default ui;
