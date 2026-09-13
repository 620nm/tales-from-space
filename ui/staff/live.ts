import type { UiNode } from "@lunatic/ui";
import { reviewDialog } from "./live/review";
import { isDecimalId, isProfileId, profileCardValue, type StaffEntity, type StaffSession } from "./model";
import { liveInspector } from "./live/inspector";
import { nativeWorldOverlay } from "./live/world";
import { staffLocal } from "./actions";
import { reviewTarget as pendingReviewTarget } from "./live/review";

/** Live station is a click-through overlay over the trusted world canvas. */
export function liveWorkspace(session: StaffSession): UiNode {
  const state = staffLocal(session);
  const entity = selectedEntity(session);
  return {
    id: "staff/live/layout",
    type: "row",
    class: ["staff-live-layout"],
    children: [
      nativeWorldOverlay(session, entity),
      ...(state.inspectorOpen ? [liveInspector(session, entity)] : []),
    ],
  };
}

/** Keep the destructive review tied to the instance that opened it. */
export function liveOverlay(session: StaffSession): UiNode | null {
  const target = reviewTarget(session);
  return target ? reviewDialog(session, target) : null;
}

/** Resolve the native inspection first, then the current world roster. */
export function selectedEntity(session: StaffSession): StaffEntity | null {
  const inspection = session.inspector;
  if (inspection?.target.id && inspection.found) {
    const listed = session.entities.find((entity) =>
      entity.ref.round === inspection.target.round
      && entity.ref.id === inspection.target.id,
    );
    const payload = inspection.payload ?? {};
    const current = listed ?? {
      id: inspection.target.id,
      kind: inspection.target.kind,
      name: typeof payload.name === "string" ? payload.name : typeof payload.username === "string" ? payload.username : inspection.target.id,
      ref: inspection.target,
      ...(inspection.target.kind === "account" ? { accountId: inspection.target.id } : {}),
    };
    const live = payload.live === true;
    const classification = inspection.target.kind === "entity"
      ? listed?.kind ?? inspection.target.kind
      : inspection.target.kind;
    return {
      ...current,
      ...payloadFields(payload),
      id: inspection.target.id,
      kind: classification,
      ref: inspection.target,
      readOnly: inspection.tombstone
        || inspection.target.round !== session.roundId
        || inspection.target.kind === "account"
        || !LIVE_REFERENCE_KINDS.has(inspection.target.kind)
        || !live,
      payload: { ...(current.payload ?? {}), ...payload },
    };
  }
  return null;
}

const LIVE_REFERENCE_KINDS = new Set([
  "entity", "player", "body", "mob", "item", "structure", "machine", "underfloor", "overhead",
]);

function payloadFields(payload: Record<string, unknown>): Partial<StaffEntity> {
  const position = payload.position;
  const pos = position && typeof position === "object" && !Array.isArray(position)
    ? (() => {
      const raw = position as { x?: unknown; y?: unknown; z?: unknown };
      return typeof raw.x === "number" && Number.isFinite(raw.x) && typeof raw.y === "number" && Number.isFinite(raw.y)
        ? { x: raw.x, y: raw.y, ...(typeof raw.z === "number" && Number.isFinite(raw.z) ? { z: raw.z } : {}) }
        : undefined;
    })()
    : undefined;
  const capabilities = Array.isArray(payload.capabilities)
    ? Object.fromEntries(["inspect", "freeze", "restore", "drive", "kill", "delete", "gib", "move", "duplicate", "property"].filter((key) => payload.capabilities?.includes(key)).map((key) => [key, true])) as StaffEntity["capabilities"]
    : undefined;
  const profileCard = profileCardValue(payload.profile_card);
  return {
    ...(typeof payload.name === "string" ? { name: payload.name } : {}),
    ...(pos ? { pos } : {}),
    ...(typeof payload.frozen === "boolean" ? { frozen: payload.frozen } : {}),
    ...(typeof payload.editable === "boolean" ? { editable: payload.editable } : {}),
    ...(typeof payload.live === "boolean" ? { live: payload.live } : {}),
    ...(isProfileId(payload.account_id) ? { accountId: payload.account_id } : {}),
    ...(isDecimalId(payload.mind_id) ? { mindId: payload.mind_id } : {}),
    ...(isDecimalId(payload.body_id) ? { bodyId: payload.body_id } : {}),
    ...(profileCard ? { profileCard, ...(typeof payload.name !== "string" ? { name: profileCard.username } : {}) } : {}),
    ...(capabilities ? { capabilities } : {}),
  };
}

function reviewTarget(session: StaffSession): StaffEntity | null {
  const pending = pendingReviewTarget(session);
  const selected = selectedEntity(session);
  return pending && selected && !selected.readOnly && sameReference(pending.ref, selected.ref) ? pending : null;
}

function sameReference(left: StaffEntity["ref"], right: StaffEntity["ref"]): boolean {
  return left.round === right.round && left.kind === right.kind && left.id === right.id;
}
