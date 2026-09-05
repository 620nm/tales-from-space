import type { GameplayView } from "./model";
import type { GuestUi, UiNode } from "@lunatic/ui";
import { begin, column, event, pane } from "./view";
import { crewPanels, chatPanel, inspectionPanels } from "./panels";
import { worldOverlays } from "./world-overlays";
import { inventory, shortcut } from "./inventory";
import { documents } from "./documents";

const ui: GuestUi = {
  render(raw) {
    const view = raw as unknown as GameplayView;
    begin();
    const children: UiNode[] = [];
    children.push(...crewPanels(view));
    const tray = inventory(view);
    if (tray) children.push(tray);
    children.push(...chatPanel(view));
    const docs = documents(view);
    if (docs.length)
      children.push(
        column("documents", docs, {
          position: "absolute",
          right: 14,
          top: 14,
          width: 470,
          maxHeight: 512,
          overflow: "auto",
          pointerEvents: "auto",
        }),
      );
    children.push(...inspectionPanels(view));
    children.push(...worldOverlays(view));
    return pane("gameplay", children, {
      width: "100%",
      height: "100%",
      backgroundColor: "transparent",
      pointerEvents: "none",
      padding: 0,
      overflow: "hidden",
    });
  },
  onEvent(e, view) {
    const command = shortcut(e.id, view as unknown as GameplayView);
    if (command) return { action: command };
    return event(e);
  },
};
export default ui;
