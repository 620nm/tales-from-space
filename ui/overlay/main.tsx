// The two surfaces that follow the cursor: the card reading what is
// under it, and the menu over what stands on a tile. Their own package,
// in the `overlay` slot, so a hover never re-renders the HUD — the slot
// claims `state.hover` and `state.context` and the host wakes this guest
// for nothing else (docs/pack-ui/sdk.md, "Slots").
import type { GuestUi, UiNode } from "@lunatic/ui";
import { Pane, Stack, t } from "@lunatic/ui";
import type { ActionLabel, GameplayView, HoverAction } from "../model";
import { begin, event, icon, panel, press, row, screen, some, text } from "../view";
import { gesture, order } from "../gesture";
import * as S from "../strings";
import { actionStyles } from "./actions";

/** What the cursor is over, with the verbs it answers to. */
function actionText(label: ActionLabel): string {
  if (label.text !== undefined && label.text !== null) return label.text;
  const args = { ...label.args };
  for (const key of label.arg_keys ?? []) if (args[key] !== undefined) args[key] = t(args[key]!);
  return t(label.key, args);
}

function hoverCard(hover: NonNullable<GameplayView["state"]["hover"]>,
  bindings?: Record<string, readonly string[]>): UiNode {
  const rows: HoverAction[] = [...(hover.actions ?? [])];
  const rank = (hint: HoverAction) => hint.group === "suggestion" ? 2 : hint.available ? 0 : 1;
  rows.sort((a, b) => rank(a) - rank(b) || (a.order ?? order(a.gesture)) - (b.order ?? order(b.gesture)));
  const cells: UiNode[] = [];
  let previousGroup = "";
  let previousPresentation = "";
  for (const hint of rows) {
    if (hint.group === "suggestion" && previousGroup !== "suggestion")
      cells.push(text("hover/group/suggestion", S.tfs("ui.look.other"), ["hover-group"],
        { gridColumn: { start: 1, span: 2 } }));
    previousGroup = hint.group;
    if (hint.presentation_group && hint.presentation_group !== previousPresentation)
      cells.push(text(`hover/group/${hint.id}`, t(hint.presentation_group), ["hover-group"],
        { gridColumn: { start: 1, span: 2 } }));
    previousPresentation = hint.presentation_group ?? "";
    const keyId = `hover/key/${hint.id}`;
    const keys = gesture(keyId, hint.gesture, false, bindings);
    if (hint.implement?.sprite) keys.children = [...(keys.children ?? []),
      text(`${keyId}/plus`, "+", ["hover-combination-plus"]),
      icon(`${keyId}/implement`, hint.implement.sprite, actionText(hint.implement.name), ["hover-implement"])!,
    ];
    if (!hint.available) keys.class = [...(keys.class ?? []), "hover-unavailable"];
    const style = hint.style ? actionStyles[hint.style] : undefined;
    const cls = ["hover-description", ...(style ? [style] : []),
      ...(hint.available ? [] : ["hover-unavailable"])];
    cells.push(keys, panel(`hover/hint/${hint.id}`, [
      text(`hover/label/${hint.id}`, actionText(hint.label), cls),
      ...(hint.requirements ?? []).map((requirement, index) => text(`hover/requirement/${hint.id}/${index}`,
        S.tfs(requirement.count > 1 ? "ui.look.requires_quantity" : "ui.look.requires", {
          item: actionText(requirement.label), quantity: String(requirement.count),
        }), ["hover-requirement"])),
      ...(hint.unavailable_reason
        ? [text(`hover/reason/${hint.id}`, actionText(hint.unavailable_reason), ["hover-requirement"])] : []),
    ], { cls: ["hover-row"] }));
  }
  // The header's image and every hint's key cell are both the first
  // child of a full-width row inside one padding, so their left edges
  // are the same edge: the card reads as one column, not two.
  return {
    ...Pane("hover", [
      row("hover/title", [
        {
          id: "hover/preview",
          type: "image",
          text: hover.name_label ? actionText(hover.name_label) : hover.name,
          // A slot's item comes with a sprite and no composed look, so
          // it is drawn the way every other icon is: one named asset.
          ...(hover.appearance
            ? { appearance: hover.appearance }
            : hover.sprite
              ? { asset: hover.sprite }
              : {}),
          class: ["hover-preview"],
        },
        text("hover/name", hover.name_label ? actionText(hover.name_label) : hover.name, ["hover-title"]),
      ], { cls: ["hover-head"] }),
      panel("hover/actions", cells, { cls: ["hover-actions"] }),
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
    // A screen as tall as its rows, up to the cap, and then scrolling.
    ...screen("context", { toolbar: [
        text("context-heading", S.TILE_TITLE, ["titlebar-title", "grow"]),
        press("context-close", S.CLOSE_MARK, { kind: "dismiss", panel: "context" }, {
          variant: "ghost",
        }),
      ], body: targets.map((target, index) => Stack(
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
        { gap: 4, align: "center" },
      )) }, { cls: ["pane"], fit: true, style: { width: 300, maxHeight: "60%" } }),
  };
}

const ui: GuestUi = {
  render(raw) {
    const view = raw as unknown as GameplayView;
    begin();
    const state = view.state ?? {};
    return Pane("overlay", some(
      state.hover ? hoverCard(state.hover, state.effectiveBindings) : null,
      state.context ? contextMenu(state.context) : null,
    ), { cls: ["overlay"] });
  },
  onEvent: event,
};
export default ui;
