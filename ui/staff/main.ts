import type { GuestUi, UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { GameplayView } from "../model";
import { begin, bind, event, screen, text } from "../view";
import { casesWorkspace } from "./cases";
import { liveOverlay, liveWorkspace } from "./live";
import { localPress, request, profileCard, staffLocal } from "./actions";
import { readStaff, type StaffSession } from "./model";
import * as S from "./strings";
import { staffNotice } from "./notice";
import { applyFlowLocal, caseFlowPending, staffViewAction } from "./flows";
import { cursorReopenQuery } from "./cases/records";
import { staffRequest } from "./shared/actions";
import { beginProfileRender, profileViewAction } from "./profile/flows";

/** Staff package entry; the ordinary gameplay package never renders this. */
export function staffScreen(view: GameplayView): UiNode | null {
  const session = readStaff(view);
  if (!session || !session.allowed) return null;
  beginProfileRender(session);
  const state = staffLocal(session);
  applyFlowLocal(session, state);
  bind("staff/exit", () => request(session, { kind: "exit" }));
  const body = state.workspace === "cases" ? casesWorkspace(session) : liveWorkspace(session);
  const notice = staffNotice(session);
  const overlay = state.workspace === "live" ? liveOverlay(session) : null;
  const root = screen("staff/shell", {
    toolbar: [
      Stack("staff/header", [
        text("staff/header/brand", brandText(S.TITLE), ["staff-brand"]),
        Stack("staff/header/perspective", [
          text("staff/header/perspective/label", S.PERSPECTIVE.toUpperCase(), ["staff-header-perspective-label"]),
          text("staff/header/perspective/value", `${S.PERSPECTIVE} · ${S.SERVER_GRANTED}`, ["staff-header-perspective-value"]),
        ], { cls: ["staff-header-perspective"], gap: 2, align: "start", dir: "column" }),
        session.operator
          ? headerProfile(session)
          : text("staff/header/no-operator", S.NO_ACCESS, ["staff-muted"]),
        localPress("staff/header/inspector", state.inspectorOpen ? S.CLOSE_INSPECTOR : S.TOGGLE_INSPECTOR, () => { state.inspectorOpen = !state.inspectorOpen; }, { variant: "ghost" }),
        { id: "staff/header/exit", type: "button", class: ["btn", "btn-ghost"], text: S.EXIT, event: "staff/exit" },
      ], { cls: ["staff-header"], gap: 16, align: "center" }),
      Stack("staff/navigation", [
        text("staff/navigation/status", session.active ? S.RUNNING : S.ENTER, [session.active ? "staff-good" : "staff-warning"]),
        text("staff/navigation/round", `${session.roundId} · ${S.REVISION(session.revision)}`, ["staff-mono", "staff-muted"]),
        session.hold ? text("staff/navigation/hold", S.HOLD, ["staff-warning"]) : null,
      ].filter(Boolean) as UiNode[], { cls: ["staff-status-bar"], gap: 8, align: "center" }),
      { id: "staff/body/workspaces", type: "panel", class: ["staff-workspace-tabs"], children: [workspaceTabs(session)] },
    ],
    body: [
      body,
    ],
    footer: [
      text("staff/footer/audience", notice?.message ?? S.SERVER_GRANTED, [notice?.tone ?? "staff-muted"]),
      text("staff/footer/target", session.inspector ? S.SELECTED(session.inspector.target.id) : S.SELECT_TARGET, ["staff-mono"]),
      text("staff/footer/round", `${session.roundId} · ${S.REVISION(session.revision)}`, ["staff-mono", "staff-muted"]),
    ],
    overlay: overlay ? [overlay] : [],
  }, { cls: ["staff-shell"] });
  return root;
}

function workspaceTabs(session: StaffSession): UiNode {
  const state = staffLocal(session);
  return {
    id: "staff/workspace-nav", type: "row", class: ["staff-workspace-nav"], children: [
      { id: "staff/workspace-nav/live", type: "button", class: ["btn", "btn-ghost", "staff-workspace-tab", ...(state.workspace === "live" ? ["staff-workspace-tab-selected"] : [])], text: S.LIVE, event: bind("staff/workspace/live", () => { state.workspace = "live"; return undefined; }) },
      { id: "staff/workspace-nav/cases", type: "button", class: ["btn", "btn-ghost", "staff-workspace-tab", ...(state.workspace === "cases" ? ["staff-workspace-tab-selected"] : [])], text: S.CASES, event: bind("staff/workspace/cases", () => { state.workspace = "cases"; return undefined; }) },
    ],
  };
}

function brandText(title: string): string {
  return title.replace(/\s*\/\s*/, "\n/ ");
}

function headerProfile(session: StaffSession): UiNode {
  const card = profileCard("staff/header/operator", session.operator, "", session);
  return { ...card, class: [...(card.class ?? []), "staff-header-profile"] };
}

/** A refused page cursor reopens its query once no response chain is in flight. */
function cursorReopenAction(session: StaffSession | null) {
  if (!session || !session.allowed || caseFlowPending(session)) return undefined;
  const reopen = cursorReopenQuery(session);
  return reopen ? staffRequest(session, reopen) : undefined;
}

const ui: GuestUi = {
  onView(raw) {
    const view = raw as unknown as GameplayView;
    const session = readStaff(view);
    // Case opening owns the first response-chain turn. The profile observer
    // still records its own response while that chain is queued, but it never
    // gets to overtake a case read.
    const caseAction = staffViewAction(session);
    const profileAction = profileViewAction(session);
    return { action: caseAction ?? profileAction ?? cursorReopenAction(session) };
  },
  render(raw) {
    begin();
    return staffScreen(raw as unknown as GameplayView) ?? { id: "staff/empty", type: "panel" };
  },
  onEvent(e) {
    return event(e);
  },
};

export default ui;
