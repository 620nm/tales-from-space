// Two coordinated regions keep communication and body controls clear of
// each other; host windows contain expandable documents and storage.
import type { GuestUi, Json, UiNode } from "@lunatic/ui";
import { Pane, Stack, clientReport, recentLines } from "@lunatic/ui";
import type { GameplayView } from "./model";
import { begin, column, event, panel, row, some, text } from "./view";
import { STAFF_MARK, STATUS_DELAYED, STATUS_FROZEN, STATUS_HELD } from "./strings";
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
import { contactOnView, contactPanel } from "./contact/actions";

/** Where this body is and who it is, a staff mark, this session's hold,
 *  and the last few refusals and faults the client reported: lettering
 *  over the station, no pane. A line keys on its seq and the host clock
 *  retires it; nothing here keeps time. */
function statusCluster(view: GameplayView): UiNode | null {
  const place = (view.state as { location?: { name?: string } }).location?.name;
  const report = clientReport(view as unknown as Json);
  const where = some(
    view.state.staff_view ? text("status-staff", STAFF_MARK, ["statusmark"]) : null,
    view.body && place
      ? Stack("status-place", [
          panel("status-dot", [], { cls: ["statusdot"] }),
          text("status-place/name", place),
        ], { cls: ["hudgroup"], gap: 8, align: "center" })
      : null,
    view.body ? text("identity", view.state.identity?.name ?? "", ["statusname"]) : null,
  );
  const hold = report?.hold.frozen ? STATUS_FROZEN : report?.hold.control_held ? STATUS_HELD : null;
  const note = hold
    ? text("status-hold", hold, ["statusnote", "statusnote-hold"])
    : report?.connection.delayed ? text("status-hold", STATUS_DELAYED, ["statusnote"]) : null;
  const lines = report ? recentLines(report, 3, ["refused", "fault"]).reverse() : [];
  const rows = some(
    where.length ? row("status-where", where, { cls: ["hudgroup", "statusline"] }) : null,
    note,
    ...lines.map((line): UiNode => ({
      ...text(`status-line/${line.seq}`, line.text,
        line.kind === "refused" ? ["statusnote", "statusnote-refused"] : ["statusnote"]),
      expires: 4000,
    })),
  );
  if (!rows.length) return null;
  return column("status", rows, { cls: ["hudgroup", "statusline", "statuscluster"], style: {
    position: "absolute", right: 14, top: 14,
  } });
}

const ui: GuestUi = {
  onView(raw) {
    const view = raw as unknown as GameplayView;
    return { action: contactOnView(view) ?? pollContinuation(Object.values(view.documents ?? {})) };
  },
  render(raw) {
    const view = raw as unknown as GameplayView;
    begin();
    const children: UiNode[] = [];
    // The board and the condition card are the only nodes in flow, so
    // the root's own centring puts them where a modal belongs.
    children.push(...crewPanels(view));
    // Preparation owns the whole bounded surface. Keeping the gameplay HUD
    // out of this branch leaves the OOC and setup columns unobscured.
    if (view.state.round?.phase === "preparing" && !view.state.staff_view) {
      const contact = contactPanel(view);
      if (contact) children.push(panel("preparation-contact", [contact], {
        cls: ["hudgroup"], style: {
          position: "absolute", left: 12, bottom: 12, width: "32%", minWidth: 320, maxWidth: 420,
        },
      }));
      return Pane("gameplay", children, { cls: ["hud", "centered"] });
    }
    children.push(column("hud-comms", [
      ...inspectionPanels(view), ...some(contactPanel(view)), ...chatPanel(view),
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
    children.push(...some(storageRegion(view), statusCluster(view)));
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
