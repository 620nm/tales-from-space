import type { Json } from "@lunatic/ui";
import type { StaffCase, StaffEntity, StaffEvent, StaffProfile, StaffRef, StaffSession } from "../model";
import { isDecimalId, isProfileId, isStaffIdentifier, isStaffRefId, isStaffRound, staffRef } from "../model";
import { historicalEventPresentation } from "../shared/presentation";
import { eventReference } from "../shared/records";

type ObjectValue = Record<string, unknown>;

export interface RecordPage {
  items: ObjectValue[];
  next: string | null;
  error: string | null;
  loading: boolean;
}

export interface ContextPage {
  rows: StaffEvent[];
  fullRows: ObjectValue[];
  profiles: StaffProfile[];
  next: string | null;
  error: string | null;
  loading: boolean;
}

/** Session-local limits keep historical reads useful without growing forever. */
export const MAX_CONTEXT_ENTRIES = 64;
export const MAX_CASE_ENTRIES = 64;
export const MAX_CONTEXT_ROWS = 1000;
export const MAX_CONTEXT_PROFILES = 256;
export const MAX_CONTEXT_PAGES = 16;
export const MAX_CASE_NESTED_ROWS = 1000;

export const objectValue = (value: unknown): ObjectValue | null =>
  value && typeof value === "object" && !Array.isArray(value) ? value as ObjectValue : null;

function boundedObjectRows(value: unknown): ObjectValue[] {
  return Array.isArray(value)
    ? value.slice(0, MAX_CASE_NESTED_ROWS).map(objectValue).filter((item): item is ObjectValue => !!item)
    : [];
}

export const stringValue = (value: unknown, fallback = ""): string =>
  typeof value === "string" || typeof value === "number" ? String(value) : fallback;

export function readRef(value: unknown, round: string): StaffRef | null {
  const raw = objectValue(value);
  if (!raw) return null;
  const kind = stringValue(raw.kind);
  const id = stringValue(raw.id);
  const refRound = stringValue(raw.round);
  if (!isStaffIdentifier(kind, 96) || !isStaffRefId(kind, id)) return null;
  if (kind === "account" ? refRound !== "" || !isProfileId(id) : refRound === "" || !isStaffRound(refRound)) return null;
  void round;
  return {
    round: refRound,
    kind,
    id,
    ...(typeof raw.label === "string" ? { label: raw.label } : {}),
  };
}

export function readRefs(value: unknown, round: string): StaffRef[] {
  if (!Array.isArray(value)) return [];
  return value.slice(0, MAX_CONTEXT_ROWS).map((item) => readRef(item, round)).filter((item): item is StaffRef => !!item);
}

/**
 * A colon join would collide: the wire charset permits `:` inside
 * `kind` and `id` (lunatic-core's `validate_identifier`), so two
 * distinct refs can print the same joined string. `JSON.stringify`
 * escapes each part instead of trusting none of them contain the
 * separator.
 */
export function refKey(ref: StaffRef): string {
  return JSON.stringify([ref.round, ref.kind, ref.id]);
}

export function uniqueRefs(refs: StaffRef[]): StaffRef[] {
  return [...new Map(refs.map((ref) => [refKey(ref), ref])).values()];
}

export function caseRef(session: StaffSession, item: StaffCase): StaffRef | null {
  const raw = item as unknown as ObjectValue;
  const reference = readRef(raw.reference, session.roundId);
  if (reference?.kind === "case" && isDecimalId(reference.id)) return reference;
  return null;
}

export function caseId(item: StaffCase): string {
  return item.id;
}

export function caseLabel(item: StaffCase): string {
  return item.title;
}

/** Parse one response case without weakening the model's wire validation. */
export function caseFromRaw(value: unknown, round: string): StaffCase | null {
  const raw = objectValue(value);
  const reference = readRef(raw?.reference, round);
  if (!raw || !reference || reference.kind !== "case") return null;
  const anchors = readRefs(raw.direct_anchor_history, round);
  const addressed = readRefs(raw.case_addressed_events, round).filter((ref) => ref.kind === "event");
  const attachments = readRefs(raw.attachments, round);
  const notes = boundedObjectRows(raw.notes);
  const statuses = boundedObjectRows(raw.statuses);
  const outcomes = boundedObjectRows(raw.outcomes);
  const refs = uniqueRefs([...anchors, ...attachments]);
  const accounts = refs.filter((ref) => ref.kind === "account").map((ref) => ref.id).filter(isProfileId);
  const minds = refs.filter((ref) => ref.kind === "mind").map((ref) => ref.id).filter(isDecimalId);
  const events = addressed.map((ref) => ref.id).filter(isDecimalId);
  const latest = outcomes.at(-1);
  const outcome = latest && typeof latest.value === "string"
    ? {
      label: latest.value,
      ...(typeof latest.label === "string" ? { duration: latest.label } : {}),
      ...(typeof latest.reason === "string" ? { reason: latest.reason } : {}),
      ...(Array.isArray(latest.recipients) ? { accountIds: latest.recipients.filter(isProfileId) } : {}),
    }
    : undefined;
  return {
    reference,
    id: reference.id,
    title: typeof raw.label === "string" ? raw.label : reference.id,
    ...(typeof raw.created_at === "number" ? { createdAt: raw.created_at } : {}),
    ...(typeof raw.status === "string" ? { status: raw.status } : {}),
    anchorHistory: anchors,
    addressedEvents: addressed,
    attachments,
    notes,
    statuses,
    outcomes,
    ...(refs.length ? { entityRefs: refs } : {}),
    ...(accounts.length ? { accountIds: accounts } : {}),
    ...(minds.length ? { mindIds: minds } : {}),
    ...(events.length ? { eventIds: events } : {}),
    ...(outcome ? { outcome } : {}),
  };
}

export function caseAccountIds(item: StaffCase): string[] {
  const ids = [...(item.accountIds ?? [])].map(String);
  for (const ref of item.anchorHistory ?? []) if (ref.kind === "account" && isProfileId(ref.id)) ids.push(ref.id);
  for (const ref of item.attachments ?? []) if (ref.kind === "account" && isProfileId(ref.id)) ids.push(ref.id);
  return [...new Set(ids.filter(isProfileId))];
}

export function caseAnchorRefs(session: StaffSession, item: StaffCase): StaffRef[] {
  void session;
  return uniqueRefs(item.anchorHistory ?? []);
}

export function caseEventRefs(session: StaffSession, item: StaffCase): StaffRef[] {
  const refs = [
    ...(item.addressedEvents ?? []),
    ...(item.attachments ?? []),
  ];
  void session;
  return uniqueRefs(refs.filter((ref) => ref.kind === "event"));
}

export function eventRef(session: StaffSession, event: StaffEvent): StaffRef | null {
  // Event ids come from the server cursor. Never derive one from a row index.
  return event.id ? eventReference(event) : null;
}

export function eventFrom(value: unknown, round: string): StaffEvent | null {
  const raw = objectValue(value);
  if (!raw) return null;
  const reference = readRef(raw.reference, round);
  if (!reference || reference.kind !== "event") return null;
  if (typeof raw.action !== "string") return historicalEventFrom(raw, reference, round);
  const id = reference.id;
  const targetRefs = readRefs(raw.target_refs, round);
  const targetRef = readRef(raw.target_ref, round);
  return {
    reference,
    id,
    time: stringValue(raw.time, "—"),
    action: stringValue(raw.action, "—"),
    target: stringValue(raw.target),
    targetRef,
    ...(targetRefs.length ? { targetRefs } : {}),
    actor: stringValue(raw.actor),
    actorMind: stringValue(raw.actor_mind),
    actorBody: stringValue(raw.actor_body),
    accountId: stringValue(raw.account_id),
    operator: stringValue(raw.operator),
    admin: raw.admin === true,
    result: stringValue(raw.result),
    reason: stringValue(raw.reason),
    before: stringValue(raw.before),
    after: stringValue(raw.after),
    includedThrough: stringValue(raw.included_through),
    caseId: stringValue(raw.case_id),
  };
}

/** Expand the server's full historical row without inventing a source event. */
function historicalEventFrom(raw: ObjectValue, reference: StaffRef, round: string): StaffEvent | null {
  if (typeof raw.event_type !== "string") return null;
  const payload = objectValue(raw.payload);
  const refs = readRefs(raw.refs, round);
  const occupantAccount = isProfileId(raw.occupant_account) ? { round: "", kind: "account", id: raw.occupant_account } satisfies StaffRef : null;
  const occupantMind = isDecimalId(raw.occupant_mind) ? { round: reference.round, kind: "mind", id: raw.occupant_mind } satisfies StaffRef : null;
  const body = readRef(raw.body, round) ?? refs.find((ref) => ref.kind === "body");
  const mind = readRef(raw.mind, round) ?? refs.find((ref) => ref.kind === "mind") ?? occupantMind;
  const account = readRef(raw.account, round) ?? refs.find((ref) => ref.kind === "account") ?? occupantAccount;
  const presentation = historicalEventPresentation(
    raw.event_type,
    payload,
    refs,
    (value) => readRef(value, round),
    raw.created_at_ms,
  );
  const adminOrigin = objectValue(raw.admin_origin);
  const adminProfileId = stringValue(adminOrigin?.profile, "");
  const action = stringValue(payload?.action, stringValue(payload?.event, raw.event_type));
  const sourceSeq = isDecimalId(stringValue(payload?.seq))
    ? stringValue(payload?.seq)
    : typeof payload?.seq === "number" && Number.isSafeInteger(payload.seq) && payload.seq >= 0
      ? String(payload.seq)
      : undefined;
  return {
    reference,
    id: reference.id,
    time: presentation.time,
    action,
    eventType: raw.event_type,
    ...(typeof raw.server_id === "string" ? { serverId: raw.server_id } : {}),
    ...(typeof raw.created_at_ms === "number" ? { createdAtMs: raw.created_at_ms } : {}),
    ...(sourceSeq ? { sourceSeq } : {}),
    ...(presentation.target === undefined ? {} : { target: presentation.target }),
    ...(presentation.targetRef ? { targetRef: presentation.targetRef } : {}),
    ...(body ? { actorBody: body.id } : {}),
    ...(mind ? { actorMind: mind.id } : {}),
    ...(body ? { bodyRef: body } : {}),
    ...(mind ? { mindRef: mind } : {}),
    ...(account ? { accountRef: account } : {}),
    ...(account ? { accountId: account.id } : {}),
    ...(typeof raw.actor === "string" ? { actor: raw.actor } : {}),
    ...(isProfileId(adminProfileId) ? { adminProfileId, operator: adminProfileId, admin: true } : raw.admin_origin !== undefined && raw.admin_origin !== null ? { admin: true } : {}),
    ...(typeof raw.controller === "string" ? { controller: raw.controller } : {}),
    ...(typeof raw.operation_id === "string" ? { operationId: raw.operation_id } : {}),
    ...(payload ? { payload } : {}),
    ...(refs.length ? { refs } : {}),
    ...(typeof raw.name === "string" ? { name: raw.name } : {}),
    ...(raw.deleted === true ? { deleted: true } : {}),
    ...(typeof payload?.result === "string" ? { result: payload.result } : {}),
    ...(typeof payload?.reason === "string" ? { reason: payload.reason } : {}),
    ...(typeof payload?.before === "string" ? { before: payload.before } : {}),
    ...(typeof payload?.after === "string" ? { after: payload.after } : {}),
    ...(typeof payload?.included_through === "string" ? { includedThrough: payload.included_through } : {}),
    ...(isDecimalId(payload?.case_id) ? { caseId: stringValue(payload?.case_id) } : {}),
  };
}

export function eventRows(session: StaffSession): StaffEvent[] {
  // The shell has already validated and normalized these HistoricalRows. Keep
  // their full identity metadata (including admin origin) intact.
  const rows = [...(session.events ?? []), ...(session.audit ?? [])]
    .filter((row): row is StaffEvent => !!row.reference && row.reference.kind === "event" && typeof row.action === "string");
  return [...new Map(rows.map((row) => [refKey(row.reference), row])).values()];
}

export function sameRef(left: StaffRef | undefined, right: StaffRef): boolean {
  return !!left && left.round === right.round && left.kind === right.kind && left.id === right.id;
}

export function eventMatchesRef(event: StaffEvent, ref: StaffRef, round: string): boolean {
  if (ref.kind === "event") return event.reference.round === ref.round && event.reference.id === ref.id;
  const targets = [event.targetRef, ...(event.targetRefs ?? [])]
    .map((item) => readRef(item, round)).filter((item): item is StaffRef => !!item);
  if (targets.some((target) => sameRef(target, ref))) return true;
  if (ref.kind === "account") return event.accountId === ref.id;
  if (ref.kind === "mind") return event.actorMind === ref.id;
  if (ref.kind === "body" || ref.kind === "entity") {
    return event.actorBody === ref.id || event.target === ref.id;
  }
  return false;
}

/** Case history is the exact anchor union plus explicit case rows. */
export function localCaseEvents(session: StaffSession, item: StaffCase): StaffEvent[] {
  const eventRefs = caseEventRefs(session, item);
  const id = caseId(item);
  const anchors = caseAnchorRefs(session, item);
  const contextRows = anchors.flatMap((anchor) => contextRowsFor(session, anchor));
  const contextIds = new Set(contextRows.map((event) => refKey(event.reference)));
  return eventRows(session)
    .concat(contextRows)
    .filter((event) => event.caseId === id
      || eventRefs.some((ref) => eventMatchesRef(event, ref, session.roundId))
      || contextIds.has(refKey(event.reference)))
    .sort((left, right) => left.time.localeCompare(right.time) || left.id.localeCompare(right.id));
}

/**
 * Context pages are durable cursors, so retain each loaded page by its exact
 * anchor. The native bridge keeps only the latest response; this cache lets a
 * case show all pages the operator has explicitly opened without deriving rows
 * from an anchor or collapsing rows from another anchor.
 */
interface SavedContext {
  rows: Map<string, StaffEvent>;
  fullRows: Map<string, ObjectValue>;
  profiles: Map<string, StaffProfile>;
  pages: number;
  next: string | null;
  error: string | null;
}

interface SavedCase {
  value: StaffCase;
  raw: ObjectValue;
  next: string | null;
  error: string | null;
}

const contextCache = new Map<string, SavedContext>();
const caseCache = new Map<string, SavedCase>();
const responseProfiles = new Map<string, StaffProfile>();
let cacheRound = "";
let rememberedResponseKey = "";

export function resetRecordCaches(): void {
  contextCache.clear();
  caseCache.clear();
  responseProfiles.clear();
  cacheRound = "";
  rememberedResponseKey = "";
}

function ensureCacheRound(round: string): void {
  if (cacheRound === round) return;
  contextCache.clear();
  caseCache.clear();
  responseProfiles.clear();
  cacheRound = round;
  rememberedResponseKey = "";
}

function lruGet<K, V>(cache: Map<K, V>, key: K): V | undefined {
  const value = cache.get(key);
  if (value === undefined) return undefined;
  cache.delete(key);
  cache.set(key, value);
  return value;
}

function lruSet<K, V>(cache: Map<K, V>, key: K, value: V, capacity: number): void {
  cache.delete(key);
  cache.set(key, value);
  while (cache.size > capacity) {
    const oldest = cache.keys().next().value as K | undefined;
    if (oldest === undefined) break;
    cache.delete(oldest);
  }
}

function trimRows(entry: SavedContext): void {
  while (entry.rows.size > MAX_CONTEXT_ROWS) {
    const oldest = entry.rows.keys().next().value as string | undefined;
    if (oldest === undefined) break;
    entry.rows.delete(oldest);
    entry.fullRows.delete(oldest);
  }
  while (entry.fullRows.size > MAX_CONTEXT_ROWS) {
    const oldest = entry.fullRows.keys().next().value as string | undefined;
    if (oldest === undefined) break;
    entry.fullRows.delete(oldest);
    entry.rows.delete(oldest);
  }
}

function clearContext(entry: SavedContext): void {
  entry.rows.clear();
  entry.fullRows.clear();
  entry.profiles.clear();
  entry.pages = 0;
  entry.next = null;
  entry.error = null;
}

function contextEntry(key: string): SavedContext {
  const existing = lruGet(contextCache, key);
  if (existing) return existing;
  const created: SavedContext = { rows: new Map(), fullRows: new Map(), profiles: new Map(), pages: 0, next: null, error: null };
  lruSet(contextCache, key, created, MAX_CONTEXT_ENTRIES);
  return created;
}

function caseEntry(session: StaffSession, value: unknown): SavedCase | null {
  const parsed = caseFromRaw(value, session.roundId);
  if (!parsed) return null;
  const key = refKey(parsed.reference);
  const raw = boundedRawCase(objectValue(value)!);
  const previous = lruGet(caseCache, key);
  const merged = previous ? mergeCases(previous.value, parsed) : parsed;
  const mergedRaw = previous ? mergeRawCases(previous.raw, raw) : raw;
  const saved: SavedCase = {
    value: merged,
    raw: mergedRaw,
    next: previous?.next ?? null,
    error: previous?.error ?? null,
  };
  lruSet(caseCache, key, saved, MAX_CASE_ENTRIES);
  return saved;
}

function boundedRawCase(raw: ObjectValue): ObjectValue {
  const bounded: ObjectValue = { ...raw };
  for (const key of ["direct_anchor_history", "case_addressed_events", "attachments", "notes", "statuses", "outcomes"]) {
    if (Array.isArray(raw[key])) bounded[key] = raw[key].slice(0, MAX_CASE_NESTED_ROWS);
  }
  return bounded;
}

function mergeRawCases(left: ObjectValue, right: ObjectValue): ObjectValue {
  const merged: ObjectValue = { ...left, ...right };
  for (const key of ["direct_anchor_history", "case_addressed_events", "attachments", "notes", "statuses", "outcomes"]) {
    const a = Array.isArray(left[key]) ? left[key] : [];
    const b = Array.isArray(right[key]) ? right[key] : [];
    if (a.length || b.length) {
      merged[key] = [...a, ...b]
        .filter((item, index, values) => values.findIndex((other) => JSON.stringify(other) === JSON.stringify(item)) === index)
        .slice(0, MAX_CASE_NESTED_ROWS);
    }
  }
  return merged;
}

function mergeCases(left: StaffCase, right: StaffCase): StaffCase {
  const refs = (a: StaffRef[], b: StaffRef[]) => uniqueRefs([...a, ...b]).slice(0, MAX_CONTEXT_ROWS);
  const rows = (a: ObjectValue[], b: ObjectValue[]) => {
    const key = (row: ObjectValue) => JSON.stringify(row);
    return [...new Map([...a, ...b].map((row) => [key(row), row])).values()].slice(0, MAX_CASE_NESTED_ROWS);
  };
  const merged: StaffCase = {
    ...left,
    ...right,
    anchorHistory: refs(left.anchorHistory, right.anchorHistory),
    addressedEvents: refs(left.addressedEvents, right.addressedEvents),
    attachments: refs(left.attachments, right.attachments),
    notes: rows(left.notes, right.notes),
    statuses: rows(left.statuses, right.statuses),
    outcomes: rows(left.outcomes, right.outcomes),
  };
  const entityRefs = refs(left.entityRefs ?? [], right.entityRefs ?? []);
  const accountIds = [...new Set([...(left.accountIds ?? []), ...(right.accountIds ?? [])])];
  const mindIds = [...new Set([...(left.mindIds ?? []), ...(right.mindIds ?? [])])];
  const eventIds = [...new Set([...(left.eventIds ?? []), ...(right.eventIds ?? [])])];
  if (entityRefs.length) merged.entityRefs = entityRefs;
  if (accountIds.length) merged.accountIds = accountIds;
  if (mindIds.length) merged.mindIds = mindIds;
  if (eventIds.length) merged.eventIds = eventIds;
  return merged;
}

function saveProfiles(entry: SavedContext, values: unknown): void {
  if (!Array.isArray(values)) return;
  for (const value of values.slice(0, MAX_CONTEXT_PROFILES)) {
    const raw = objectValue(value);
    if (!raw || !isProfileId(raw.id) || typeof raw.username !== "string" || typeof raw.avatar !== "string" || typeof raw.role !== "string") continue;
    const avatar = raw.avatar === "portrait-01" || raw.avatar === "portrait-02" || raw.avatar === "portrait-03" || raw.avatar === "portrait-04" || raw.avatar === "unknown"
      ? raw.avatar
      : "unknown";
    lruSet(entry.profiles, raw.id, { id: raw.id, username: raw.username, avatar, role: raw.role }, MAX_CONTEXT_PROFILES);
  }
}

/** Save every response row before another query replaces the bridge value. */
export function rememberRecordResponse(session: StaffSession): void {
  const response = recordResponse(session);
  if (!response) return;
  const responseKey = rememberedKey(response);
  if (responseKey === rememberedResponseKey) return;
  rememberedResponseKey = responseKey;
  const result = objectValue(response.result);
  if (!result) {
    const query = objectValue(response.query);
    const anchor = readRef(query?.anchor, session.roundId);
    if (query?.op === "context" && anchor) {
      const entry = contextEntry(refKey(anchor));
      entry.next = null;
      entry.error = responseError(response);
    }
    return;
  }
  if (result.kind === "case") {
    const query = objectValue(response.query);
    if (!nextCursor(query?.after)) {
      const parsed = caseFromRaw(result.case, session.roundId);
      if (parsed) caseCache.delete(refKey(parsed.reference));
    }
    const saved = caseEntry(session, result.case);
    if (saved) {
      saved.next = nextCursor(result.next);
      saved.error = responseError(response);
    }
    return;
  }
  if (result.kind !== "context") return;
  const query = objectValue(response.query);
  const anchor = readRef(query?.anchor, session.roundId) ?? readRef(objectValue(result.context)?.anchor, session.roundId);
  if (!anchor) return;
  const entry = contextEntry(refKey(anchor));
  const after = nextCursor(query?.after);
  if (!after) clearContext(entry);
  const canStorePage = entry.pages < MAX_CONTEXT_PAGES;
  if (canStorePage && Array.isArray(result.rows)) {
    for (const value of result.rows) {
      const raw = objectValue(value);
      const event = eventFrom(value, session.roundId);
      if (!raw || !event) continue;
      const key = refKey(event.reference);
      lruSet(entry.rows, key, event, MAX_CONTEXT_ROWS);
      lruSet(entry.fullRows, key, raw, MAX_CONTEXT_ROWS);
    }
    trimRows(entry);
  }
  if (canStorePage) {
    entry.pages += 1;
    saveProfiles(entry, result.profiles);
  }
  entry.next = canStorePage && entry.pages < MAX_CONTEXT_PAGES && entry.rows.size < MAX_CONTEXT_ROWS
    ? nextCursor(objectValue(result.context)?.next)
    : null;
  entry.error = responseError(response);
}

/** Full source rows are returned with a context result, keyed by its query anchor. */
function contextRowsFor(session: StaffSession, anchor: StaffRef): StaffEvent[] {
  if (typeof session.roundId === "string") rememberRecordResponse(session);
  return [...contextEntry(refKey(anchor)).rows.values()];
}

export function contextRows(session: StaffSession, anchor: StaffRef): StaffEvent[] {
  return contextRowsFor(session, anchor);
}

export function contextPageFor(session: StaffSession, anchor: StaffRef): ContextPage {
  contextRowsFor(session, anchor);
  const cached = contextEntry(refKey(anchor));
  return {
    rows: [...cached.rows.values()],
    fullRows: [...cached.fullRows.values()],
    profiles: [...cached.profiles.values()],
    next: cached.next,
    error: cached.error,
    loading: false,
  };
}

export function contextFullRows(session: StaffSession, anchor: StaffRef): ObjectValue[] {
  return contextPageFor(session, anchor).fullRows;
}

export function contextQueryAnchor(session: StaffSession): StaffRef | null {
  const response = recordResponse(session);
  const query = objectValue(response?.query);
  return readRef(query?.anchor, session.roundId);
}

/** The native bridge keeps one session-local durable response. */
export function recordResponse(session: StaffSession): ObjectValue | null {
  if (typeof session.roundId === "string") ensureCacheRound(session.roundId);
  const records = objectValue(session.records);
  const response = objectValue(records?.response);
  return response;
}

export function responseCase(session: StaffSession, reference?: StaffRef | null): StaffCase | null {
  const result = objectValue(recordResponse(session)?.result);
  const value = result?.kind === "case" ? result.case : null;
  const parsed = caseFromRaw(value, session.roundId);
  if (parsed) {
    const saved = caseEntry(session, value);
    if (saved && (!reference || sameRef(parsed.reference, reference))) return saved.value;
  }
  if (reference) return lruGet(caseCache, refKey(reference))?.value ?? null;
  return null;
}

export function cachedCase(session: StaffSession, reference: StaffRef): StaffCase | null {
  if (typeof session.roundId === "string") ensureCacheRound(session.roundId);
  return lruGet(caseCache, refKey(reference))?.value ?? null;
}

export function casePageFor(session: StaffSession, reference: StaffRef): RecordPage {
  rememberRecordResponse(session);
  const saved = lruGet(caseCache, refKey(reference));
  if (!saved) {
    const response = recordResponse(session);
    const query = objectValue(response?.query);
    const queried = readRef(query?.case, session.roundId);
    return queried && sameRef(queried, reference)
      ? { items: [], next: null, error: responseError(response), loading: false }
      : { items: [], next: null, error: null, loading: false };
  }
  return { items: [saved.raw], next: saved.next, error: saved.error, loading: false };
}

/** Resolve only profile metadata included by the authoritative record result. */
export function responseProfileFor(session: StaffSession, id: string): StaffProfile | null {
  if (typeof session.roundId === "string") ensureCacheRound(session.roundId);
  const response = recordResponse(session);
  const result = response?.error ? null : objectValue(response?.result);
  if (result?.kind === "context") {
    const query = objectValue(response?.query);
    const anchor = readRef(query?.anchor, session.roundId) ?? readRef(objectValue(result.context)?.anchor, session.roundId);
    if (anchor) {
      const entry = contextEntry(refKey(anchor));
      saveProfiles(entry, result.profiles);
    }
  }
  const values = result?.kind === "context"
    ? result.profiles
    : result?.kind === "profile"
      ? [objectValue(objectValue(result.profile)?.identity)]
      : null;
  if (Array.isArray(values)) {
    for (const value of values.slice(0, MAX_CONTEXT_PROFILES)) {
      const raw = objectValue(value);
      if (!raw || !isProfileId(raw.id) || typeof raw.username !== "string" || typeof raw.avatar !== "string" || typeof raw.role !== "string") continue;
      const avatar = raw.avatar === "portrait-01" || raw.avatar === "portrait-02" || raw.avatar === "portrait-03" || raw.avatar === "portrait-04" || raw.avatar === "unknown"
        ? raw.avatar
        : "unknown";
      lruSet(responseProfiles, `${session.roundId}:${raw.id}`, { id: raw.id, username: raw.username, avatar, role: raw.role }, MAX_CONTEXT_PROFILES);
    }
  }
  const responseProfile = lruGet(responseProfiles, `${session.roundId}:${id}`);
  if (responseProfile) return responseProfile;
  for (const entry of contextCache.values()) {
    const profile = entry.profiles.get(id);
    if (profile) return profile;
  }
  return null;
}

function nextCursor(value: unknown): string | null {
  if (typeof value === "string" || typeof value === "number") return String(value);
  return null;
}

function rememberedKey(response: ObjectValue): string {
  const requestId = stringValue(response.request_id);
  const query = canonical(response.query);
  const error = stringValue(response.error);
  return `${requestId}\u0000${query}\u0000${error}`.slice(0, 4096);
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value as ObjectValue).sort().map((key) => `${JSON.stringify(key)}:${canonical((value as ObjectValue)[key])}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}

export function pageFor(session: StaffSession, kind: "cases" | "case" | "profile" | "context"): RecordPage {
  rememberRecordResponse(session);
  const response = recordResponse(session);
  const result = objectValue(response?.result);
  if (!response || !result || stringValue(result.kind) !== kind) {
    return { items: [], next: null, error: responseError(response), loading: false };
  }
  const payload = kind === "cases"
    ? result
    : objectValue(result[kind]) ?? null;
  const items = kind === "cases"
    ? (Array.isArray(payload?.items) ? payload.items.map(objectValue).filter((item): item is ObjectValue => !!item) : [])
    : payload ? [payload] : [];
  return {
    items,
    next: nextCursor(kind === "cases" ? result.next : payload?.next),
    error: responseError(response),
    loading: false,
  };
}

function responseError(response: ObjectValue | null): string | null {
  return stringValue(response?.error, "") || null;
}

export function pageEvents(session: StaffSession, kind: "case" | "context"): StaffEvent[] {
  return pageFor(session, kind).items
    .map((item) => eventFrom(item, session.roundId))
    .filter((item): item is StaffEvent => !!item);
}

export function allCaseEvents(session: StaffSession, item: StaffCase): StaffEvent[] {
  const pageRows = pageEvents(session, "case");
  const localRows = localCaseEvents(session, item);
  return [...new Map([...pageRows, ...localRows].map((row) => [refKey(row.reference), row])).values()]
    .sort((left, right) => left.time.localeCompare(right.time) || left.id.localeCompare(right.id));
}

export function queryJson(op: string, body: ObjectValue): string {
  return JSON.stringify({ op, ...body });
}

export function casesQuery(after?: string | null): Record<string, Json> {
  return {
    kind: "query",
    query: JSON.stringify({ op: "cases", ...(after ? { after } : {}), limit: 64 }),
  };
}

export function caseQuery(session: StaffSession, item: StaffCase, after?: string | null): Record<string, Json> {
  const ref = caseRef(session, item);
  return {
    kind: "query",
    query: JSON.stringify({ op: "case", case: ref, ...(after ? { after } : {}), limit: 64 }),
  };
}

export function contextQuery(session: StaffSession, anchor: StaffRef, after?: string | null): Record<string, Json> {
  return {
    kind: "query",
    query: JSON.stringify({ op: "context", anchor, ...(after ? { after } : {}), limit: 64 }),
  };
}

export function profileQuery(account: StaffRef, after?: string | null): Record<string, Json> {
  return {
    kind: "query",
    query: JSON.stringify({ op: "profile", target: account, ...(after ? { after } : {}), limit: 64 }),
  };
}

export function conversationQuery(conversation: StaffRef, after?: string | null): Record<string, Json> {
  return {
    kind: "query",
    query: JSON.stringify({ op: "conversation", conversation, ...(after ? { after } : {}), limit: 16, newest: true }),
  };
}

export function entitiesForRef(session: StaffSession, ref: StaffRef): StaffEntity[] {
  const selected = selectedLiveBody(session, ref);
  const candidates = [...(session.entities ?? [])];
  if (selected && !candidates.some((entity) => exactRef(entity.ref, selected.ref, session.roundId))) candidates.push(selected);
  const matches = candidates.filter((entity) => {
    const related = (entity.refs ?? []).some((candidate) => exactRef(candidate, ref, session.roundId));
    if (related || exactRef(entity.ref, ref, session.roundId)) return true;
    if (ref.kind === "account") return ref.round === "" && entity.accountId === ref.id;
    if (ref.round !== session.roundId) return false;
    if (ref.kind === "mind") return entity.mindId === ref.id;
    if (ref.kind === "body") return entity.bodyId === ref.id;
    return false;
  });
  return [...new Map(matches.map((entity) => [`${entity.ref.round}:${entity.ref.kind}:${entity.ref.id}`, entity])).values()];
}

function exactRef(candidate: StaffRef, ref: StaffRef, round: string): boolean {
  if (candidate.kind !== ref.kind || candidate.id !== ref.id) return false;
  if (candidate.kind === "account") return candidate.round === "" && ref.round === "";
  return candidate.round === round && ref.round === round;
}

function selectedLiveBody(session: StaffSession, ref: StaffRef): StaffEntity | null {
  if (ref.kind !== "account" || ref.round !== "") return null;
  const inspection = session.inspector;
  if (!inspection || !inspection.found || inspection.tombstone
    || inspection.target.round !== session.roundId
    || !LIVE_BODY_KINDS.has(inspection.target.kind)) return null;
  const payload = objectValue(inspection.payload);
  if (!payload || payload.live !== true || payload.entity_id !== undefined && String(payload.entity_id) !== inspection.target.id) return null;
  if (!isProfileId(payload.account_id) || payload.account_id !== ref.id) return null;
  const kind = typeof payload.kind === "string" && LIVE_BODY_KINDS.has(payload.kind) ? payload.kind : inspection.target.kind;
  const position = objectValue(payload.position);
  const pos = position && typeof position.x === "number" && Number.isFinite(position.x)
    && typeof position.y === "number" && Number.isFinite(position.y)
    ? { x: position.x, y: position.y, ...(typeof position.z === "number" && Number.isFinite(position.z) ? { z: position.z } : {}) }
    : undefined;
  const mindId = payload.mind_id === undefined || payload.mind_id === null ? undefined : isDecimalId(payload.mind_id) ? payload.mind_id : null;
  const bodyId = payload.body_id === undefined || payload.body_id === null ? undefined : isDecimalId(payload.body_id) ? payload.body_id : null;
  if (mindId === null || bodyId === null) return null;
  return {
    id: inspection.target.id,
    ref: inspection.target,
    kind,
    name: typeof payload.name === "string" && payload.name ? payload.name : `${kind} · ${inspection.target.id}`,
    accountId: payload.account_id,
    ...(mindId ? { mindId } : {}),
    ...(bodyId ? { bodyId } : {}),
    ...(pos ? { pos } : {}),
    live: true,
  };
}

const LIVE_BODY_KINDS = new Set(["entity", "player", "body", "mob"]);
