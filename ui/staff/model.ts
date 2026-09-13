import type { GameplayView } from "../model";
import { historicalEventPresentation } from "./shared/presentation";
import { nullablePropertyOptions, parsePropertyOption, type PropertyOption, type PropertyPrimitive, type PropertyType } from "./shared/property-values";

/** Browser-safe representation of a server `u64`. Never coerce this to a number. */
export type DecimalId = string;

/** Public profile ids are stable lowercase hexadecimal keys. */
export type ProfileId = string;

export interface StaffProfile {
  id: ProfileId;
  username: string;
  avatar: "portrait-01" | "portrait-02" | "portrait-03" | "portrait-04" | "unknown";
  role: string;
  warnings?: string[];
  messageCount?: number;
  timeline?: StaffEvent[];
}

/** The native live inspection card contains only public identity fields. */
export interface StaffProfileCard {
  id: ProfileId;
  username: string;
  avatar: StaffProfile["avatar"];
}

/** A wire reference is always round/kind/id; account references are cross-round. */
export interface StaffRef {
  round: string;
  kind: string;
  id: string;
  label?: string;
}

export interface StaffProperty {
  path: string;
  label?: string;
  type?: PropertyType;
  value?: PropertyPrimitive | null;
  unit?: string;
  options?: PropertyOption[];
  nullable?: boolean;
  editable?: boolean;
  reason?: string;
}

export type StaffCapability =
  | "inspect" | "freeze" | "restore" | "drive" | "kill" | "delete"
  | "gib" | "move" | "duplicate" | "property";

/** One source row. `id` is the durable database cursor; `sourceSeq` is separate. */
export interface StaffEvent {
  reference: StaffRef;
  id: DecimalId;
  sourceSeq?: DecimalId;
  eventType?: string;
  serverId?: string;
  createdAtMs?: number;
  time?: string;
  tick?: number;
  action: string;
  target?: string;
  targetRef?: StaffRef;
  targetRefs?: StaffRef[];
  actor?: string;
  actorMind?: DecimalId;
  actorBody?: DecimalId;
  accountId?: ProfileId;
  occupantAccount?: ProfileId;
  occupantMind?: DecimalId;
  bodyRef?: StaffRef;
  accountRef?: StaffRef;
  mindRef?: StaffRef;
  operator?: string;
  adminProfileId?: ProfileId;
  adminOrigin?: StaffAdminOrigin;
  admin?: boolean;
  controller?: string;
  operationId?: string;
  control?: StaffControlMetadata;
  payload?: unknown;
  refs?: StaffRef[];
  name?: string;
  deleted?: boolean;
  result?: string;
  reason?: string;
  before?: string;
  after?: string;
  includedThrough?: string;
  caseId?: DecimalId;
}

export interface StaffAdminOrigin {
  profile: ProfileId;
  staffAccount?: ProfileId;
  requestId?: string;
  interface?: string;
}

export interface StaffControlMetadata {
  sessionId?: string;
  origin?: string;
  requestId?: string;
}

export interface StaffEntity {
  /** Decimal `bevy::Entity` bits, retained as text across the browser edge. */
  id: DecimalId;
  ref: StaffRef;
  kind: string;
  name: string;
  role?: string;
  state?: string;
  location?: string;
  pos?: { x: number; y: number; z?: number };
  accountId?: ProfileId;
  mindId?: DecimalId;
  bodyId?: DecimalId;
  live?: boolean;
  frozen?: boolean;
  editable?: boolean;
  deleted?: boolean;
  properties?: StaffProperty[];
  refs?: StaffRef[];
  history?: StaffEvent[];
  payload?: Record<string, unknown>;
  profileCard?: StaffProfileCard;
  /** Set when the selected reference cannot safely drive a live mutation. */
  readOnly?: boolean;
  capabilities?: Partial<Record<StaffCapability, boolean>>;
  capabilityReasons?: Record<string, string>;
}

export interface StaffCase {
  reference: StaffRef;
  id: DecimalId;
  title: string;
  createdAt?: number;
  status?: string;
  assignee?: ProfileId;
  /** Normalized views of the canonical record reference arrays. */
  anchorHistory: StaffRef[];
  addressedEvents: StaffRef[];
  attachments: StaffRef[];
  notes: Record<string, unknown>[];
  statuses: Record<string, unknown>[];
  outcomes: Record<string, unknown>[];
  /** Resolved display conveniences populated only from canonical refs. */
  entityRefs?: StaffRef[];
  accountIds?: ProfileId[];
  mindIds?: DecimalId[];
  eventIds?: DecimalId[];
  outcome?: { label: string; duration?: string; accountIds?: ProfileId[]; reason?: string };
}

export interface StaffInspection {
  target: StaffRef;
  found: boolean;
  tombstone: boolean;
  payload: Record<string, unknown> | null;
  related: StaffRef[];
  audit: StaffEvent[];
}

/** The pack-owned payload emitted by the native staff adapter. */
export interface StaffPayload {
  current_round?: string;
  revision?: string;
  contact_updates?: Array<{ account: StaffRef; conversation: StaffRef; change: StaffRef }>;
  selected?: StaffInspection | null;
  audit?: StaffEvent[];
  profiles?: StaffProfile[];
  world?: { entities?: StaffEntity[] };
  records?: {
    cases?: StaffCase[];
    response?: StaffRecordResponse | null;
  };
  roster?: {
    items?: StaffCatalogEntry[];
    structures?: StaffCatalogEntry[];
    machines?: StaffCatalogEntry[];
    mobs?: StaffCatalogEntry[];
    bodies?: StaffCatalogEntry[];
  };
  workspace?: "live" | "cases";
  station?: { name?: string; shift?: string; clock?: string; status?: string };
  error?: string;
}

/** One native prototype row accepted by the staff spawn action. */
export interface StaffCatalogEntry {
  kind: string;
  prototype: string;
  name: string;
  default_properties: Record<string, unknown>;
  properties: StaffCatalogProperty[];
}

/** Native catalog descriptors retain the placement schema's numeric bounds. */
export interface StaffCatalogProperty {
  path: string;
  label: string;
  type: string;
  value?: string | number | boolean | null;
  options?: Array<string | number | boolean | null | Record<string, unknown>>;
  nullable?: boolean;
  editable: boolean;
  min?: number;
  max?: number;
  step?: number;
}

/** One session-local durable query envelope from the native records adapter. */
export interface StaffRecordResponse {
  request_id: string;
  query: unknown;
  refs: StaffRef[];
  cursor?: string | null;
  result: Record<string, unknown> | null;
  error?: string | null;
}

/** Native shell metadata is separate from the pack-owned payload. */
export interface StaffState {
  allowed: boolean;
  active: boolean;
  revision: string;
  round_id: string;
  frozen: boolean;
  control_held: boolean;
  operator?: StaffProfile | null;
  camera?: { x: number; y: number };
  driving?: DecimalId;
  payload?: StaffPayload | string | null;
}

export interface StaffSession extends StaffPayload {
  allowed: boolean;
  active: boolean;
  revision: string;
  roundId: string;
  operator: StaffProfile | null;
  frozen: boolean;
  hold: boolean;
  camera: { x: number; y: number } | null;
  driving: DecimalId | null;
  inspector: StaffInspection | null;
  entities: StaffEntity[];
  profiles: StaffProfile[];
  cases: StaffCase[];
  events: StaffEvent[];
  audit: StaffEvent[];
}

const DECIMAL = /^(0|[1-9][0-9]*)$/;
const PROFILE = /^[0-9a-f]{64}$/;
const STAFF_IDENTIFIER = /^[A-Za-z0-9_.:/-]+$/;
const MAX_U64 = "18446744073709551615";
const AVATARS = new Set(["portrait-01", "portrait-02", "portrait-03", "portrait-04", "unknown"]);
const DECIMAL_REF_KINDS = new Set([
  "body", "case", "container", "conversation", "entity", "event", "item", "machine", "message", "mind", "record", "structure",
]);

export function isDecimalId(value: unknown): value is DecimalId {
  if (typeof value !== "string" || !DECIMAL.test(value)) return false;
  return value.length < MAX_U64.length || (value.length === MAX_U64.length && value <= MAX_U64);
}

export function isProfileId(value: unknown): value is ProfileId {
  return typeof value === "string" && PROFILE.test(value);
}

/** Match the core StaffRef identifier grammar before any typed-id rule. */
export function isStaffIdentifier(value: unknown, max = 128): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= max && STAFF_IDENTIFIER.test(value);
}

/** Known live and durable ids are decimal; future kinds stay opaque. */
export function isStaffRefId(kind: string, value: unknown): value is string {
  return DECIMAL_REF_KINDS.has(kind) ? isDecimalId(value) : isStaffIdentifier(value);
}

/** Round ids follow the core's bounded text rule and remain exact across rounds. */
export function isStaffRound(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= 128 && !/[\x00-\x1f\x7f]/.test(value);
}

const object = (value: unknown): Record<string, unknown> | null =>
  value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;

function avatar(value: unknown): StaffProfile["avatar"] {
  return typeof value === "string" && AVATARS.has(value)
    ? value as StaffProfile["avatar"]
    : "unknown";
}

export function profileCardValue(value: unknown): StaffProfileCard | null {
  const raw = object(value);
  if (!raw || !isProfileId(raw.id) || typeof raw.username !== "string" || !raw.username) return null;
  return { id: raw.id, username: raw.username, avatar: avatar(raw.avatar) };
}

function refValue(value: unknown): StaffRef | null {
  const raw = object(value);
  if (!raw || typeof raw.round !== "string" || typeof raw.kind !== "string" || !raw.kind || typeof raw.id !== "string" || !raw.id) return null;
  if ((raw.kind === "account") !== (raw.round === "")) return null;
  if (!isStaffIdentifier(raw.kind, 96) || !isStaffRefId(raw.kind, raw.id)
    || (raw.round !== "" && !isStaffRound(raw.round))
    || (raw.kind === "account" && !isProfileId(raw.id))) return null;
  return { round: raw.round, kind: raw.kind, id: raw.id, ...(typeof raw.label === "string" ? { label: raw.label } : {}) };
}

const refs = (value: unknown): StaffRef[] =>
  Array.isArray(value) ? value.map(refValue).filter((item): item is StaffRef => !!item) : [];

function profileValue(value: unknown): StaffProfile | null {
  const raw = object(value);
  if (!raw || !isProfileId(raw.id) || typeof raw.username !== "string" || typeof raw.role !== "string") return null;
  const warnings = Array.isArray(raw.warnings) ? raw.warnings.filter((item): item is string => typeof item === "string") : undefined;
  const messageCount = typeof raw.message_count === "number" && Number.isSafeInteger(raw.message_count) && raw.message_count >= 0 ? raw.message_count : undefined;
  return { id: raw.id, username: raw.username, avatar: avatar(raw.avatar), role: raw.role, ...(warnings?.length ? { warnings } : {}), ...(messageCount === undefined ? {} : { messageCount }) };
}

export function propertyValue(value: unknown): StaffProperty | null {
  const raw = object(value);
  if (!raw || typeof raw.path !== "string" || !raw.path) return null;
  const kind = raw.type;
  const type = kind === "string" || kind === "integer" || kind === "number" || kind === "boolean" || kind === "enum"
    || kind === "text" || kind === "json" || kind === "reference"
    ? kind
    : typeof raw.value === "number" ? "number"
      : typeof raw.value === "boolean" ? "boolean"
        : "string";
  const property: StaffProperty = { path: raw.path, ...(typeof raw.label === "string" ? { label: raw.label } : {}), ...(type ? { type } : {}), ...(typeof raw.nullable === "boolean" ? { nullable: raw.nullable } : {}) };
  if (raw.value === null) property.value = null;
  else if (typeof raw.value === "string" || typeof raw.value === "boolean" || (typeof raw.value === "number" && Number.isFinite(raw.value))) property.value = raw.value;
  if (typeof raw.unit === "string") property.unit = raw.unit;
  if (Array.isArray(raw.options)) {
    const options = raw.options.map(parsePropertyOption).filter((option): option is PropertyOption => option !== undefined);
    if (options.length) property.options = nullablePropertyOptions(property.nullable && type === "enum", options);
  }
  if (typeof raw.editable === "boolean") property.editable = raw.editable;
  if (typeof raw.reason === "string") property.reason = raw.reason;
  return property;
}

const decimalValue = (value: unknown): DecimalId | null => {
  if (isDecimalId(value)) return value;
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? String(value) : null;
};

const optionalRef = (value: unknown, round: string): StaffRef | null => {
  if (value === undefined || value === null) return null;
  const reference = refValue(value);
  void round;
  return reference;
};

/** Parse the native HistoricalRow shape; its cursor remains distinct from source seq. */
function eventValue(value: unknown, round: string): StaffEvent | null {
  const raw = object(value);
  const reference = refValue(raw?.reference);
  if (!raw || !reference || reference.kind !== "event"
    || typeof raw.event_type !== "string" || typeof raw.server_id !== "string"
    || typeof raw.created_at_ms !== "number" || !Number.isSafeInteger(raw.created_at_ms)
    || typeof raw.tick !== "number" || !Number.isSafeInteger(raw.tick) || raw.tick < 0
    || !Object.hasOwn(raw, "payload") || !Array.isArray(raw.refs)
    || typeof raw.deleted !== "boolean") return null;
  const rowRefs = raw.refs.map(refValue);
  if (rowRefs.some((item) => !item)) return null;
  const refsValue = rowRefs as StaffRef[];
  const bodyRef = optionalRef(raw.body, round);
  const accountRef = optionalRef(raw.account, round);
  const mindRef = optionalRef(raw.mind, round);
  if ((raw.body !== undefined && raw.body !== null && !bodyRef)
    || (raw.account !== undefined && raw.account !== null && !accountRef)
    || (raw.mind !== undefined && raw.mind !== null && !mindRef)) return null;
  const payload = object(raw.payload);
  const actorMind = decimalValue(raw.occupant_mind);
  const occupantAccount = isProfileId(raw.occupant_account) ? raw.occupant_account : undefined;
  if (raw.occupant_account !== undefined && raw.occupant_account !== null && !occupantAccount) return null;
  if (raw.actor !== undefined && raw.actor !== null && typeof raw.actor !== "string") return null;
  if (raw.controller !== undefined && raw.controller !== null && typeof raw.controller !== "string") return null;
  if (raw.operation_id !== undefined && raw.operation_id !== null && typeof raw.operation_id !== "string") return null;
  if (raw.name !== undefined && raw.name !== null && typeof raw.name !== "string") return null;
  const adminOrigin = object(raw.admin_origin);
  const adminProfileId = adminOrigin && isProfileId(adminOrigin.profile) ? adminOrigin.profile : undefined;
  if (raw.admin_origin !== undefined && raw.admin_origin !== null && (!adminOrigin || !adminProfileId)) return null;
  if (adminOrigin && ((adminOrigin.staff_account !== undefined && !isProfileId(adminOrigin.staff_account))
    || (adminOrigin.request_id !== undefined && typeof adminOrigin.request_id !== "string")
    || (adminOrigin.interface !== undefined && typeof adminOrigin.interface !== "string"))) return null;
  const control = object(raw.control);
  if (raw.control !== undefined && raw.control !== null && (!control
    || (control.session_id !== undefined && typeof control.session_id !== "string")
    || (control.origin !== undefined && typeof control.origin !== "string")
    || (control.request_id !== undefined && typeof control.request_id !== "string"))) return null;
  const targetRefs = payload?.target_refs;
  if (targetRefs !== undefined && (!Array.isArray(targetRefs) || targetRefs.map(refValue).some((item) => !item))) return null;
  const targetRefList = Array.isArray(targetRefs) ? targetRefs.map(refValue) as StaffRef[] : undefined;
  const sourceSeq = decimalValue(payload?.seq);
  const presentation = historicalEventPresentation(
    raw.event_type,
    payload,
    refsValue,
    (item) => optionalRef(item, round),
    raw.created_at_ms,
  );
  const action = typeof payload?.action === "string" ? payload.action : raw.event_type;
  const event: StaffEvent = {
    reference,
    id: reference.id,
    eventType: raw.event_type,
    serverId: raw.server_id,
    createdAtMs: raw.created_at_ms,
    time: presentation.time,
    tick: raw.tick,
    action,
    ...(sourceSeq ? { sourceSeq } : {}),
    ...(presentation.target === undefined ? {} : { target: presentation.target }),
    ...(presentation.targetRef ? { targetRef: presentation.targetRef } : {}),
    ...(targetRefList?.length ? { targetRefs: targetRefList } : {}),
    ...(typeof raw.actor === "string" ? { actor: raw.actor } : {}),
    ...(actorMind ? { actorMind, occupantMind: actorMind } : {}),
    ...(bodyRef ? { bodyRef, actorBody: bodyRef.id } : {}),
    ...(accountRef ? { accountRef, accountId: accountRef.id } : occupantAccount ? { accountId: occupantAccount } : {}),
    ...(occupantAccount ? { occupantAccount } : {}),
    ...(adminProfileId ? {
      adminProfileId,
      adminOrigin: {
        profile: adminProfileId,
        ...(isProfileId(adminOrigin?.staff_account) ? { staffAccount: adminOrigin.staff_account } : {}),
        ...(typeof adminOrigin?.request_id === "string" ? { requestId: adminOrigin.request_id } : {}),
        ...(typeof adminOrigin?.interface === "string" ? { interface: adminOrigin.interface } : {}),
      },
      operator: adminProfileId,
      admin: true,
    } : {}),
    ...(typeof raw.controller === "string" ? { controller: raw.controller } : {}),
    ...(typeof raw.operation_id === "string" ? { operationId: raw.operation_id } : {}),
    ...(control ? {
      control: {
        ...(typeof control.session_id === "string" ? { sessionId: control.session_id } : {}),
        ...(typeof control.origin === "string" ? { origin: control.origin } : {}),
        ...(typeof control.request_id === "string" ? { requestId: control.request_id } : {}),
      },
    } : {}),
    ...(Object.hasOwn(raw, "payload") ? { payload: raw.payload } : {}),
    ...(refsValue.length ? { refs: refsValue } : {}),
    ...(mindRef ? { mindRef } : {}),
    ...(typeof raw.name === "string" ? { name: raw.name } : {}),
    ...(raw.deleted === true ? { deleted: true } : {}),
    ...(typeof payload?.result === "string" ? { result: payload.result } : {}),
    ...(typeof payload?.reason === "string" ? { reason: payload.reason } : {}),
    ...(typeof payload?.before === "string" ? { before: payload.before } : {}),
    ...(typeof payload?.after === "string" ? { after: payload.after } : {}),
    ...(typeof payload?.included_through === "string" ? { includedThrough: payload.included_through } : {}),
    ...(decimalValue(payload?.case_id) ? { caseId: decimalValue(payload?.case_id)! } : {}),
  };
  return event;
}

function entityValue(value: unknown, round: string): StaffEntity | null {
  const raw = object(value);
  if (!raw || !isDecimalId(raw.id) || typeof raw.kind !== "string" || !raw.kind) return null;
  const ref = refValue(raw.ref);
  if (!ref || ref.round !== round || ref.id !== raw.id || ref.kind !== "entity") return null;
  const position = object(raw.position);
  const accountId = raw.account_id === undefined || raw.account_id === null
    ? undefined
    : isProfileId(raw.account_id) ? raw.account_id : null;
  const mindId = raw.mind_id === undefined || raw.mind_id === null
    ? undefined
    : decimalValue(raw.mind_id);
  const bodyId = raw.body_id === undefined || raw.body_id === null
    ? undefined
    : decimalValue(raw.body_id);
  if (accountId === null || (raw.mind_id !== undefined && raw.mind_id !== null && !mindId)
    || (raw.body_id !== undefined && raw.body_id !== null && !bodyId)) return null;
  const entity: StaffEntity = { id: raw.id, ref, kind: raw.kind, name: typeof raw.name === "string" && raw.name ? raw.name : `${raw.kind} · ${raw.id}` };
  if (position && typeof position.x === "number" && Number.isFinite(position.x)
    && typeof position.y === "number" && Number.isFinite(position.y)) {
    entity.pos = { x: position.x, y: position.y, ...(typeof position.z === "number" && Number.isFinite(position.z) ? { z: position.z } : {}) };
  }
  if (accountId) entity.accountId = accountId;
  if (mindId) entity.mindId = mindId;
  if (bodyId) entity.bodyId = bodyId;
  if (typeof raw.live === "boolean") entity.live = raw.live;
  return entity;
}

function caseValue(value: unknown, round: string): StaffCase | null {
  const raw = object(value);
  const reference = refValue(raw?.reference);
  if (!raw || !reference || reference.kind !== "case" || typeof raw.label !== "string") return null;
  const anchorHistory = refs(raw.direct_anchor_history);
  const addressedEvents = refs(raw.case_addressed_events).filter((ref) => ref.kind === "event");
  const attachments = refs(raw.attachments);
  const entityRefs = [...anchorHistory, ...attachments].filter((ref) => ref.kind !== "event");
  const accountIds = attachments.filter((ref) => ref.kind === "account").map((ref) => ref.id).filter(isProfileId);
  const mindIds = attachments.filter((ref) => ref.kind === "mind").map((ref) => ref.id).filter(isDecimalId);
  const eventIds = addressedEvents.map((ref) => ref.id).filter(isDecimalId);
  const statuses = Array.isArray(raw.statuses) ? raw.statuses.filter((item): item is Record<string, unknown> => !!object(item)) : [];
  const outcomes = Array.isArray(raw.outcomes) ? raw.outcomes.filter((item): item is Record<string, unknown> => !!object(item)) : [];
  const latest = outcomes.length ? outcomes[outcomes.length - 1] : undefined;
  const outcome = latest && typeof latest.value === "string" ? { label: latest.value, ...(typeof latest.label === "string" ? { duration: latest.label } : {}), ...(typeof latest.reason === "string" ? { reason: latest.reason } : {}), ...(Array.isArray(latest.recipients) ? { accountIds: latest.recipients.filter(isProfileId) } : {}) } : undefined;
  return {
    reference, id: reference.id, title: raw.label,
    ...(typeof raw.created_at === "number" ? { createdAt: raw.created_at } : {}),
    ...(typeof raw.status === "string" ? { status: raw.status } : {}),
    anchorHistory, addressedEvents, attachments,
    notes: Array.isArray(raw.notes) ? raw.notes.filter((item): item is Record<string, unknown> => !!object(item)) : [],
    statuses, outcomes,
    ...(entityRefs.length ? { entityRefs } : {}), ...(accountIds.length ? { accountIds } : {}),
    ...(mindIds.length ? { mindIds } : {}), ...(eventIds.length ? { eventIds } : {}), ...(outcome ? { outcome } : {}),
  };
}

function decodePayload(value: unknown): StaffPayload | null {
  if (value && typeof value === "object") return object(value) as StaffPayload;
  if (typeof value !== "string" || !value.length) return {};
  try { return object(JSON.parse(value)) as StaffPayload | null; } catch { return null; }
}

function inspectionValue(value: unknown, round: string): StaffInspection | null {
  const raw = object(value);
  const target = refValue(raw?.target);
  if (!raw || !target || typeof raw.found !== "boolean" || typeof raw.tombstone !== "boolean") return null;
  return { target, found: raw.found, tombstone: raw.tombstone, payload: object(raw.payload), related: refs(raw.related), audit: Array.isArray(raw.audit) ? raw.audit.map((item) => eventValue(item, round)).filter((item): item is StaffEvent => !!item) : [] };
}

/** Build the only accepted reference shape for a staff action or row. */
export const staffRef = (round: string, kind: string, id: string, labelText?: string): StaffRef => ({
  round: kind === "account" ? "" : round, kind, id: String(id), ...(labelText ? { label: labelText } : {}),
});

/**
 * The one collision-proof ref key for the staff package. A colon join
 * folds distinct refs together: the wire charset lets ':' occur inside
 * `kind` and `id` (lunatic-core's `validate_identifier`), so a colon
 * landing in one field can shift where the next field's boundary
 * appears to be. `cases/records.ts` re-exports this rather than
 * defining its own.
 */
export const refKey = (value: StaffRef | null | undefined): string =>
  value ? JSON.stringify([value.round, value.kind, value.id]) : "";
export const recordRef = (round: string, id: string): StaffRef => staffRef(round, "event", id);
export const accountRef = (id: ProfileId, labelText?: string): StaffRef => staffRef("", "account", id, labelText);
export const label = (value: unknown, fallback = "—"): string => typeof value === "string" || typeof value === "number" ? String(value) : fallback;
export const initials = (value: string): string => value.split(/[^a-z0-9]+/i).filter(Boolean).slice(0, 2).map((part) => part[0]).join("").toUpperCase() || "?";

/** Read the native staff envelope while preserving every exact identifier. */
export function readStaff(view: GameplayView): StaffSession | null {
  const raw = object(view.state.staff);
  if (!raw || typeof raw.allowed !== "boolean" || typeof raw.active !== "boolean" || typeof raw.revision !== "string" || !isDecimalId(raw.revision) || typeof raw.round_id !== "string" || !isDecimalId(raw.round_id) || typeof raw.frozen !== "boolean" || typeof raw.control_held !== "boolean") return null;
  const payload = decodePayload(raw.payload);
  if (!payload) return null;
  const roundId = raw.round_id;
  const profiles = Array.isArray(payload.profiles) ? payload.profiles.map(profileValue).filter((item): item is StaffProfile => !!item) : [];
  const entities = Array.isArray(payload.world?.entities) ? payload.world!.entities.map((item) => entityValue(item, roundId)).filter((item): item is StaffEntity => !!item) : [];
  const cases = Array.isArray(payload.records?.cases) ? payload.records!.cases.map((item) => caseValue(item, roundId)).filter((item): item is StaffCase => !!item) : [];
  const selected = inspectionValue(payload.selected, roundId);
  const audit = Array.isArray(payload.audit) ? payload.audit.map((item) => eventValue(item, roundId)).filter((item): item is StaffEvent => !!item) : [];
  const events = [...(selected?.audit ?? []), ...audit];
  const camera = object(raw.camera);
  return {
    ...payload, allowed: raw.allowed, active: raw.allowed && raw.active, revision: raw.revision, roundId,
    operator: profileValue(raw.operator), frozen: raw.frozen, hold: raw.control_held,
    camera: camera && typeof camera.x === "number" && typeof camera.y === "number" ? { x: camera.x, y: camera.y } : null,
    driving: isDecimalId(raw.driving) ? raw.driving : null, inspector: selected,
    profiles, entities, cases, events, audit,
  };
}

export function entityFor(session: StaffSession, id: string | number | undefined): StaffEntity | null {
  const wanted = String(id ?? "");
  return session.entities.find((entity) => entity.id === wanted) ?? null;
}

export function profileFor(session: StaffSession, id: string | undefined): StaffProfile | null {
  return id && isProfileId(id) ? session.profiles.find((profile) => profile.id === id) ?? null : null;
}

export function caseFor(session: StaffSession, id: string | undefined): StaffCase | null {
  return id && isDecimalId(id) ? session.cases.find((item) => item.id === id) ?? null : null;
}
