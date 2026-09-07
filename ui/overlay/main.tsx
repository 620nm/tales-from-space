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
import { gesture } from "../gesture";
import * as S from "../strings";

/** What the cursor is over, with the verbs it answers to. */
function hoverCard(hover: NonNullable<GameplayView["state"]["hover"]>): UiNode {
  // Primary is always offered: a thing with no declared verbs is still
  // something a hand can be put on.
  const hints = hover.hints.some((hint) => hint.gesture === "primary")
    ? hover.hints
    : [{ gesture: "primary", label: S.tfs("ui.look.interact") }, ...hover.hints];
  // The header's image and every hint's key cell are both the first
  // child of a full-width row inside one padding, so their left edges
  // are the same edge: the card reads as one column, not two.
  return {
    ...Pane("hover", [
      row("hover/title", [
        { id: "hover/preview", type: "image", appearance: hover.appearance, class: ["hover-preview"] },
        text("hover/name", hover.name, ["hover-title"]),
      ], { cls: ["hover-head"] }),
      ...[...hints, { gesture: "examine", label: S.tfs("ui.look.examine") }]
        .map((hint, index) => row(`hover/hint/${index}`, [
          gesture(`hover/key/${index}`, hint.gesture),
          text(`hover/label/${index}`, hintText(hint.label), ["hover-description"]),
        ], { cls: ["hover-row"] })),
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
