// The whole gameplay surface: a transparent sheet the station shows
// through, with the crew board in the middle of it and every other
// panel pinned to an edge.
import type { GuestUi, UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { begin, column, event, some, text } from "./view";
import { crewPanels } from "./lobby";
import { chatPanel } from "./chat";
import { inspectionPanels } from "./inspect";
import { worldOverlays } from "./world-overlays";
import { inventory, shortcut, vitals, wornGroup } from "./inventory";
import { bodyTarget } from "./doll";
import { storageRegion } from "./inventory-storage";
import { documents } from "./documents";
import { actionGroups } from "./actions";

const ui: GuestUi = {
  render(raw) {
    const view = raw as unknown as GameplayView;
    begin();
    const children: UiNode[] = [];
    // The board and the condition card are the only nodes in flow, so
    // the root's own centring puts them where a modal belongs.
    children.push(...crewPanels(view));
    children.push(...some(
      column("hud-origin", some(
        inventory(view), wornGroup(view), wornGroup(view, true),
        bodyTarget(view, { style: { position: "absolute", left: 126, bottom: 40, minWidth: 64 } }),
        ...actionGroups(view),
      ), { cls: ["hudgroup"], style: { position: "absolute", left: "55%", bottom: 0, width: 0, height: 0 } }),
      storageRegion(view),
      view.body ? column("status", some(
        text("identity", view.state.identity?.name ?? "", ["chipval"]), vitals(view),
      ), { cls: ["hudgroup"], style: { position: "absolute", right: 14, top: 14, alignItems: "end" } }) : null,
    ));
    children.push(...chatPanel(view));
    children.push(...documents(view));
    children.push(...inspectionPanels(view));
    children.push(...worldOverlays(view));
    return Pane("gameplay", children, {
      cls: ["hud"],
      style: { justifyContent: "center", alignItems: "center" },
    });
  },
  onEvent(e, view) {
    const command = shortcut(e.id, view as unknown as GameplayView);
    if (command) return { action: command };
    return event(e);
  },
};
export default ui;
