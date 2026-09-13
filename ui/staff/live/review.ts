import type { UiNode } from "@lunatic/ui";
import { Dialog } from "@lunatic/ui";
import { freezeReference, localButton, staffRequest } from "../shared/actions";
import type { StaffEntity, StaffSession } from "../model";
import { entityFor, refKey } from "../model";
import { press, text } from "../../view";
import * as S from "../strings";
import { liveState } from "./state";

let reviewed: StaffEntity | null = null;

/** Save the displayed row so a later selection cannot retarget its review. */
export function rememberReviewTarget(session: StaffSession, entity: StaffEntity): void {
  reviewed = { ...entity, ref: freezeReference(entity.ref) };
}

export function reviewTarget(session: StaffSession): StaffEntity | null {
  const state = liveState(session);
  if (!state.review) return null;
  return reviewed && refKey(reviewed.ref) === refKey(state.review.target)
    ? reviewed
    : entityFor(session, state.review.target.id);
}

export function reviewDialog(session: StaffSession, target: StaffEntity): UiNode | null {
  const state = liveState(session);
  const pending = state.review;
  if (!pending || refKey(pending.target) !== refKey(target.ref)) return null;
  const title = pending.verb === "kill" ? S.REVIEW_KILL : pending.verb === "gib" ? S.REVIEW_GIB : S.REVIEW_DELETE;
  const effect = pending.verb === "kill" ? S.KILL_EFFECT : pending.verb === "gib" ? S.GIB_EFFECT : S.DELETE_EFFECT;
  return Dialog("staff/review", {
    title,
    body: [
      text("staff/review/target", S.EXACT_TARGET(target.name, target.id), ["staff-review-target"]),
      text("staff/review/effect", effect, ["staff-muted"]),
    ],
    actions: [
      localButton("staff/review/cancel", S.KEEP_TARGET, () => { state.review = null; }, { variant: "ghost" }),
      press("staff/review/confirm", S.CONFIRM, () => {
        state.review = null;
        return staffRequest(session, { kind: "edit", edit: { kind: pending.verb, target: pending.target.id } });
      }, { variant: "danger" }),
    ],
  }, { dismissEvent: "staff/review/cancel", dismissLabel: S.KEEP_TARGET, initialFocus: "staff/review/cancel" });
}
