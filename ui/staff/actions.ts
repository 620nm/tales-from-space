import type { Json, UiNode } from "@lunatic/ui";
import { Button, Card, Dialog, Field, Stack, Tabs } from "@lunatic/ui";
import { bind, entry, press, select, text } from "../view";
import type { StaffCase, StaffEntity, StaffEvent, StaffProfile, StaffRef, StaffSession } from "./model";
import { accountRef, caseFor, entityFor, profileFor, refKey } from "./model";
import { profileQuery } from "./cases/records";
import { createCaseRequest, openCaseRequest, openedCaseRef, resetStaffFlows } from "./flows";
import { freezeReference as freezeActionReference, localButton, nativePress, recordsRequest, resetActionScope, staffRequest } from "./shared/actions";
import { identityCard } from "./shared/identity-card";
import * as S from "./strings";

export interface StaffLocalState {
  workspace: "live" | "cases";
  selectedId: string | null;
  selectedCaseId: string | null;
  selectedRef: StaffRef | null;
  inspector: "read" | "edit" | "audit";
  query: string;
  recordFilter: string | null;
  /** The target is the exact frozen reference selected by the operator. */
  review: { verb: "kill" | "delete" | "gib"; target: StaffRef; name?: string } | null;
  spawnOpen: boolean;
  spawnPrototype: string;
  spawnKind: string;
  spawnX: string;
  spawnY: string;
  spawnZ: string;
  spawnProperties: string;
  spawnPreview: boolean;
  inspectorOpen: boolean;
  drafts: Record<string, string>;
  roundId: string;
}

const fresh = (roundId = "", workspace: "live" | "cases" = "live"): StaffLocalState => ({
  workspace, selectedId: null, selectedCaseId: null, selectedRef: null,
  inspector: "read", query: "", recordFilter: null, review: null,
  spawnOpen: false, spawnPrototype: "", spawnKind: "entity", spawnX: "0", spawnY: "0", spawnZ: "0", spawnProperties: "{}", spawnPreview: false,
  inspectorOpen: true, drafts: {}, roundId,
});
let local = fresh();

export function staffLocal(session: StaffSession): StaffLocalState {
  if (local.roundId !== session.roundId) {
    local = fresh(session.roundId, session.workspace ?? "live");
    resetActionScope();
  }
  if (!local.selectedId && session.entities.length) local.selectedId = session.entities[0].id;
  if (local.selectedId && !entityFor(session, local.selectedId)) local.selectedId = session.entities[0]?.id ?? null;
  const opened = openedCaseRef(session);
  if (!local.selectedCaseId && (opened || session.cases.length)) local.selectedCaseId = opened?.id ?? session.cases[0]?.id ?? null;
  if (local.selectedCaseId && !caseFor(session, local.selectedCaseId) && local.selectedCaseId !== opened?.id) local.selectedCaseId = session.cases[0]?.id ?? null;
  return local;
}

export function resetStaffLocal(): void {
  local = fresh();
  resetActionScope();
  resetStaffFlows();
}

/** The pack action is namespaced again by the trusted host before transport. */
export function request(session: StaffSession, action: Record<string, Json>): Json {
  return staffRequest(session, action);
}

export function activate(id: string, action: () => void): void {
  bind(id, () => { action(); return undefined; });
}

export function staffPress(
  id: string,
  caption: unknown,
  session: StaffSession,
  action: Record<string, Json>,
  opts: Parameters<typeof press>[3] = {},
): UiNode {
  return nativePress(id, caption, session, action, opts);
}

/** Create-case presses register the response chain before transport. */
export function createCasePress(
  id: string,
  caption: unknown,
  session: StaffSession,
  anchor: StaffRef,
  opts: Parameters<typeof press>[3] = {},
): UiNode {
  return press(id, caption, () => createCaseRequest(session, anchor), opts);
}

/** Case selection starts the exact case page and its direct-anchor reads. */
export function openCasePress(
  id: string,
  caption: unknown,
  session: StaffSession,
  item: StaffCase,
  opts: Parameters<typeof press>[3] = {},
): UiNode {
  return press(id, caption, () => openCaseRequest(session, item), opts);
}

export function localPress(id: string, caption: unknown, action: () => void, opts: Parameters<typeof press>[3] = {}): UiNode {
  return localButton(id, caption, action, opts);
}

export function inspectPress(id: string, caption: unknown, session: StaffSession, ref: StaffRef, opts: Parameters<typeof press>[3] = {}): UiNode {
  bind(id, () => {
    local.selectedRef = freezeActionReference(ref);
    if (ref.kind === "body" || ref.kind === "entity") {
      local.workspace = "live";
      local.selectedId = ref.id;
    }
    local.inspector = "read";
    return request(session, { kind: "inspect", target: freezeActionReference(ref) });
  });
  return Button(id, caption, { ...opts, event: id });
}

export function workspaceTabs(_session: StaffSession): UiNode {
  return Tabs("staff/workspaces", [
    { key: "live", label: S.LIVE, selected: local.workspace === "live", event: bind("staff/workspace/live", () => { local.workspace = "live"; return undefined; }) },
    { key: "cases", label: S.CASES, selected: local.workspace === "cases", event: bind("staff/workspace/cases", () => { local.workspace = "cases"; return undefined; }) },
  ], { cls: ["staff-tabs"] });
}

export function profileCard(id: string, profile: StaffProfile | null | undefined, context = "", session?: StaffSession, timeline?: UiNode | null): UiNode {
  const open = profile && session
    ? press(`${id}/open`, S.OPEN_PROFILE, () => {
      const target = accountRef(profile.id);
      local.selectedRef = freezeActionReference(target);
      local.workspace = "cases";
      local.recordFilter = null;
      local.inspector = "read";
      return request(session, profileQuery(target));
    }, { variant: "ghost", cls: ["staff-card-action"] })
    : null;
  return identityCard(id, profile, { context, open, timeline });
}

export function profileActionCard(id: string, session: StaffSession, profile: StaffProfile | null, context = "", timeline?: UiNode | null): UiNode {
  return profileCard(id, profile, context, session, timeline);
}

export function targetSummary(id: string, entity: StaffEntity): UiNode {
  const details = entity.role ? `${entity.id} · ${entity.role}` : entity.id;
  return Card(id, [
    Stack(`${id}/heading`, [
      text(`${id}/kind`, entity.kind.toUpperCase(), ["staff-eyebrow"]),
      text(`${id}/name`, entity.name, ["staff-target-name"]),
    ], { cls: ["staff-target-heading"], gap: 5, align: "center" }),
    text(`${id}/identity`, details, ["staff-mono", "staff-muted"]),
    text(`${id}/state`, entity.state ?? S.SELECT_TARGET, [entity.frozen ? "staff-good" : "staff-muted"]),
  ], { cls: ["staff-target-summary"] });
}

export function entityButton(id: string, session: StaffSession, entity: StaffEntity, selected: boolean): UiNode {
  return inspectPress(id, `${entity.name} · ${entity.kind}`, session, entity.ref, { variant: selected ? "selected" : "default", cls: ["staff-entity-button"] });
}

export function recordButton(id: string, ref: StaffRef, selected: boolean, session?: StaffSession): UiNode {
  if (session) return inspectPress(id, `${ref.label ?? ref.kind} · ${ref.id}`, session, ref, { variant: selected ? "selected" : "default", cls: ["staff-record-button"] });
  return localPress(id, `${ref.label ?? ref.kind} · ${ref.id}`, () => {
    local.selectedRef = freezeActionReference(ref);
    local.recordFilter = refKey(ref);
    local.workspace = "cases";
  }, { variant: selected ? "selected" : "default", cls: ["staff-record-button"] });
}

export function auditEventRow(id: string, session: StaffSession, event: StaffEvent, selected = false): UiNode {
  return inspectPress(id, `${event.time ?? S.TIME} · ${event.action}`, session, event.reference, { variant: selected ? "selected" : "default", cls: ["staff-audit-row"] });
}

export function propertyField(id: string, session: StaffSession, target: StaffEntity, property: NonNullable<StaffEntity["properties"]>[number]): UiNode {
  const value = property.value === null || property.value === undefined ? "" : String(property.value);
  const draftKey = `${refKey(target.ref)}:${property.path}`;
  const draft = local.drafts[draftKey] ?? value;
  const callback = (next: string): Json | undefined => { local.drafts[draftKey] = next; return undefined; };
  let control: UiNode;
  if (property.type === "boolean" || typeof property.value === "boolean") {
    control = select(id, draft, [{ value: "false", text: S.FALSE }, { value: "true", text: S.TRUE }], callback, { cls: ["staff-property-control"], disabled: property.editable === false });
  } else if (property.type === "enum" && property.options?.length) {
    control = select(id, draft, property.options.map((option) => ({ value: option, text: option })), callback, { cls: ["staff-property-control"], disabled: property.editable === false });
  } else {
    control = entry(id, draft, callback, { cls: ["staff-property-control"], disabled: property.editable === false });
  }
  const children: UiNode[] = [
    Field(`${id}/label`, property.label ?? property.path, control),
    property.unit ? text(`${id}/unit`, property.unit, ["staff-unit"]) : text(`${id}/current`, `${S.CURRENT} · ${value || "—"}`, ["staff-current"]),
  ];
  if (property.editable === false) children.push(text(`${id}/reason`, property.reason ?? S.READ_ONLY, ["staff-muted"]));
  if (property.editable !== false && local.drafts[draftKey] !== undefined && local.drafts[draftKey] !== value) {
    children.push(staffPress(`${id}/apply`, S.APPLY, session, { kind: "edit", edit: { kind: "property", target: target.id, path: property.path, value: jsonValue(draft) } }, { variant: "primary" }));
  }
  return Stack(`${id}/field`, children, { cls: ["staff-property"], gap: 3, align: "center" });
}

function jsonValue(value: string): string {
  try { JSON.parse(value); return value; } catch { return JSON.stringify(value); }
}

/** Capture the exact reference at the moment a destructive review opens. */
export function beginReview(session: StaffSession, entity: StaffEntity, verb: "kill" | "delete" | "gib"): void {
  local.review = { verb, target: freezeActionReference(entity.ref), name: entity.name };
  local.selectedRef = freezeActionReference(entity.ref);
  local.selectedId = entity.id;
  void session;
}

export function reviewDialog(session: StaffSession, target: StaffEntity): UiNode | null {
  const pending = local.review;
  if (!pending) return null;
  const targetRef = pending.target;
  if (targetRef.id !== target.id || targetRef.round !== target.ref.round || targetRef.kind !== target.ref.kind) return null;
  const verb = pending.verb;
  const close = localPress("staff/review/cancel", S.KEEP_TARGET, () => { local.review = null; }, { variant: "ghost" });
  const confirm = staffPress("staff/review/confirm", S.CONFIRM, session, { kind: "edit", edit: { kind: verb, target: targetRef.id } }, { variant: "danger" });
  return Dialog("staff/review", {
    title: verb === "kill" ? S.REVIEW_KILL : verb === "delete" ? S.REVIEW_DELETE : S.REVIEW_GIB,
    body: [text("staff/review/target", S.EXACT_TARGET(pending.name ?? target.name, targetRef.id), ["staff-review-target"]), text("staff/review/effect", effectText(verb), ["staff-muted"])],
    actions: [close, confirm],
  }, { dismissEvent: "staff/review/cancel", dismissLabel: S.KEEP_TARGET, initialFocus: "staff/review/cancel" });
}

function effectText(verb: string): string {
  if (verb === "kill") return S.KILL_EFFECT;
  if (verb === "gib") return S.GIB_EFFECT;
  return S.DELETE_EFFECT;
}

export function accountForEntity(session: StaffSession, entity: StaffEntity): StaffProfile | null {
  return profileFor(session, entity.accountId);
}

export function capability(entity: StaffEntity, action: string): boolean {
  if (entity.capabilities && action in entity.capabilities) return entity.capabilities[action as keyof NonNullable<StaffEntity["capabilities"]>] !== false;
  return action === "inspect";
}

export function eventMatches(event: StaffEvent, key: string | null): boolean {
  if (!key) return true;
  const wanted = key.split(":").at(-1);
  return [event.reference.id, event.target, event.targetRef?.id, ...(event.targetRefs ?? []).map((ref) => ref.id), event.accountId, event.actorMind, event.actorBody, event.caseId]
    .some((value) => value !== undefined && String(value) === wanted);
}

export { recordsRequest };
export { freezeReference } from "./shared/actions";
