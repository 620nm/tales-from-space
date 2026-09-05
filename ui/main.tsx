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
import { inventory, shortcut, TRAY_WIDE } from "./inventory";
import { bodyTarget } from "./doll";
import { storageRegion } from "./inventory-storage";
import { documents } from "./documents";

// The bottom-right stack, from the station's edge upwards: the tray, the
// target figure, and an open container beside the figure. Each is its own
// HUD region, so opening a bag moves nothing else. The tray's own height
// is the head row, one row of squares and the verbs — 158px at its
// tallest, with a held container's Open row and a wrapped verb row.
const TRAY_TOP = 164;
const DOLL_WIDE = 80;

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
    const target = bodyTarget(view, {
      style: { position: "absolute", right: 14, bottom: TRAY_TOP },
    });
    if (target) children.push(target);
    const stored = storageRegion(view, {
      style: {
        position: "absolute",
        right: 14 + DOLL_WIDE,
        bottom: TRAY_TOP,
        width: TRAY_WIDE - DOLL_WIDE,
        maxHeight: "40%",
        overflowY: "auto",
      },
    });
    if (stored) children.push(stored);
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
