import type { Json, UiNode } from "@lunatic/ui";
import { Card, Divider, LabeledList, Section, Stack, Table } from "@lunatic/ui";
import { bind, entry, press, text } from "../view";
import { localButton as localPress, nativePress as staffPress } from "./shared/actions";
import { createCasePress, inspectPress, openCasePress, profileActionCard, staffLocal } from "./actions";
import type { StaffCase, StaffEntity, StaffEvent, StaffRef, StaffSession } from "./model";
import { entityFor, profileFor } from "./model";
import { profileDrill } from "./profile";
import {
  allCaseEvents, cachedCase, caseAccountIds, caseAnchorRefs, caseEventRefs, caseId, caseLabel, casePageFor, caseQuery, caseRef,
  contextPageFor, contextQuery, eventRef, objectValue, pageFor, queryJson, responseCase, responseProfileFor, stringValue, uniqueRefs,
} from "./cases/records";
import { recordsRequest, staffRequest } from "./shared/actions";
import { openedCase } from "./flows";
import * as S from "./strings";

export function casesWorkspace(session: StaffSession): UiNode {
  const state = staffLocal(session);
  const selected = selectedCase(session);
  return {
    id: "staff/cases/layout", type: "row", class: ["staff-cases-layout"],
    // The shell's inspector toggle is also the compact rail collapse affordance.
    children: [caseRail(session, selected), caseTimeline(session, selected), ...(state.inspectorOpen ? [evidenceInspector(session, selected)] : [])],
  };
}

function selectedCase(session: StaffSession): StaffCase | null {
  const state = staffLocal(session);
  const cases = session.cases ?? [];
  const active = openedCase(session);
  const selected = cases.find((item) => caseId(item) === state.selectedCaseId);
  return active ?? selected ?? cases[0] ?? null;
}

function caseRail(session: StaffSession, selected: StaffCase | null): UiNode {
  const state = staffLocal(session);
  const active = openedCase(session);
  const all = active && !(session.cases ?? []).some((item) => caseId(item) === caseId(active))
    ? [active, ...(session.cases ?? [])]
    : (session.cases ?? []);
  const values = all.filter((item) => {
    const query = state.query.trim().toLowerCase();
    return !query || `${caseId(item)} ${caseLabel(item)}`.toLowerCase().includes(query);
  });
  const page = pageFor(session, "cases");
  return Card("staff/cases/rail", [
    textNode("staff/cases/rail/kicker", S.CASE_CONTEXT, "staff-eyebrow"),
    textNode("staff/cases/rail/title", S.CASES, "staff-title"),
    { id: "staff/cases/filter", type: "input", value: state.query, label: S.INSPECT, event: bind("staff/cases/filter", (event) => { state.query = event.value ?? ""; return undefined; }), class: ["entry", "staff-case-filter"] },
    ...values.map((item, index) => {
      const id = caseId(item);
      return openCasePress(`staff/cases/select/${id || index}`, `${id} · ${caseLabel(item)}`, session, item, { variant: selected && caseId(selected) === id ? "selected" : "default", cls: ["staff-case-button"] });
    }),
    values.length ? null : textNode("staff/cases/rail/empty", S.NO_CASE, "staff-muted"),
    page.error ? textNode("staff/cases/rail/error", page.error, "staff-warning") : null,
    page.next ? staffPress("staff/cases/rail/load-more", S.ALL_RECORDS, session, casesQuery(page.next), { variant: "ghost" }) : null,
    Divider("staff/cases/rail/divider"),
    Section("staff/cases/rail/records", S.ASSOCIATED, selected ? associatedRecords(session, selected) : [textNode("staff/cases/rail/no-case", S.CHOOSE_CASE, "staff-muted")]),
  ].filter(Boolean) as UiNode[], { cls: ["staff-case-rail"] });
}

function casesQuery(after?: string | null): Record<string, Json> {
  return { kind: "query", query: queryJson("cases", { limit: 64, ...(after ? { after } : {}) }) };
}

function associatedRecords(session: StaffSession, item: StaffCase): UiNode[] {
  const refs = orderedEvidence(session, item);
  const chosen = staffLocal(session).selectedRef;
  if (!refs.length) return [textNode("staff/cases/rail/empty-records", S.NO_RECORDS, "staff-muted")];
  return refs.map((ref, index) => caseRecordButton(`staff/cases/rail/ref/${index}`, ref, !!chosen && chosen.round === ref.round && chosen.kind === ref.kind && chosen.id === ref.id, session));
}

/** Accounts, Minds, bodies, objects and exact event refs keep a stable order. */
function orderedEvidence(session: StaffSession, item: StaffCase): StaffRef[] {
  const anchors = caseAnchorRefs(session, item);
  const events = caseEventRefs(session, item);
  const accounts = refsForCaseRows(session, item, "account");
  const minds = refsForCaseRows(session, item, "mind");
  const bodies = refsForCaseRows(session, item, "body");
  const entities = anchors.filter((ref) => ref.kind !== "account" && ref.kind !== "mind" && ref.kind !== "body");
  return uniqueRefs([...accounts, ...minds, ...bodies, ...entities, ...events]);
}

function refsForCaseRows(session: StaffSession, item: StaffCase, kind: string): StaffRef[] {
  const out = [
    ...caseAnchorRefs(session, item),
    ...item.attachments,
  ].filter((ref) => ref.kind === kind);
  return uniqueRefs(out);
}

function caseTimeline(session: StaffSession, item: StaffCase | null): UiNode {
  const state = staffLocal(session);
  if (!item) return Card("staff/cases/timeline", [textNode("staff/cases/timeline/empty-case", S.CHOOSE_CASE, "staff-muted")], { cls: ["staff-case-timeline"] });
  const allRows = allCaseEvents(session, item);
  const rows = allRows.filter((event) => !state.recordFilter || eventMatchesRef(event, state.recordFilter));
  const page = caseRef(session, item) ? casePageFor(session, caseRef(session, item)!) : pageFor(session, "case");
  const target = caseRef(session, item);
  const anchor = caseAnchorRefs(session, item)[0] ?? null;
  const anchors = caseAnchorRefs(session, item);
  const contextPages = anchors.map((ref) => ({ ref, page: contextPageFor(session, ref) }));
  return Card("staff/cases/timeline", [
    Stack("staff/cases/timeline/head", [textNode("staff/cases/timeline/kicker", S.HISTORY, "staff-eyebrow"), textNode("staff/cases/timeline/title", `${caseId(item)} · ${caseLabel(item)}`, "staff-section-title"), textNode("staff/cases/timeline/count", S.RECORD_COUNT(rows.length, allRows.length), "staff-muted"), target ? staffPress("staff/cases/timeline/query", S.ALL_RECORDS, session, caseQuery(session, item), { variant: "ghost" }) : null].filter(Boolean) as UiNode[], { cls: ["staff-timeline-heading"], gap: 6, align: "center" }),
    anchors.length ? Stack("staff/cases/timeline/anchors", anchors.map((ref, index) => contextPress(`staff/cases/timeline/anchor/${index}`, `${S.ALL_RECORDS} · ${refCaption(session, ref)}`, session, ref)), { cls: ["staff-action-row"], gap: 4, wrap: true }) : null,
    evidenceChain(session, item),
    state.recordFilter ? Stack("staff/cases/timeline/filter", [textNode("staff/cases/timeline/filter/text", state.recordFilter, "staff-muted"), localPress("staff/cases/timeline/filter/clear", S.ALL_RECORDS, () => { state.recordFilter = null; }, { variant: "ghost" })], { cls: ["staff-filter-banner"], gap: 5, align: "center" }) : null,
    rows.length ? Table("staff/cases/timeline/table", ["auto", "1fr", "1fr", "1fr"], rows.map((event) => eventRow(session, event)), { header: [S.TIME, S.ACTION_TARGET, S.INCLUSION, S.ACCOUNT_PROFILE] }) : textNode("staff/cases/timeline/empty", S.EMPTY_FILTER, "staff-muted"),
    page.error ? textNode("staff/cases/timeline/error", page.error, "staff-warning") : null,
    page.next && target ? staffPress("staff/cases/timeline/load-more", S.ALL_RECORDS, session, caseQuery(session, item, page.next), { variant: "ghost" }) : null,
    ...contextPages.flatMap(({ ref, page }, index) => page.next
      ? [staffPress(`staff/cases/timeline/context-load-more/${index}`, S.ALL_RECORDS, session, contextQuery(session, ref, page.next), { variant: "ghost" })]
      : []),
    itemActions(session, target, anchor),
  ].filter(Boolean) as UiNode[], { cls: ["staff-case-timeline"] });
}

function contextPress(id: string, caption: unknown, session: StaffSession, anchor: StaffRef, after?: string | null): UiNode {
  return press(id, caption, () => {
    const state = staffLocal(session);
    state.selectedRef = { ...anchor };
    state.recordFilter = null;
    return staffRequest(session, contextQuery(session, anchor, after));
  }, { variant: "ghost" });
}

function eventRow(session: StaffSession, event: StaffEvent): UiNode[] {
  const state = staffLocal(session);
  const target = eventRef(session, event);
  if (!target) return [textNode(`staff/cases/event/${event.id}/time`, event.time, "staff-mono")];
  const selected = !!state.selectedRef && state.selectedRef.round === target.round && state.selectedRef.kind === target.kind && state.selectedRef.id === target.id;
  const adminProfileId = (event as StaffEvent & { adminProfileId?: string }).adminProfileId;
  const identityId = event.admin ? adminProfileId ?? event.accountId : event.accountId;
  const profile = accountProfile(session, identityId);
  const actor = event.actor || event.actorMind || event.actorBody || S.RECORD_ONLY;
  const identity = profile
    ? profileActionCard(`staff/cases/event/${event.id}/profile`, session, profile, event.admin ? S.ADMIN : `${S.ACTOR} · ${actor}`)
    : unknownAccount(`staff/cases/event/${event.id}/profile`, identityId);
  return [
    inspectPress(`staff/cases/event/${event.id}`, event.time, session, target, { variant: selected ? "selected" : "ghost", cls: ["staff-event-time"] }),
    Stack(`staff/cases/event/${event.id}/action`, [
      textNode(`staff/cases/event/${event.id}/action/name`, event.action, "staff-event-action"),
      event.target ? textNode(`staff/cases/event/${event.id}/action/target`, `${S.ACTION_TARGET} · ${event.target}`, "staff-event-actor") : null,
      textNode(`staff/cases/event/${event.id}/action/actor`, `${S.ACTOR} · ${actor}`, "staff-event-actor"),
      textNode(`staff/cases/event/${event.id}/action/mind`, `${S.MIND} · ${event.actorMind || S.RECORD_ONLY}`, "staff-event-actor"),
    ].filter(Boolean) as UiNode[], { dir: "column", gap: 2 }),
    textNode(`staff/cases/event/${event.id}/reason`, event.includedThrough || event.reason || S.EXACT_EVENT, "staff-muted"),
    identity,
  ];
}

/** Keep missing account metadata legible without displaying a full profile id. */
function unknownAccount(id: string, accountId: string | undefined): UiNode {
  const short = accountId ? `${accountId.slice(0, 8)}…${accountId.slice(-6)}` : S.RECORD_ONLY;
  return Card(id, [
    textNode(`${id}/name`, S.NO_ACCOUNT, "staff-muted"),
    textNode(`${id}/id`, short, "staff-mono"),
  ], { cls: ["staff-profile", "staff-profile-empty"] });
}

function evidenceChain(session: StaffSession, item: StaffCase): UiNode {
  const refs = orderedEvidence(session, item);
  const anchor = caseAnchorRefs(session, item)[0];
  return Card("staff/cases/chain", [textNode("staff/cases/chain/title", anchor ? `${S.ANCHOR_HISTORY} · ${refCaption(session, anchor)}` : S.ANCHOR_HISTORY, "staff-eyebrow"), Stack("staff/cases/chain/refs", refs.map((ref, index) => caseRecordButton(`staff/cases/chain/ref/${index}`, ref, false, session)), { cls: ["staff-chain"], gap: 4, wrap: true }), textNode("staff/cases/chain/source", S.SOURCE_ROWS(allCaseEvents(session, item).length), "staff-muted")], { cls: ["staff-evidence-chain"] });
}

function caseRecordButton(id: string, ref: StaffRef, selected: boolean, session: StaffSession): UiNode {
  const caption = refCaption(session, ref);
  return inspectPress(id, caption, session, ref, { variant: selected ? "selected" : "default", cls: ["staff-record-button"] });
}

function refCaption(session: StaffSession, ref: StaffRef): string {
  const profile = ref.kind === "account" ? accountProfile(session, ref.id) : null;
  return ref.kind === "account"
    ? `${profile?.username ?? S.NO_ACCOUNT} · ${shortId(ref.id)}`
    : `${ref.label ?? ref.kind} · ${ref.id}`;
}

function shortId(id: string): string {
  return id.length > 14 ? `${id.slice(0, 6)}…${id.slice(-4)}` : id;
}

function accountProfile(session: StaffSession, id: string | undefined): ReturnType<typeof profileFor> {
  return (id ? responseProfileFor(session, id) : null) ?? profileFor(session, id);
}

function itemActions(session: StaffSession, target: StaffRef | null, anchor: StaffRef | null): UiNode {
  const actions: UiNode[] = [];
  if (anchor) actions.push(createCasePress("staff/cases/create", S.CREATE_CASE, session, anchor, { variant: "ghost" }));
  const selected = staffLocal(session).selectedRef;
  if (target && selected?.kind === "event") actions.push(staffPress("staff/cases/attach", S.ATTACH, session, recordsRequest("attach", { case: target, event: selected }), { variant: "primary" }));
  if (target) actions.push(localPress("staff/cases/outcome", S.OUTCOME, () => {
    const state = staffLocal(session);
    state.selectedRef = target;
    state.inspectorOpen = true;
  }, { variant: "ghost" }));
  return Stack("staff/cases/actions", actions, { cls: ["staff-action-row"], gap: 5 });
}

function evidenceInspector(session: StaffSession, item: StaffCase | null): UiNode {
  const state = staffLocal(session);
  const ref = state.selectedRef;
  if (ref?.kind === "account") return profileDrill(session, ref.id);
  const entity = ref?.kind === "entity" || ref?.kind === "body" ? entityFor(session, ref.id) : null;
  const profile = entity?.accountId ? accountProfile(session, entity.accountId) : null;
  const event = ref?.kind === "event" && item ? allCaseEvents(session, item).find((row) => row.reference.round === ref.round && row.id === ref.id) : null;
  const target = item ? caseRef(session, item) : null;
  return Card("staff/cases/evidence", [
    textNode("staff/cases/evidence/kicker", S.INSPECTOR, "staff-eyebrow"),
    textNode("staff/cases/evidence/title", ref ? refCaption(session, ref) : S.SELECT_TARGET, "staff-target-name"),
    item ? textNode("staff/cases/evidence/case", item.status || S.OPEN_CASE, "staff-muted") : null,
    ref ? Stack("staff/cases/evidence/actions", [target && event ? staffPress("staff/cases/evidence/attach", S.ATTACH, session, recordsRequest("attach", { case: target, event: ref }), { variant: "primary" }) : null, createCasePress("staff/cases/evidence/create", S.CREATE_CASE, session, ref, { variant: "ghost" })].filter(Boolean) as UiNode[], { cls: ["staff-action-row"], gap: 5 }) : null,
    entity ? entityInspector(entity) : null,
    event ? eventInspector(event) : null,
    profile ? profileActionCard("staff/cases/evidence/profile", session, profile, S.RECORD_ONLY) : null,
    ref?.kind === "event" && !event ? textNode("staff/cases/evidence/event-unavailable", S.NO_HISTORY, "staff-warning") : null,
    item ? workflow(session, item, target) : null,
    !ref ? textNode("staff/cases/evidence/hint", S.INSPECT_HINT, "staff-muted") : null,
  ].filter(Boolean) as UiNode[], { cls: ["staff-evidence-inspector"] });
}

function entityInspector(entity: StaffEntity): UiNode {
  return Section("staff/cases/entity", S.PROPERTIES, [LabeledList("staff/cases/entity/values", [{ label: S.KIND, value: entity.kind }, { label: S.STATE, value: entity.state }, { label: S.LOCATION, value: entity.location }, { label: S.BODY, value: entity.bodyId }])], { cls: ["staff-entity-inspector"] });
}

function eventInspector(event: StaffEvent): UiNode {
  return Section("staff/cases/event-inspector", S.AUDIT, [LabeledList("staff/cases/event-inspector/values", [{ label: S.ACTOR, value: event.actor }, { label: S.MIND, value: event.actorMind }, { label: S.BODY, value: event.actorBody }, { label: S.OPERATOR, value: event.operator }, { label: S.ADMIN, value: event.admin ? S.TRUE : S.FALSE }, { label: S.RESULT, value: event.result }])], { cls: ["staff-event-inspector"] });
}

function workflow(session: StaffSession, item: StaffCase, target: StaffRef | null): UiNode {
  const state = staffLocal(session);
  const id = caseId(item);
  const noteKey = `case:${id}:note`;
  const statusKey = `case:${id}:status`;
  const note = state.drafts[noteKey] ?? "";
  const status = state.drafts[statusKey] ?? item.status ?? S.OPEN_CASE;
  const selectedRecipients = recipientsFor(item, state);
  const raw = item as unknown as Record<string, unknown>;
  const notes = Array.isArray(raw.notes) ? raw.notes : [];
  const statuses = Array.isArray(raw.statuses) ? raw.statuses : [];
  const outcomes = Array.isArray(raw.outcomes) ? raw.outcomes : [];
  return Card(`staff/cases/workflow/${id}`, [
    textNode(`staff/cases/workflow/${id}/heading`, S.RECORDS, "staff-section-title"),
    notes.length ? textNode(`staff/cases/workflow/${id}/notes`, notes.map((row) => stringValue(objectValue(row)?.text)).join(" · "), "staff-muted") : null,
    entryNode(`staff/cases/workflow/${id}/note`, note, (value) => { state.drafts[noteKey] = value; }, S.OPERATOR_REASON),
    target ? staffPress(`staff/cases/workflow/${id}/note/save`, S.RECORDS, session, recordsRequest("note", { case: target, text: note }), { variant: "ghost", disabled: !note.trim() }) : null,
    entryNode(`staff/cases/workflow/${id}/status`, status, (value) => { state.drafts[statusKey] = value; }, S.STATUS),
    target ? staffPress(`staff/cases/workflow/${id}/status/save`, S.STATUS, session, recordsRequest("status", { case: target, value: status, recipients: caseAccountIds(item) }), { variant: "ghost" }) : null,
    recipientControls(item, selectedRecipients, state),
    target ? outcomeFields(session, item, target, selectedRecipients) : null,
    statuses.length ? textNode(`staff/cases/workflow/${id}/statuses`, statuses.map((row) => stringValue(objectValue(row)?.value)).join(" · "), "staff-mono") : null,
    outcomes.length ? textNode(`staff/cases/workflow/${id}/outcomes`, outcomes.map((row) => stringValue(objectValue(row)?.value)).join(" · "), "staff-mono") : null,
  ].filter(Boolean) as UiNode[], { cls: ["staff-outcome"] });
}

function entryNode(id: string, value: string, save: (value: string) => void, caption: string): UiNode {
  return entry(id, value, (next) => { save(next); return undefined; }, { label: caption });
}

function recipientsFor(item: StaffCase, state: ReturnType<typeof staffLocal>): string[] {
  return caseAccountIds(item).filter((id) => state.drafts[`recipient:${caseId(item)}:${id}`] !== "off");
}

function recipientControls(item: StaffCase, selected: string[], state: ReturnType<typeof staffLocal>): UiNode | null {
  const ids = caseAccountIds(item);
  if (!ids.length) return null;
  return Stack(`staff/cases/recipients/${caseId(item)}`, ids.map((id, index) => localPress(`staff/cases/recipient/${caseId(item)}/${index}`, id, () => { state.drafts[`recipient:${caseId(item)}:${id}`] = selected.includes(id) ? "off" : "on"; }, { variant: selected.includes(id) ? "selected" : "default" })), { cls: ["staff-action-row"], gap: 4, wrap: true });
}

function outcomeFields(session: StaffSession, item: StaffCase, target: StaffRef, recipients: string[]): UiNode {
  const state = staffLocal(session);
  const id = caseId(item);
  const valueKey = `outcome:${id}:value`;
  const reasonKey = `outcome:${id}:reason`;
  const labelKey = `outcome:${id}:label`;
  const value = state.drafts[valueKey] ?? item.outcome?.label ?? "";
  const reason = state.drafts[reasonKey] ?? item.outcome?.reason ?? "";
  const label = state.drafts[labelKey] ?? item.outcome?.duration ?? "";
  return Stack(`staff/cases/outcome/${id}`, [textNode(`staff/cases/outcome/${id}/heading`, S.OUTCOME, "staff-section-title"), entryNode(`staff/cases/outcome/${id}/value`, value, (next) => { state.drafts[valueKey] = next; }, S.OUTCOME), entryNode(`staff/cases/outcome/${id}/label`, label, (next) => { state.drafts[labelKey] = next; }, S.OUTCOME_LABEL), entryNode(`staff/cases/outcome/${id}/reason`, reason, (next) => { state.drafts[reasonKey] = next; }, S.OPERATOR_REASON), textNode(`staff/cases/outcome/${id}/recipients`, recipients.join(" · "), "staff-mono"), staffPress(`staff/cases/outcome/${id}/save`, S.SAVE_OUTCOME, session, recordsRequest("outcome", { case: target, value, reason, label, recipients }), { variant: "primary", disabled: !value.trim() })], { cls: ["staff-action-row"], gap: 4, wrap: true });
}

function eventMatchesRef(event: StaffEvent, key: string): boolean {
  const id = key.split(":").slice(-1)[0];
  return [event.id, event.target, event.targetRef?.id, ...(event.targetRefs ?? []).map((ref) => ref.id), event.accountId, event.actorMind, event.actorBody].some((value) => value !== undefined && String(value) === id);
}

function textNode(id: string, value: unknown, cls?: string): UiNode {
  return text(id, value, cls ? [cls] : undefined);
}
