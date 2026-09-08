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
  // Out in the world primary is always offered: a thing with no declared
  // verbs is still something a hand can be put on. A thing already in a
  // slot is not — the server drops that row, and a bare click there is
  // the hand itself, not a reach for the item.
  const slot = !hover.appearance;
  const rows = slot || hover.hints.some((hint) => hint.gesture === "primary")
    ? [...hover.hints]
    : [{ gesture: "primary", label: S.tfs("ui.look.interact") }, ...hover.hints];
  // Examine is Shift+LMB and takes the place its own rank names, between
  // the bare group and the shift group. The rows arrive ranked, so this
  // is one insertion and never a sort.
  const examine = { gesture: "shift_primary", label: S.tfs("ui.look.examine") };
  const at = rows.findIndex((hint) => order(hint.gesture) > order(examine.gesture));
  rows.splice(at < 0 ? rows.length : at, 0, examine);
  // One rail for the card, sized off its widest row: a two-key gesture
  // needs 84px for its pills and mouse, everything else fits 58. Every
  // row takes that one width, so widening never staggers the rail.
  const wide = rows.some((hint) => modifierCount(hint.gesture) > 1);
  const rail = { gridTemplateColumns: [wide ? 84 : 58, "1fr"] };
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
      ...rows.map((hint, index) => row(`hover/hint/${index}`, [
        gesture(`hover/key/${index}`, hint.gesture, wide),
        text(`hover/label/${index}`, hintText(hint.label), ["hover-description"]),
      ], { cls: ["hover-row"], style: rail })),
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
