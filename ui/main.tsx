// The whole gameplay surface: a transparent sheet the station shows
// through, with the crew board in the middle of it and every other
// panel pinned to an edge.
import type { GuestUi, UiNode } from "@lunatic/ui";
import { Pane } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { begin, column, event } from "./view";
import { crewPanels } from "./lobby";
import { chatPanel } from "./chat";
import { inspectionPanels } from "./inspect";
import { worldOverlays } from "./world-overlays";
import { inventory, shortcut } from "./inventory";
import { documents } from "./documents";

const ui: GuestUi = {
  render(raw) {
    const view = raw as unknown as GameplayView;
    begin();
    const children: UiNode[] = [];
    // The board and the condition card are the only nodes in flow, so
    // the root's own centring puts them where a modal belongs.
    children.push(...crewPanels(view));
    const tray = inventory(view);
    if (tray) children.push(tray);
    children.push(...chatPanel(view));
    const docs = documents(view);
    if (docs.length)
      children.push(
        column("documents", docs, {
          cls: ["dock"],
          style: {
            position: "absolute",
            right: 14,
            top: 14,
            maxHeight: "84%",
            alignItems: "end",
            overflowY: "auto",
            pointerEvents: "auto",
          },
        }),
      );
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
