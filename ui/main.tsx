// Two coordinated regions keep communication and body controls clear of
// each other; host windows contain expandable documents and storage.
import type { GuestUi, UiNode } from "@lunatic/ui";
import { Pane, Stack } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { begin, column, event, panel, row, some, text } from "./view";
import { crewPanels } from "./lobby";
import { chatPanel } from "./chat";
import { inspectionPanels } from "./inspect";
import { worldOverlays } from "./world-overlays";
import { inventory, shortcut, targetMeta, wornGroup } from "./inventory";
import { bodyTarget } from "./doll";
import { storageRegion } from "./inventory-storage";
import { pollContinuation } from "./files";
import { documents } from "./documents";
import { actionGroups } from "./actions";

/** Where this body is, and who it is: two spans over the station, no
 *  pane behind them. A viewer whose projection names no place gets the
 *  name alone rather than a dot with nothing after it. */
function statusLine(view: GameplayView): UiNode {
  const place = (view.state as { location?: { name?: string } }).location?.name;
  return row("status", some(
    place
      ? Stack("status-place", [
          panel("status-dot", [], { cls: ["statusdot"] }),
          text("status-place/name", place),
        ], { cls: ["hudgroup"], gap: 8, align: "center" })
      : null,
    text("identity", view.state.identity?.name ?? "", ["statusname"]),
  ), { cls: ["hudgroup", "statusline"], style: { position: "absolute", right: 14, top: 14 } });
}

const ui: GuestUi = {
  onView(raw) {
    const view = raw as unknown as GameplayView;
    return { action: pollContinuation(Object.values(view.documents ?? {})) };
  },
  render(raw) {
    const view = raw as unknown as GameplayView;
    begin();
    const children: UiNode[] = [];
    // The board and the condition card are the only nodes in flow, so
    // the root's own centring puts them where a modal belongs.
    children.push(...crewPanels(view));
    children.push(column("hud-comms", [
      ...inspectionPanels(view), ...chatPanel(view),
    ], { cls: ["hudgroup", "hud-comms"], style: {
      position: "absolute", left: 12, top: 18, bottom: 12, width: "32%", minWidth: 320, maxWidth: 420,
    } }));
    children.push(column("hud-origin", [
      ...actionGroups(view),
      row("hud-controls", some(
        wornGroup(view), wornGroup(view, true), inventory(view),
        Stack("target-block", some(bodyTarget(view), targetMeta(view)), {
          cls: ["hudgroup"], gap: 8, align: "center",
        }),
      ), { cls: ["hudgroup", "hud-controls"] }),
    ], { cls: ["hudgroup", "hud-controls-region"], style: {
      position: "absolute", left: "35%", right: 12, bottom: 12,
    } }));
    children.push(...some(storageRegion(view), view.body ? statusLine(view) : null));
    children.push(...documents(view));
    children.push(...worldOverlays(view));
    return Pane("gameplay", children, { cls: ["hud", "centered"] });
  },
  onEvent(e, view) {
    const command = shortcut(e.id, view as unknown as GameplayView);
    if (command) return { action: command };
    return event(e);
  },
};
export default ui;
