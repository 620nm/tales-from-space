import type { Json, UiEvent, UiNode } from "@lunatic/ui";
import { Card, Divider, Field, LabeledList, Section, Stack, Table, Tabs } from "@lunatic/ui";
import { bind, entry, press, select, text } from "../../view";
import { freezeReference, localButton, nativePress, staffRequest } from "../shared/actions";
import type { StaffEntity, StaffEvent, StaffInspection, StaffProperty, StaffRef, StaffSession } from "../model";
import { label, profileFor, propertyValue } from "../model";
import { caseAnchorRefs, caseId, contextQuery, contextQueryAnchor, contextRows, pageFor, responseProfileFor } from "../cases/records";
import { createCasePress, profileActionCard, staffLocal } from "../actions";
import * as S from "../strings";
import { refKey } from "../../refs";
import { rememberReviewTarget } from "./review";
import { liveState } from "./state";
import { propertyDraftJson, propertyOptionChoices, propertyOptionDraft } from "../shared/property-values";

export function liveInspector(session: StaffSession, entity: StaffEntity | null): UiNode {
  const state = liveState(session);
  if (!entity) {
    return Card("staff/live/inspector", [textNode("staff/live/no-target", S.SELECT_TARGET, "staff-muted")], { cls: ["staff-inspector"] });
  }
  if (entity.readOnly && state.inspector === "edit") state.inspector = "read";
  const tabs = [
    { key: "read", label: S.READ, selected: state.inspector === "read", event: bind("staff/live/tab/read", () => { state.inspector = "read"; return undefined; }) },
    ...(!entity.readOnly ? [{ key: "edit", label: S.EDIT, selected: state.inspector === "edit", event: bind("staff/live/tab/edit", () => { state.inspector = "edit"; return undefined; }) }] : []),
    { key: "audit", label: S.AUDIT, selected: state.inspector === "audit", event: bind("staff/live/tab/audit", () => { state.inspector = "audit"; return undefined; }) },
  ];
  const inspection = session.inspector
    && session.inspector.target.round === entity.ref.round
    && session.inspector.target.kind === entity.ref.kind
    && session.inspector.target.id === entity.ref.id
    ? session.inspector
    : null;
  return Card("staff/live/inspector", [
    Stack("staff/live/inspector/head", [
      textNode("staff/live/inspector/kicker", S.INSPECTOR, "staff-eyebrow"),
      textNode("staff/live/inspector/name", entity.name, "staff-target-name"),
      textNode("staff/live/inspector/id", `${entity.kind} · ${entity.id}`, "staff-mono"),
    ], { cls: ["staff-inspector-heading"], gap: 3 }),
    inspection?.tombstone ? textNode("staff/live/inspector/tombstone", S.TOMBSTONE, "staff-warning") : null,
    Tabs("staff/live/inspector/tabs", [
      ...tabs,
    ], { cls: ["staff-inspector-tabs"] }),
    state.inspector === "edit"
      ? editInspector(session, entity, inspection)
      : state.inspector === "audit"
        ? auditInspector(session, entity, inspection)
        : readInspector(session, entity, inspection),
  ].filter(Boolean) as UiNode[], { cls: ["staff-inspector"] });
}

function intervention(session: StaffSession, entity: StaffEntity): UiNode {
  const state = liveState(session);
  const destructive = (verb: "kill" | "delete" | "gib", caption: string): UiNode => {
    const enabled = capability(entity, verb);
    return localButton(`staff/live/review/${verb}`, caption, () => {
      rememberReviewTarget(session, entity);
      state.review = { verb, target: freezeReference(entity.ref) };
    }, { variant: "danger", disabled: !enabled, cls: [`staff-action-${verb}`] });
  };
  const reason = (action: string): UiNode | null => capability(entity, action)
    ? null
    : textNode(`staff/live/intervene/reason/${action}`, entity.capabilityReasons?.[action] ?? S.NO_CONTROLS, "staff-muted");
  return Section("staff/live/intervene", S.INTERVENE, [
    Stack("staff/live/intervene/primary", [
      nativePress("staff/live/freeze", entity.frozen ? S.UNFREEZE : S.FREEZE, session, { kind: "freeze", target: entity.id, on: !entity.frozen }, { variant: entity.frozen ? "selected" : "primary", disabled: !capability(entity, "freeze") }),
      nativePress("staff/live/restore", S.RESTORE, session, { kind: "edit", edit: { kind: "restore", target: entity.id } }, { variant: "default", disabled: !capability(entity, "restore") }),
      nativePress("staff/live/drive", session.driving === entity.id ? S.RELEASE : S.DRIVE, session, { kind: session.driving === entity.id ? "release" : "drive", target: entity.id }, { variant: "ghost", disabled: !capability(entity, "drive") }),
    ], { cls: ["staff-action-row"], gap: 5, wrap: true }),
    Stack("staff/live/intervene/destructive", [destructive("kill", S.KILL), destructive("delete", S.DELETE), destructive("gib", S.GIB)], { cls: ["staff-action-row", "staff-destructive"], gap: 5, wrap: true }),
    textNode("staff/live/intervene/explanation", S.EXACT_TARGET_ACTIONS, "staff-muted"),
    reason("freeze"), reason("restore"), reason("drive"), reason("kill"), reason("delete"), reason("gib"),
  ].filter(Boolean) as UiNode[], { cls: ["staff-intervene"] });
}

function readInspector(session: StaffSession, entity: StaffEntity, inspection: StaffInspection | null): UiNode {
  const profile = entity.accountId
    ? responseProfileFor(session, entity.accountId)
      ?? profileFor(session, entity.accountId)
      ?? (entity.profileCard?.id === entity.accountId ? { ...entity.profileCard, role: S.RECORD_ONLY } : null)
    : entity.profileCard
      ? { ...entity.profileCard, role: S.RECORD_ONLY }
      : null;
  const refs = uniqueRefs([...(entity.refs ?? []), ...(inspection?.related ?? [])]);
  return {
    id: "staff/live/read",
    type: "column",
    class: ["staff-inspector-body"],
    children: [
      targetSummary("staff/live/read/target", entity),
      entity.readOnly ? null : intervention(session, entity),
      profile
        ? profileActionCard("staff/live/read/profile", session, profile, `${S.ACCOUNT_PROFILE} · ${S.MIND} ${label(entity.mindId)}`)
        : textNode("staff/live/read/no-profile", S.NO_ACCOUNT, "staff-muted"),
      Section("staff/live/read/properties", S.PROPERTIES, [LabeledList("staff/live/read/values", readRows(entity, inspection))]),
      Section("staff/live/read/case", S.RECORDS, [
        createCasePress("staff/live/read/case/create", S.CREATE_CASE, session, entity.ref, { variant: "ghost" }),
      ]),
      refs.length
        ? Section("staff/live/read/related", S.RELATED, refs.map((ref, index) => nativePress(`staff/live/read/ref/${index}`, refCaption(session, ref), session, { kind: "inspect", target: ref }, { variant: "ghost", cls: ["staff-related-ref"] })))
        : null,
    ].filter(Boolean) as UiNode[],
  };
}

function editInspector(session: StaffSession, entity: StaffEntity, inspection: StaffInspection | null): UiNode {
  const state = liveState(session);
  const properties = disclosedProperties(entity, inspection);
  return {
    id: "staff/live/edit",
    type: "column",
    class: ["staff-inspector-body"],
    children: [
      targetSummary("staff/live/edit/target", entity),
      Section("staff/live/edit/properties", S.PROPERTIES, properties.length
        ? properties.map((property, index) => propertyField(`staff/live/edit/property/${index}`, session, entity, property))
        : [textNode("staff/live/edit/no-properties", S.NO_PROPERTIES, "staff-muted")]),
      Divider("staff/live/edit/divider"),
      coordinates(session, entity, state),
      Stack("staff/live/edit/move", [
        editPress("staff/live/edit/move/action", S.MOVE, session, state, { kind: "move", target: entity.id }, { variant: "ghost", disabled: !capability(entity, "move") }),
        editPress("staff/live/edit/duplicate", S.DUPLICATE, session, state, { kind: "duplicate", target: entity.id }, { variant: "ghost", disabled: !capability(entity, "duplicate") }),
      ], { cls: ["staff-action-row"], gap: 5 }),
    ],
  };
}

function coordinates(_session: StaffSession, entity: StaffEntity, state: ReturnType<typeof liveState>): UiNode {
  const pos = entity.pos;
  const targetKey = `${entity.ref.round}:${entity.ref.kind}:${entity.ref.id}`;
  if (state.editTarget !== targetKey) {
    state.editTarget = targetKey;
    state.spawnX = pos ? String(pos.x) : "0";
    state.spawnY = pos ? String(pos.y) : "0";
  }
  return Stack("staff/live/edit/coordinates", [
    entry(`staff/live/edit/x/${entity.id}`, state.spawnX, (value) => { state.spawnX = value; return undefined; }, { label: S.X, cls: ["staff-coordinate"] }),
    entry(`staff/live/edit/y/${entity.id}`, state.spawnY, (value) => { state.spawnY = value; return undefined; }, { label: S.Y, cls: ["staff-coordinate"] }),
  ], { cls: ["staff-coordinate-row"], gap: 4 });
}

function coordinateValue(state: ReturnType<typeof liveState>): Json {
  const number = (value: string): number => Number.isFinite(Number(value)) ? Number(value) : 0;
  return { x: number(state.spawnX), y: number(state.spawnY) };
}

function editPress(
  id: string,
  caption: unknown,
  session: StaffSession,
  state: ReturnType<typeof liveState>,
  edit: Record<string, Json>,
  opts: Parameters<typeof press>[3],
): UiNode {
  return press(id, caption, () => staffRequest(session, { kind: "edit", edit: { ...edit, pos: coordinateValue(state) } }), opts);
}

function disclosedProperties(entity: StaffEntity, inspection: StaffInspection | null): StaffProperty[] {
  const payload = inspection?.payload ?? entity.payload ?? {};
  const descriptors = payload.properties;
  if (Array.isArray(descriptors)) {
    return descriptors.map(propertyValue).filter((item): item is StaffProperty => !!item);
  }
  const fields = payload.fields;
  if (fields && typeof fields === "object" && !Array.isArray(fields)) {
    return Object.entries(fields).map(([path, raw]) => {
      const field = raw && typeof raw === "object" && !Array.isArray(raw) ? raw as Record<string, unknown> : {};
      return propertyValue({ path, label: typeof field.label === "string" ? field.label : path, type: field.type, value: field.value, options: field.options, nullable: field.nullable, editable: field.editable === true, reason: typeof field.reason === "string" ? field.reason : undefined })
        ?? { path, label: typeof field.label === "string" ? field.label : path, type: propertyType(field.type, field.value), editable: field.editable === true, reason: typeof field.reason === "string" ? field.reason : undefined };
    });
  }
  if (entity.properties?.length) return entity.properties;
  return [];
}

function propertyType(value: unknown, current: unknown): StaffProperty["type"] {
  if (value === "string" || value === "text") return "string";
  if (value === "integer") return "integer";
  if (value === "number" || typeof current === "number") return "number";
  if (value === "boolean" || typeof current === "boolean") return "boolean";
  if (value === "enum") return "enum";
  if (value === "reference") return "json";
  if (value === "json") return "json";
  return "text";
}

function readRows(entity: StaffEntity, inspection: StaffInspection | null): { label: string; value: string }[] {
  const rows: { label: string; value: string }[] = [
    { label: S.STATE, value: label(entity.state) },
    { label: S.LOCATION, value: label(entity.location) },
    { label: S.MIND, value: label(entity.mindId) },
    { label: S.BODY, value: label(entity.bodyId) },
  ];
  const payload = inspection?.payload ?? entity.payload ?? {};
  for (const [path, value] of Object.entries(payload)) {
    if (["entity_id", "kind", "name", "position", "properties", "fields"].includes(path) || value === null || typeof value === "object") continue;
    if (rows.some((row) => row.label === path)) continue;
    rows.push({ label: path, value: String(value) });
  }
  return rows;
}

function auditInspector(session: StaffSession, entity: StaffEntity, inspection: StaffInspection | null): UiNode {
  const state = liveState(session);
  const all = [...(entity.history ?? []), ...(inspection?.audit ?? []), ...(session.audit ?? []), ...(session.events ?? [])];
  const rows = [...new Map(all.filter((event) => eventMatchesEntity(event, entity.ref)).map((event) => [refKey(event.reference), event])).values()]
    .filter((event) => !state.query || `${event.action} ${event.target} ${event.actor}`.toLowerCase().includes(state.query.toLowerCase()));
  const anchor = contextQueryAnchor(session);
  const context = anchor && sameRef(anchor, entity.ref) ? contextRows(session, anchor) : [];
  const contextPage = anchor && sameRef(anchor, entity.ref) ? pageFor(session, "context") : { items: [], next: null, error: null, loading: false };
  return {
    id: "staff/live/audit",
    type: "column",
    class: ["staff-inspector-body"],
    children: [
      targetSummary("staff/live/audit/target", entity),
      entry("staff/live/audit/filter", state.query, (query) => { state.query = query; return undefined; }, { label: S.INSPECT, cls: ["staff-audit-filter"], debounceMs: 160 }),
      rows.length
        ? Table("staff/live/audit/table", ["auto", "1fr", "1fr", "1fr"], rows.map((event) => [
          textNode(`staff/live/audit/${event.id}/time`, label(event.time, S.TIME), "staff-mono"),
          textNode(`staff/live/audit/${event.id}/action`, `${event.action} · ${event.target ?? entity.id}`, "staff-audit-action"),
          textNode(`staff/live/audit/${event.id}/result`, label(event.result, S.RESULT), "staff-muted"),
          textNode(`staff/live/audit/${event.id}/delta`, `${label(event.before)} → ${label(event.after)}`, "staff-mono"),
        ]), { header: [S.TIME, S.ACTION_TARGET, S.RESULT, S.CURRENT] })
        : textNode("staff/live/audit/empty", S.NO_HISTORY, "staff-muted"),
      openCasesButton(session, entity),
      ...(context.length || contextPage.error || contextPage.next
        ? [Section("staff/live/audit/context", S.HISTORY, [
          context.length
            ? Table("staff/live/audit/context/table", ["auto", "1fr", "1fr", "1fr"], context.map((event) => [
              textNode(`staff/live/audit/context/${event.id}/time`, label(event.time, S.TIME), "staff-mono"),
              textNode(`staff/live/audit/context/${event.id}/action`, `${event.action} · ${event.target ?? entity.id}`, "staff-audit-action"),
              textNode(`staff/live/audit/context/${event.id}/actor`, event.actor ?? event.actorMind ?? S.RECORD_ONLY, "staff-muted"),
              textNode(`staff/live/audit/context/${event.id}/ref`, refCaption(session, event.reference), "staff-mono"),
            ]), { header: [S.TIME, S.ACTION_TARGET, S.ACTOR, S.EXACT_EVENT] })
            : textNode("staff/live/audit/context/empty", contextPage.error ?? S.NO_HISTORY, "staff-muted"),
          contextPage.error ? textNode("staff/live/audit/context/error", contextPage.error, "staff-warning") : null,
          contextPage.next && anchor ? nativePress("staff/live/audit/context/load-more", S.ALL_RECORDS, session, contextQuery(session, anchor, contextPage.next), { variant: "ghost" }) : null,
        ].filter(Boolean) as UiNode[], { cls: ["staff-live-context"] })]
        : []),
    ],
  };
}

function openCasesButton(session: StaffSession, entity: StaffEntity): UiNode {
  return press("staff/live/audit/open-cases", S.OPEN_CASES, () => {
    const state = staffLocal(session);
    state.workspace = "cases";
    state.selectedRef = freezeReference(entity.ref);
    state.recordFilter = null;
    const related = session.cases.find((item) => caseAnchorRefs(session, item).some((anchor) => sameRef(anchor, entity.ref)));
    if (related) state.selectedCaseId = caseId(related);
    return staffRequest(session, contextQuery(session, entity.ref));
  }, { variant: "ghost" });
}

function uniqueRefs(refs: StaffEntity["refs"]): NonNullable<StaffEntity["refs"]> {
  return [...new Map((refs ?? []).map((ref) => [`${ref.round}:${ref.kind}:${ref.id}`, ref])).values()];
}

function eventMatchesEntity(event: StaffEvent, entity: StaffRef): boolean {
  const targets = [event.targetRef, ...(event.targetRefs ?? [])];
  if (targets.some((target) => sameRef(target, entity))) return true;
  if (entity.kind === "body") return event.actorBody === entity.id;
  if (entity.kind === "mind") return event.actorMind === entity.id;
  if (entity.kind === "account") return event.accountId === entity.id;
  return entity.kind === "entity" && event.target === entity.id;
}

function sameRef(left: StaffRef | undefined, right: StaffRef): boolean {
  return !!left && left.round === right.round && left.kind === right.kind && left.id === right.id;
}

function textNode(id: string, value: unknown, cls?: string): UiNode {
  return text(id, value, cls ? [cls] : undefined);
}

function refCaption(session: StaffSession, ref: StaffRef): string {
  const profile = ref.kind === "account" ? profileFor(session, ref.id) ?? responseProfileFor(session, ref.id) : null;
  return ref.kind === "account"
    ? `${profile?.username ?? S.NO_ACCOUNT} · ${shortId(ref.id)}`
    : `${ref.label ?? ref.kind} · ${ref.id}`;
}

function shortId(id: string): string {
  return id.length > 14 ? `${id.slice(0, 6)}…${id.slice(-4)}` : id;
}

function targetSummary(id: string, entity: StaffEntity): UiNode {
  const details = entity.role ? `${entity.id} · ${entity.role}` : entity.id;
  return Card(id, [
    Stack(`${id}/heading`, [
      textNode(`${id}/kind`, entity.kind.toUpperCase(), "staff-eyebrow"),
      textNode(`${id}/name`, entity.name, "staff-target-name"),
    ], { cls: ["staff-target-heading"], gap: 5, align: "center" }),
    textNode(`${id}/identity`, details, "staff-mono"),
    textNode(`${id}/state`, label(entity.state, S.SELECT_TARGET), entity.frozen ? "staff-good" : "staff-muted"),
  ], { cls: ["staff-target-summary"] });
}

function propertyField(id: string, session: StaffSession, target: StaffEntity, property: StaffProperty): UiNode {
  const state = liveState(session);
  const value = property.value === null || property.value === undefined ? "" : String(property.value);
  const choiceValue = property.type === "enum" && property.options?.length
    ? propertyOptionDraft(property.value, property.options)
    : value;
  const draftKey = `${target.ref.round}:${target.ref.kind}:${target.ref.id}:${property.path}`;
  const draft = state.drafts[draftKey] ?? choiceValue;
  const editable = capability(target, "property") && property.editable === true;
  const callback = (next: string): Json | undefined => {
    state.drafts[draftKey] = next;
    return undefined;
  };
  const inferredBoolean = property.type === undefined && typeof property.value === "boolean";
  const selectControl = property.type === "boolean" || inferredBoolean
    || (property.type === "enum" && property.options?.length);
  let control: UiNode;
  if (property.type === "boolean" || inferredBoolean) {
    control = selectNode(id, draft, [{ value: "false", text: S.FALSE }, { value: "true", text: S.TRUE }], callback, !editable);
  } else if (property.type === "enum" && property.options?.length) {
    control = selectNode(id, draft, propertyOptionChoices(property.options), callback, !editable);
  } else {
    control = entry(id, draft, callback, { cls: ["staff-property-control"], disabled: !editable });
  }
  const children: UiNode[] = [
    Field(`${id}/label`, property.label ?? property.path, control),
    property.unit ? textNode(`${id}/unit`, property.unit, "staff-unit") : textNode(`${id}/current`, `${S.CURRENT} · ${value || label(undefined)}`, "staff-current"),
  ];
  if (!editable) children.push(textNode(`${id}/reason`, property.reason ?? S.READ_ONLY, "staff-muted"));
  const encodedDraft = editable && state.drafts[draftKey] !== undefined && state.drafts[draftKey] !== choiceValue
    ? jsonValue(draft, property)
    : undefined;
  if (encodedDraft !== undefined) {
    children.push(press(`${id}/apply`, S.APPLY, (event) => {
      if (!capability(target, "property") || property.editable !== true) return undefined;
      const submitted = event.value ?? state.drafts[draftKey] ?? choiceValue;
      const encoded = jsonValue(submitted, property);
      if (encoded === undefined) return undefined;
      return staffRequest(session, {
        kind: "edit",
        edit: { kind: "property", target: target.id, path: property.path, value: encoded },
      });
    }, { variant: "primary", ...(selectControl ? {} : { submit: id }) }));
  }
  return Stack(`${id}/field`, children, { cls: ["staff-property"], gap: 3, align: "center" });
}

function selectNode(
  id: string,
  value: string,
  choices: { value: string; text: unknown }[],
  callback: (value: string) => Json | undefined,
  disabled: boolean,
): UiNode {
  return select(id, value, choices, callback, { cls: ["staff-property-control"], disabled });
}

function jsonValue(value: string, property: StaffProperty): string | undefined {
  return propertyDraftJson(property.type, value, property.options);
}

function capability(entity: StaffEntity, action: string): boolean {
  if (entity.readOnly) return false;
  if (entity.capabilities) return entity.capabilities[action as keyof NonNullable<StaffEntity["capabilities"]>] === true;
  return action === "inspect";
}
