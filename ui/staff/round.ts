import type { Json, UiNode } from "@lunatic/ui";
import { Stack } from "@lunatic/ui";
import type { PreparationIssue, RoundStatus } from "../model";
import { press, text } from "../view";
import type { StaffRecordResponse, StaffSession } from "./model";
import { staffRequest } from "./shared/actions";
import * as S from "./strings";

export type RoundControlVerb = "pause" | "resume" | "start_now";

interface RoundPanelState {
  roundId: string;
  roundNumber: number | null;
  phase: RoundStatus["phase"] | null;
  pending: { requestId: string; action: RoundControlVerb; revision: string } | null;
  refusalKey: string | null;
  lastReplyId: string | null;
}

const fresh = (roundId = ""): RoundPanelState => ({
  roundId,
  roundNumber: null,
  phase: null,
  pending: null,
  refusalKey: null,
  lastReplyId: null,
});

let local = fresh();

export function resetRoundPanel(): void {
  local = fresh();
}

function isRoundControlReply(reply: StaffRecordResponse): boolean {
  const query = reply.query;
  return !!query && typeof query === "object" && !Array.isArray(query) && "RoundControl" in query;
}

/** Reconcile pending state and refusal feedback from the latest staff and round views. */
export function observeRoundReply(session: StaffSession | null, round: RoundStatus | undefined): void {
  if (!session?.active) {
    local = fresh();
    return;
  }
  if (local.roundId !== session.roundId) local = fresh(session.roundId);
  if (round && (local.roundNumber !== round.round || local.phase !== round.phase)) {
    local.roundNumber = round.round;
    local.phase = round.phase;
    local.refusalKey = null;
  }
  const reply = session.records?.response;
  if (local.pending) {
    if (reply && reply.request_id === local.pending.requestId) {
      local.pending = null;
      local.lastReplyId = reply.request_id;
      local.refusalKey = typeof reply.error === "string" && reply.error ? reply.error : null;
    } else if (typeof session.error === "string" && session.error) {
      local.pending = null;
      local.refusalKey = session.error;
    } else if (session.revision !== local.pending.revision) {
      local.pending = null;
    }
    return;
  }
  if (reply && reply.request_id !== local.lastReplyId && isRoundControlReply(reply)) {
    local.lastReplyId = reply.request_id;
    local.refusalKey = typeof reply.error === "string" && reply.error ? reply.error : null;
  }
}

export function roundControlDisabled(
  round: RoundStatus | undefined,
  action: RoundControlVerb,
  pending: boolean,
): boolean {
  return !round || round.phase !== "preparing" || pending
    || (action === "pause" && round.paused)
    || (action === "resume" && !round.paused);
}

function sendRoundControl(
  session: StaffSession,
  round: RoundStatus | undefined,
  action: RoundControlVerb,
): Json | undefined {
  if (!session.active || roundControlDisabled(round, action, !!local.pending)) return undefined;
  const command = staffRequest(session, { kind: "round_control", action });
  const requestId = (command as { request?: { request_id?: string } }).request?.request_id ?? "";
  local.pending = { requestId, action, revision: session.revision };
  local.refusalKey = null;
  return command;
}

const PHASE_LABELS: Record<RoundStatus["phase"], () => string> = {
  preparing: () => S.ROUND_PHASE_PREPARING,
  playing: () => S.ROUND_PHASE_PLAYING,
  ending: () => S.ROUND_PHASE_ENDING,
};

const ACTION_LABELS: Record<RoundControlVerb, () => string> = {
  pause: () => S.ROUND_ACTION_PAUSE,
  resume: () => S.ROUND_ACTION_RESUME,
  start_now: () => S.ROUND_ACTION_START_NOW,
};

const ISSUE_LABELS: Record<PreparationIssue, () => string> = {
  invalid_draft: () => S.ROUND_ISSUE_INVALID_DRAFT,
  stale: () => S.ROUND_ISSUE_STALE,
  locked: () => S.ROUND_ISSUE_LOCKED,
  allocation_failed: () => S.ROUND_ISSUE_ALLOCATION_FAILED,
  no_assignments: () => S.ROUND_ISSUE_NO_ASSIGNMENTS,
};

const REFUSAL_LABELS: Record<string, () => string> = {
  "staff.stale_round": () => S.ROUND_REFUSED_STALE_ROUND,
  "staff.stale_revision": () => S.ROUND_REFUSED_STALE_REVISION,
  "staff.forbidden": () => S.ROUND_REFUSED_FORBIDDEN,
  "staff.not_authorized": () => S.ROUND_REFUSED_NOT_AUTHORIZED,
  "staff.invalid_request": () => S.ROUND_REFUSED_INVALID_REQUEST,
  "staff.storage_failed": () => S.STORAGE_FAILED,
  "staff.audit_failed": () => S.ROUND_REFUSED_AUDIT_FAILED,
  "staff.intent_pending": () => S.ROUND_REFUSED_INTENT_PENDING,
  "staff.intent_failed": () => S.ROUND_REFUSED_INTENT_FAILED,
  "staff.result_failed": () => S.ROUND_REFUSED_RESULT_FAILED,
  "staff.rejected": () => S.ROUND_REFUSED_REJECTED,
  "staff.round_invalid_phase": () => S.ROUND_REFUSED_INVALID_PHASE,
  "staff.round_no_ready_players": () => S.ROUND_REFUSED_NO_READY_PLAYERS,
  "staff.round_deferred": () => S.ROUND_REFUSED_DEFERRED,
  "staff.round_allocation_failed": () => S.ROUND_REFUSED_ALLOCATION_FAILED,
};

export function knownRoundRefusalText(key: string): string | null {
  const resolve = REFUSAL_LABELS[key];
  return resolve ? resolve() : null;
}

export function roundRefusalText(key: string): string {
  return knownRoundRefusalText(key) ?? S.ROUND_REFUSED_REJECTED;
}

/** Round operator bar: visible only while staff mode is active and round status is disclosed. */
export function roundOperatorBar(session: StaffSession, round: RoundStatus | undefined): UiNode | null {
  observeRoundReply(session, round);
  if (!session.active || !round) return null;
  const countdown = round.remaining_seconds === null ? "" : ` · ${S.ROUND_COUNTDOWN(round.remaining_seconds)}`;
  const paused = round.paused ? ` · ${S.ROUND_PAUSED}` : "";
  const waiting = round.waiting ? ` · ${S.ROUND_WAITING}` : "";
  const statusLine = `${S.ROUND_STATUS(round.round, PHASE_LABELS[round.phase]())}${countdown}${paused}${waiting}`;
  const fault = round.fault ? ` · ${ISSUE_LABELS[round.fault]()}` : "";
  const cohortLine = `${S.ROUND_COHORT(round.ready, round.connected)}${fault}`;
  const feedback = local.pending
    ? S.ROUND_PENDING(ACTION_LABELS[local.pending.action]())
    : local.refusalKey
    ? roundRefusalText(local.refusalKey)
    : null;
  const pending = !!local.pending;
  const actions: RoundControlVerb[] = ["pause", "resume", "start_now"];
  return Stack("staff/round", [
    Stack("staff/round/summary", [
      text("staff/round/status", statusLine, ["staff-mono"]),
      text("staff/round/cohort", cohortLine, ["staff-muted"]),
      feedback ? text("staff/round/feedback", feedback, [local.pending ? "staff-muted" : "staff-warning"]) : null,
    ].filter(Boolean) as UiNode[], { cls: ["staff-round-summary"], gap: 8, align: "center" }),
    Stack("staff/round/controls", actions.map((action) =>
      press(
        `staff/round/${action}`,
        ACTION_LABELS[action](),
        () => sendRoundControl(session, round, action),
        {
          variant: action === "start_now" ? "primary" : "ghost",
          disabled: roundControlDisabled(round, action, pending),
        },
      ),
    ), { cls: ["staff-round-controls"], gap: 6, align: "center" }),
  ], { cls: ["staff-round-bar"], gap: 12, align: "center" });
}
